-- ═══════════════════════════════════════════════════════════
-- ParlonsNation — ÉTAPE A : Données initiales CMS
-- À coller dans Supabase > SQL Editor > New Query > Run
-- ═══════════════════════════════════════════════════════════

-- 1. SUJET DE VOTE (CRITIQUE — sans ça voter.html ne fonctionne pas)
INSERT INTO sujets (titre, description, actif)
VALUES (
  'Que faut-il faire de la Constitution de la RDC ?',
  'Débat constitutionnel national 2026.',
  true
)
ON CONFLICT DO NOTHING;

-- 2. CONFIGURATIONS CMS
INSERT INTO configuration (cle, valeur, type) VALUES
  ('afficher_resultats',             'true',                                                                  'booleen'),
  ('message_fermeture',              'Le site est temporairement fermé.',                                     'texte'),
  ('bandeau_texte',                  '📢 Consultation ouverte à tous les Congolais — en RDC et en diaspora. Vote anonyme et sécurisé.', 'texte'),
  ('bandeau_actif',                  'true',                                                                  'booleen'),
  ('copyright_texte',                '© 2026 ParlonsNation — Tous droits réservés',                          'texte'),
  ('nb_provinces',                   '26',                                                                    'nombre'),
  ('question_principale',            'Que faut-il faire de la Constitution de la République Démocratique du Congo ?', 'texte'),
  ('couleur_option_a',               '#2563EB',                                                               'couleur'),
  ('couleur_option_b',               '#7C3AED',                                                               'couleur'),
  ('couleur_option_c',               '#CE1020',                                                               'couleur'),
  ('couleur_option_d',               '#6B7280',                                                               'couleur'),
  ('africastalking_username',        '',                                                                      'api_key'),
  ('label_option_a',                 'Changer totalement',                                                    'texte'),
  ('label_option_b',                 'Réviser partiellement',                                                 'texte'),
  ('label_option_c',                 'Conserver telle quelle',                                                'texte'),
  ('label_option_d',                 'Abstention',                                                            'texte'),
  ('desc_option_a',                  'Rédiger une toute nouvelle constitution',                               'texte'),
  ('desc_option_b',                  'Modifier certains articles spécifiques',                                'texte'),
  ('desc_option_c',                  'Garder la constitution actuelle sans modification',                     'texte'),
  ('desc_option_d',                  'Je ne me prononce pas sur cette question',                              'texte'),
  ('champ_nom_actif',                'true',                                                                  'booleen'),
  ('champ_nom_obligatoire',          'true',                                                                  'booleen'),
  ('champ_post_nom_actif',           'true',                                                                  'booleen'),
  ('champ_post_nom_obligatoire',     'true',                                                                  'booleen'),
  ('champ_prenom_actif',             'true',                                                                  'booleen'),
  ('champ_prenom_obligatoire',       'true',                                                                  'booleen'),
  ('champ_date_naissance_actif',     'true',                                                                  'booleen'),
  ('champ_date_naissance_obligatoire','true',                                                                 'booleen'),
  ('champ_sexe_actif',               'true',                                                                  'booleen'),
  ('champ_sexe_obligatoire',         'false',                                                                 'booleen'),
  ('champ_cin_actif',                'true',                                                                  'booleen'),
  ('champ_cin_obligatoire',          'true',                                                                  'booleen'),
  ('photo_cin_recto_actif',          'true',                                                                  'booleen'),
  ('photo_cin_recto_obligatoire',    'false',                                                                 'booleen'),
  ('photo_cin_verso_actif',          'true',                                                                  'booleen'),
  ('photo_cin_verso_obligatoire',    'false',                                                                 'booleen'),
  ('otp_sms_obligatoire',            'true',                                                                  'booleen'),
  ('ocr_cin_obligatoire',            'false',                                                                 'booleen'),
  ('gps_obligatoire',                'false',                                                                 'booleen'),
  ('age_minimum',                    '18',                                                                    'nombre'),
  ('champ_territoire_actif',         'true',                                                                  'booleen'),
  ('champ_territoire_obligatoire',   'false',                                                                 'booleen')
ON CONFLICT (cle) DO NOTHING;

-- 3. VÉRIFICATIONS (copier séparément après insertion)
-- SELECT id, titre, actif FROM sujets;
-- SELECT cle, valeur, type FROM configuration ORDER BY type, cle;
