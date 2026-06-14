-- ═══════════════════════════════════════════════════════════
-- ParlonsNation — Migration SQL complète
-- Exécuter dans : Supabase Dashboard > SQL Editor
-- ═══════════════════════════════════════════════════════════

-- ─── 1. IDENTITÉ COMPLÈTE CONGOLAISE ─────────────────────
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS nom               text;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS post_nom          text;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS prenom            text;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS date_naissance    date;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS sexe              text check (sexe in ('M','F'));
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS age_verifie       boolean default false;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS identite_verifie  boolean default false;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS cin_expire        boolean default false;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS cin_expiry_date   date;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS cin_photo_url     text;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS cin_verso_url     text;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS score_verification integer default 0;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS localisation_gps  boolean default false;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS localisation_ip_pays text;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS localisation_coherente boolean default false;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS coords_lat        numeric;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS coords_lng        numeric;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS telephone_verifie boolean default false;
ALTER TABLE citoyens ADD COLUMN IF NOT EXISTS statut            text default 'en_attente'
  check (statut in ('en_attente','verifie','rejete','suspendu'));

-- ─── 2. TABLE ADMINS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS admins (
  id            uuid primary key default gen_random_uuid(),
  email         text unique not null,
  password_hash text not null,
  role          text default 'moderateur'
    check (role in ('super_admin','moderateur','analyste','partenaire_api')),
  actif         boolean default true,
  created_at    timestamp default now(),
  last_login    timestamp
);

-- ─── 3. TABLE LOGS D'ACCÈS ADMIN ─────────────────────────
CREATE TABLE IF NOT EXISTS admin_logs (
  id         uuid primary key default gen_random_uuid(),
  admin_id   uuid references admins(id),
  action     text not null,
  details    jsonb,
  ip_address text,
  created_at timestamp default now()
);

-- ─── 4. TABLE SIGNALEMENTS FORUM ─────────────────────────
CREATE TABLE IF NOT EXISTS signalements (
  id              uuid primary key default gen_random_uuid(),
  commentaire_id  uuid,
  citoyen_id      uuid references citoyens(id),
  raison          text,
  traite          boolean default false,
  created_at      timestamp default now()
);

-- ─── 5. RLS SUR NOUVELLES TABLES ─────────────────────────
ALTER TABLE admins       ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs   ENABLE ROW LEVEL SECURITY;
ALTER TABLE signalements ENABLE ROW LEVEL SECURITY;

-- Admins : aucun accès direct via clé publique (tout passe par RPC SECURITY DEFINER)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='admins' AND policyname='deny_all') THEN
    CREATE POLICY deny_all ON admins FOR ALL USING (false);
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='admin_logs' AND policyname='deny_all') THEN
    CREATE POLICY deny_all ON admin_logs FOR ALL USING (false);
  END IF;
END $$;

-- Signalements : tout citoyen peut insérer, personne ne peut lire directement
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='signalements' AND policyname='insert_only') THEN
    CREATE POLICY insert_only ON signalements FOR INSERT WITH CHECK (true);
  END IF;
END $$;

