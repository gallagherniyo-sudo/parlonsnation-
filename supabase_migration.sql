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
-- FIN DE MIGRATION
-- Vérification : SELECT column_name FROM information_schema.columns WHERE table_name = 'citoyens';
-- ═══════════════════════════════════════════════════════════
