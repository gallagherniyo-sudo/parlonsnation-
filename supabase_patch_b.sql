-- ═══════════════════════════════════════════════════════════
-- ParlonsNation — PATCH B : Clés de configuration manquantes
-- À coller dans Supabase > SQL Editor > New Query > Run
-- (Run APRÈS supabase_etape_a.sql)
-- ═══════════════════════════════════════════════════════════

INSERT INTO configuration (cle, valeur, type) VALUES

  -- ── 1. Clés générales absentes ─────────────────────────
  ('inscriptions_ouvertes',           'true',                        'boolean'),
  ('votes_ouverts',                   'true',                        'boolean'),
  ('forum_ouvert',                    'true',                        'boolean'),
  ('site_slogan',                     'Votre nation, votre voix.',   'text'),
  ('couleur_principale',              '#2D6A2E',                     'color'),
  ('couleur_accent',                  '#F4A900',                     'color'),
  ('couleur_rouge',                   '#CE1020',                     'color'),

  -- ── 2. Photos CIN : préfixe champ_ cohérent ────────────
  -- (etape_a avait photo_cin_recto_actif sans préfixe champ_)
  ('champ_photo_cin_recto_actif',     'true',                        'boolean'),
  ('champ_photo_cin_recto_obligatoire','false',                      'boolean'),
  ('champ_photo_cin_verso_actif',     'true',                        'boolean'),
  ('champ_photo_cin_verso_obligatoire','false',                      'boolean'),

  -- ── 3. OTP, OCR, GPS : actif + obligatoire ─────────────
  -- (etape_a n'avait que otp_sms_obligatoire / ocr_cin_obligatoire / gps_obligatoire)
  ('champ_otp_sms_actif',             'true',                        'boolean'),
  ('champ_otp_sms_obligatoire',       'true',                        'boolean'),
  ('champ_ocr_cin_actif',             'false',                       'boolean'),
  ('champ_ocr_cin_obligatoire',       'false',                       'boolean'),
  ('champ_gps_actif',                 'false',                       'boolean'),
  ('champ_gps_obligatoire',           'false',                       'boolean')

ON CONFLICT (cle) DO NOTHING;

-- ── Vérification ─────────────────────────────────────────
-- SELECT cle, valeur, type FROM configuration
-- WHERE cle IN (
--   'inscriptions_ouvertes','votes_ouverts','forum_ouvert',
--   'site_slogan','couleur_principale','couleur_accent','couleur_rouge',
--   'champ_photo_cin_recto_actif','champ_otp_sms_actif','champ_gps_actif'
-- )
-- ORDER BY cle;