-- ─── 6. FONCTION : LOGIN ADMIN SÉCURISÉ ──────────────────
-- Le mot de passe en clair est vérifié côté serveur — le hash n'est jamais exposé au client
CREATE OR REPLACE FUNCTION admin_login(p_email text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin
  FROM admins
  WHERE email = p_email
    AND password_hash = encode(digest(p_password, 'sha256'), 'hex')
    AND actif = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Email ou mot de passe incorrect');
  END IF;

  UPDATE admins SET last_login = now() WHERE id = v_admin.id;

  RETURN jsonb_build_object(
    'success',  true,
    'admin_id', v_admin.id::text,
    'email',    v_admin.email,
    'role',     v_admin.role
  );
END;
$$;

-- ─── 7. FONCTION : METTRE À JOUR LE STATUT D'UN CITOYEN ──
CREATE OR REPLACE FUNCTION admin_update_citoyen(
  p_admin_id  uuid,
  p_citoyen_id uuid,
  p_statut    text,
  p_score     integer DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Non autorisé'); END IF;

  UPDATE citoyens
  SET statut = p_statut,
      identite_verifie = (p_statut = 'verifie'),
      score_verification = COALESCE(p_score, score_verification)
  WHERE id = p_citoyen_id;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'update_citoyen_statut',
          jsonb_build_object('citoyen_id', p_citoyen_id, 'statut', p_statut));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── 8. FONCTION : SUPPRIMER / MODÉRER UN COMMENTAIRE ────
CREATE OR REPLACE FUNCTION admin_delete_commentaire(p_admin_id uuid, p_commentaire_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Non autorisé'); END IF;

  DELETE FROM commentaires WHERE id = p_commentaire_id;
  UPDATE signalements SET traite = true WHERE commentaire_id = p_commentaire_id;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'delete_commentaire', jsonb_build_object('commentaire_id', p_commentaire_id));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── 9. FONCTION : TOGGLE SUJET ──────────────────────────
CREATE OR REPLACE FUNCTION admin_toggle_sujet(p_admin_id uuid, p_sujet_id uuid, p_actif boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Non autorisé'); END IF;

  UPDATE sujets SET actif = p_actif WHERE id = p_sujet_id;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'toggle_sujet', jsonb_build_object('sujet_id', p_sujet_id, 'actif', p_actif));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── 10. FONCTION : AJOUTER UN SUJET ─────────────────────
CREATE OR REPLACE FUNCTION admin_add_sujet(
  p_admin_id   uuid,
  p_titre      text,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin admins%ROWTYPE;
  v_sujet_id uuid;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Non autorisé'); END IF;

  INSERT INTO sujets (titre, description, actif)
  VALUES (p_titre, p_description, false)
  RETURNING id INTO v_sujet_id;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'add_sujet', jsonb_build_object('sujet_id', v_sujet_id, 'titre', p_titre));

  RETURN jsonb_build_object('success', true, 'sujet_id', v_sujet_id);
END;
$$;

-- ─── 11. SUPER ADMIN INITIAL ──────────────────────────────
-- Mot de passe par défaut : ParlonsNation2026!
-- CHANGER après la première connexion !
INSERT INTO admins (email, password_hash, role)
VALUES (
  'admin@parlonsnation.com',
  encode(digest('ParlonsNation2026!', 'sha256'), 'hex'),
  'super_admin'
)
ON CONFLICT (email) DO NOTHING;

-- ─── 12. BUCKET SUPABASE STORAGE POUR PHOTOS CIN ─────────
-- Si la table storage.buckets est accessible :
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('cin-photos', 'cin-photos', false, 5242880, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;

-- Sinon, créer manuellement via :
-- Supabase Dashboard > Storage > New bucket > "cin-photos" (privé, 5 MB max)

-- ═══════════════════════════════════════════════════════════
-- PARTIE 2 — CMS : CONFIGURATION & PAGES
-- ═══════════════════════════════════════════════════════════

-- ─── 13. TABLE CONFIGURATION (CMS) ───────────────────────
CREATE TABLE IF NOT EXISTS configuration (
  id          uuid primary key default gen_random_uuid(),
  cle         text unique not null,
  valeur      text,
  type        text default 'text'
    check (type in ('text','boolean','color','number','json','api_key')),
  categorie   text default 'general'
    check (categorie in ('general','apparence','api','contenu')),
  label       text,
  description text,
  updated_at  timestamp default now(),
  updated_by  uuid references admins(id)
);

ALTER TABLE configuration ENABLE ROW LEVEL SECURITY;

-- Public peut lire tout sauf api_key
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='configuration' AND policyname='public_read_non_api') THEN
    CREATE POLICY public_read_non_api ON configuration FOR SELECT USING (type != 'api_key');
  END IF;
END $$;

-- ─── 14. TABLE PAGES_CONTENU (CMS) ───────────────────────
CREATE TABLE IF NOT EXISTS pages_contenu (
  id               uuid primary key default gen_random_uuid(),
  slug             text unique not null,
  titre            text,
  contenu          text,
  meta_description text,
  actif            boolean default true,
  created_at       timestamp default now(),
  updated_at       timestamp default now(),
  updated_by       uuid references admins(id)
);

ALTER TABLE pages_contenu ENABLE ROW LEVEL SECURITY;

-- Public peut lire les pages actives
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='pages_contenu' AND policyname='public_read_active') THEN
    CREATE POLICY public_read_active ON pages_contenu FOR SELECT USING (actif = true);
  END IF;
END $$;

