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
  ('afficher_resultats',             'true',                                                                  'boolean'),
  ('message_fermeture',              'Le site est temporairement fermé.',                                     'text'),
  ('bandeau_texte',                  '📢 Consultation ouverte à tous les Congolais — en RDC et en diaspora. Vote anonyme et sécurisé.', 'text'),
  ('bandeau_actif',                  'true',                                                                  'boolean'),
  ('copyright_texte',                '© 2026 ParlonsNation — Tous droits réservés',                          'text'),
  ('nb_provinces',                   '26',                                                                    'number'),
  ('question_principale',            'Que faut-il faire de la Constitution de la République Démocratique du Congo ?', 'text'),
  ('couleur_option_a',               '#2563EB',                                                               'color'),
  ('couleur_option_b',               '#7C3AED',                                                               'color'),
  ('couleur_option_c',               '#CE1020',                                                               'color'),
  ('couleur_option_d',               '#6B7280',                                                               'color'),
  ('africastalking_username',        '',                                                                      'text'),
  ('label_option_a',                 'Changer totalement',                                                    'text'),
  ('label_option_b',                 'Réviser partiellement',                                                 'text'),
  ('label_option_c',                 'Conserver telle quelle',                                                'text'),
  ('label_option_d',                 'Abstention',                                                            'text'),
  ('desc_option_a',                  'Rédiger une toute nouvelle constitution',                               'text'),
  ('desc_option_b',                  'Modifier certains articles spécifiques',                                'text'),
  ('desc_option_c',                  'Garder la constitution actuelle sans modification',                     'text'),
  ('desc_option_d',                  'Je ne me prononce pas sur cette question',                              'text'),
  ('champ_nom_actif',                'true',                                                                  'boolean'),
  ('champ_nom_obligatoire',          'true',                                                                  'boolean'),
  ('champ_post_nom_actif',           'true',                                                                  'boolean'),
  ('champ_post_nom_obligatoire',     'true',                                                                  'boolean'),
  ('champ_prenom_actif',             'true',                                                                  'boolean'),
  ('champ_prenom_obligatoire',       'true',                                                                  'boolean'),
  ('champ_date_naissance_actif',     'true',                                                                  'boolean'),
  ('champ_date_naissance_obligatoire','true',                                                                 'boolean'),
  ('champ_sexe_actif',               'true',                                                                  'boolean'),
  ('champ_sexe_obligatoire',         'false',                                                                 'boolean'),
  ('champ_cin_actif',                'true',                                                                  'boolean'),
  ('champ_cin_obligatoire',          'true',                                                                  'boolean'),
  ('champ_photo_cin_recto_actif',     'true',                                                                  'boolean'),
  ('champ_photo_cin_recto_obligatoire','false',                                                               'boolean'),
  ('champ_photo_cin_verso_actif',    'true',                                                                  'boolean'),
  ('champ_photo_cin_verso_obligatoire','false',                                                               'boolean'),
  ('champ_otp_sms_actif',            'true',                                                                  'boolean'),
  ('champ_otp_sms_obligatoire',      'true',                                                                  'boolean'),
  ('champ_ocr_cin_actif',            'false',                                                                 'boolean'),
  ('champ_ocr_cin_obligatoire',      'false',                                                                 'boolean'),
  ('champ_gps_actif',                'false',                                                                 'boolean'),
  ('champ_gps_obligatoire',          'false',                                                                 'boolean'),
  ('inscriptions_ouvertes',          'true',                                                                  'boolean'),
  ('votes_ouverts',                  'true',                                                                  'boolean'),
  ('forum_ouvert',                   'true',                                                                  'boolean'),
  ('site_slogan',                    'Votre nation, votre voix.',                                             'text'),
  ('couleur_principale',             '#2D6A2E',                                                              'color'),
  ('couleur_accent',                 '#F4A900',                                                              'color'),
  ('couleur_rouge',                  '#CE1020',                                                              'color'),
  ('age_minimum',                    '18',                                                                    'number'),
  ('champ_territoire_actif',         'true',                                                                  'boolean'),
  ('champ_territoire_obligatoire',   'false',                                                                 'boolean')
ON CONFLICT (cle) DO NOTHING;

-- 3. VÉRIFICATIONS (copier séparément après insertion)
-- SELECT id, titre, actif FROM sujets;
-- SELECT cle, valeur, type FROM configuration ORDER BY type, cle;