-- ─── 15. VALEURS PAR DÉFAUT — CONFIGURATION ──────────────
INSERT INTO configuration (cle, valeur, type, categorie, label, description) VALUES
  ('site_nom',              'ParlonsNation',        'text',    'general',   'Nom du site',              'Affiché dans la navigation'),
  ('site_slogan',           'Votre nation, votre voix.', 'text', 'general', 'Slogan',                   'Affiché sur la page d''accueil'),
  ('site_description',      'Plateforme de consultation citoyenne sur le débat constitutionnel de la RDC. Neutre, sécurisée, accessible à tous.', 'text', 'general', 'Description', 'Description du site (footer)'),
  ('inscriptions_ouvertes', 'true',                 'boolean', 'general',   'Inscriptions ouvertes',    'Autoriser les nouvelles inscriptions'),
  ('votes_ouverts',         'true',                 'boolean', 'general',   'Votes ouverts',            'Autoriser les votes'),
  ('forum_ouvert',          'true',                 'boolean', 'general',   'Forum ouvert',             'Autoriser les commentaires'),
  ('afficher_resultats',    'true',                 'boolean', 'general',   'Résultats visibles',       'Rendre les résultats publics'),
  ('score_min_vote',        '0',                    'number',  'general',   'Score min. pour voter',    '0 = désactivé. Score de vérification requis.'),
  ('message_fermeture',     '',                     'text',    'contenu',   'Message fermeture',        'Affiché quand inscriptions/votes sont fermés'),
  ('couleur_principale',    '#0F6E56',              'color',   'apparence', 'Couleur principale',       'Couleur verte principale'),
  ('couleur_accent',        '#F7C518',              'color',   'apparence', 'Couleur accent (or)',      'Couleur dorée'),
  ('couleur_rouge',         '#CE1020',              'color',   'apparence', 'Couleur rouge',            'Couleur rouge RDC'),
  ('api_africas_talking_key',   '',                 'api_key', 'api',       'Africa''s Talking Key',   'Clé API SMS'),
  ('api_africas_talking_sender','ParlonsNation',    'text',    'api',       'AT Sender ID',             'ID expéditeur SMS'),
  ('api_mindee_key',        '',                     'api_key', 'api',       'Mindee API Key',           'Clé OCR pour les CIN'),
  ('api_maps_key',          '',                     'api_key', 'api',       'Google Maps API Key',      'Géolocalisation')
ON CONFLICT (cle) DO NOTHING;

-- ─── 16. VALEURS PAR DÉFAUT — PAGES ──────────────────────
INSERT INTO pages_contenu (slug, titre, contenu, meta_description) VALUES
  ('a_propos',       'À propos de ParlonsNation',
   '<h2>Notre mission</h2><p>ParlonsNation est une plateforme de consultation citoyenne créée pour permettre à tous les Congolais de s''exprimer sur le débat constitutionnel de la RDC.</p>',
   'En savoir plus sur ParlonsNation'),
  ('confidentialite','Politique de confidentialité',
   '<h2>Protection de vos données</h2><p>Votre numéro CIN n''est jamais stocké en clair. Il est converti en empreinte numérique (hash SHA-256) et ne peut pas être retrouvé.</p>',
   'Politique de confidentialité'),
  ('banniere_accueil','Bannière d''accueil',
   'La République Démocratique du Congo est à un tournant historique. Le débat sur notre constitution nous concerne tous. Faites entendre votre voix, partout où vous êtes.',
   'Texte de la bannière principale'),
  ('faq',            'Questions fréquentes',
   '<h2>FAQ</h2><h3>Qui peut participer ?</h3><p>Tout citoyen congolais majeur, qu''il soit en RDC ou en diaspora.</p><h3>Mon vote est-il anonyme ?</h3><p>Oui, en mode anonyme votre identité n''est jamais associée à votre vote dans les résultats publics.</p>',
   'Questions fréquentes sur ParlonsNation')
ON CONFLICT (slug) DO NOTHING;

-- ─── 17. FONCTIONS ADMIN CMS ─────────────────────────────

-- Mettre à jour une configuration
CREATE OR REPLACE FUNCTION admin_set_config(p_admin_id uuid, p_cle text, p_valeur text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE; v_type text;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Non autorisé'); END IF;

  SELECT type INTO v_type FROM configuration WHERE cle = p_cle;

  UPDATE configuration
  SET valeur = p_valeur, updated_at = now(), updated_by = p_admin_id
  WHERE cle = p_cle;

  IF NOT FOUND THEN
    INSERT INTO configuration (cle, valeur, updated_by) VALUES (p_cle, p_valeur, p_admin_id);
  END IF;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'set_config', jsonb_build_object(
    'cle', p_cle,
    'valeur', CASE WHEN v_type = 'api_key' THEN '***' ELSE p_valeur END
  ));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Lire les clés API (super_admin seulement)
CREATE OR REPLACE FUNCTION admin_get_api_keys(p_admin_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins
  WHERE id = p_admin_id AND actif = true AND role = 'super_admin';
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Réservé aux super admins'); END IF;

  RETURN jsonb_build_object('success', true, 'keys',
    (SELECT jsonb_object_agg(cle, valeur) FROM configuration WHERE type = 'api_key')
  );
END;
$$;

-- Sauvegarder / créer une page de contenu
CREATE OR REPLACE FUNCTION admin_save_page(
  p_admin_id       uuid,
  p_slug           text,
  p_titre          text,
  p_contenu        text,
  p_meta_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Non autorisé'); END IF;

  INSERT INTO pages_contenu (slug, titre, contenu, meta_description, updated_at, updated_by)
  VALUES (p_slug, p_titre, p_contenu, p_meta_description, now(), p_admin_id)
  ON CONFLICT (slug) DO UPDATE SET
    titre            = EXCLUDED.titre,
    contenu          = EXCLUDED.contenu,
    meta_description = EXCLUDED.meta_description,
    updated_at       = now(),
    updated_by       = p_admin_id;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'save_page', jsonb_build_object('slug', p_slug, 'titre', p_titre));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Lister les admins (super_admin seulement, sans hash)
CREATE OR REPLACE FUNCTION admin_list_admins(p_admin_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE; v_result jsonb;
BEGIN
  SELECT * INTO v_admin FROM admins
  WHERE id = p_admin_id AND actif = true AND role = 'super_admin';
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Réservé aux super admins'); END IF;

  SELECT jsonb_agg(jsonb_build_object(
    'id', id::text, 'email', email, 'role', role,
    'actif', actif, 'created_at', created_at, 'last_login', last_login
  ) ORDER BY created_at) INTO v_result FROM admins;

  RETURN jsonb_build_object('success', true, 'admins', COALESCE(v_result, '[]'::jsonb));
END;
$$;

-- Créer un nouvel admin (super_admin seulement)
CREATE OR REPLACE FUNCTION admin_create_admin(
  p_admin_id uuid, p_email text, p_password text, p_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins
  WHERE id = p_admin_id AND actif = true AND role = 'super_admin';
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Réservé aux super admins'); END IF;

  IF p_role NOT IN ('super_admin','moderateur','analyste','partenaire_api') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Rôle invalide');
  END IF;

  INSERT INTO admins (email, password_hash, role)
  VALUES (p_email, encode(digest(p_password, 'sha256'), 'hex'), p_role);

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'create_admin', jsonb_build_object('email', p_email, 'role', p_role));

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', false, 'message', 'Cet email est déjà utilisé');
END;
$$;

-- Activer / désactiver un admin (super_admin seulement)
CREATE OR REPLACE FUNCTION admin_toggle_admin(p_admin_id uuid, p_target_id uuid, p_actif boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins
  WHERE id = p_admin_id AND actif = true AND role = 'super_admin';
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Réservé aux super admins'); END IF;
  IF p_admin_id = p_target_id THEN
    RETURN jsonb_build_object('success', false, 'message', 'Impossible de se désactiver soi-même');
  END IF;

  UPDATE admins SET actif = p_actif WHERE id = p_target_id;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'toggle_admin', jsonb_build_object('target', p_target_id, 'actif', p_actif));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ─── 18. CORRECTIFS ET COMPLÉMENTS ──────────────────────

-- Ajouter nom_complet sur admins (si absent)
ALTER TABLE admins ADD COLUMN IF NOT EXISTS nom_complet text;

-- Autoriser la lecture publique des provinces (correction filtre dashboard)
DO $$ BEGIN
  BEGIN
    ALTER TABLE provinces ENABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN others THEN NULL; END;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='provinces' AND policyname='provinces_public_read') THEN
    EXECUTE 'CREATE POLICY provinces_public_read ON provinces FOR SELECT USING (true)';
  END IF;
END $$;

-- get_admins() : lecture simple sans restriction de rôle (le dashboard vérifie déjà l'auth)
CREATE OR REPLACE FUNCTION get_admins()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT jsonb_agg(jsonb_build_object(
      'id',                id::text,
      'email',             email,
      'nom_complet',       nom_complet,
      'role',              role,
      'actif',             actif,
      'derniere_connexion', last_login,
      'created_at',        created_at
    ) ORDER BY created_at)
    FROM admins
  );
END;
$$;

-- admin_set_config : accepte maintenant un type optionnel
CREATE OR REPLACE FUNCTION admin_set_config(
  p_admin_id uuid,
  p_cle      text,
  p_valeur   text,
  p_type     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE; v_existing_type text;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Non autorisé'); END IF;

  SELECT type INTO v_existing_type FROM configuration WHERE cle = p_cle;

  UPDATE configuration
  SET valeur = p_valeur,
      type   = COALESCE(p_type, v_existing_type, 'text'),
      updated_at = now(), updated_by = p_admin_id
  WHERE cle = p_cle;

  IF NOT FOUND THEN
    INSERT INTO configuration (cle, valeur, type, updated_by)
    VALUES (p_cle, p_valeur, COALESCE(p_type, 'text'), p_admin_id);
  END IF;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'set_config', jsonb_build_object(
    'cle', p_cle,
    'valeur', CASE WHEN COALESCE(p_type, v_existing_type) = 'api_key' THEN '***' ELSE p_valeur END
  ));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- admin_save_page : accepte maintenant p_actif
CREATE OR REPLACE FUNCTION admin_save_page(
  p_admin_id         uuid,
  p_slug             text,
  p_titre            text,
  p_contenu          text,
  p_actif            boolean DEFAULT true,
  p_meta_description text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Non autorisé'); END IF;

  INSERT INTO pages_contenu (slug, titre, contenu, actif, meta_description, updated_at, updated_by)
  VALUES (p_slug, p_titre, p_contenu, p_actif, p_meta_description, now(), p_admin_id)
  ON CONFLICT (slug) DO UPDATE SET
    titre            = EXCLUDED.titre,
    contenu          = EXCLUDED.contenu,
    actif            = EXCLUDED.actif,
    meta_description = EXCLUDED.meta_description,
    updated_at       = now(),
    updated_by       = p_admin_id;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'save_page', jsonb_build_object('slug', p_slug, 'titre', p_titre));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- admin_create_admin : accepte maintenant p_password_hash (hash SHA-256 côté client) + p_nom_complet
CREATE OR REPLACE FUNCTION admin_create_admin(
  p_admin_id    uuid,
  p_email       text,
  p_password_hash text,
  p_nom_complet text DEFAULT NULL,
  p_role        text DEFAULT 'moderateur'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true AND role = 'super_admin';
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Réservé aux super admins'); END IF;

  IF p_role NOT IN ('super_admin','moderateur','analyste','partenaire_api') THEN
    RETURN jsonb_build_object('success', false, 'message', 'Rôle invalide');
  END IF;

  INSERT INTO admins (email, password_hash, nom_complet, role)
  VALUES (p_email, p_password_hash, p_nom_complet, p_role);

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'create_admin', jsonb_build_object('email', p_email, 'role', p_role));

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('success', false, 'message', 'Cet email est déjà utilisé');
END;
$$;

-- admin_change_password : changer son propre mot de passe
CREATE OR REPLACE FUNCTION admin_change_password(
  p_admin_id    uuid,
  p_old_hash    text,
  p_new_hash    text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_admin admins%ROWTYPE;
BEGIN
  SELECT * INTO v_admin FROM admins WHERE id = p_admin_id AND actif = true;
  IF NOT FOUND THEN RETURN jsonb_build_object('success', false, 'message', 'Admin introuvable'); END IF;
  IF v_admin.password_hash != p_old_hash THEN
    RETURN jsonb_build_object('success', false, 'message', 'Ancien mot de passe incorrect');
  END IF;

  UPDATE admins SET password_hash = p_new_hash WHERE id = p_admin_id;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (p_admin_id, 'change_password', jsonb_build_object('email', v_admin.email));

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Mise à jour du mot de passe de l'admin initial (K!n$h@sa2026-DRC#Libre)
UPDATE admins
SET password_hash = encode(digest('K!n$h@sa2026-DRC#Libre', 'sha256'), 'hex')
WHERE email = 'admin@parlonsnation.com';

-- ═══════════════════════════════════════════════════════════
-- FIN DE MIGRATION
-- Vérification : SELECT column_name FROM information_schema.columns WHERE table_name = 'citoyens';
-- ═══════════════════════════════════════════════════════════
