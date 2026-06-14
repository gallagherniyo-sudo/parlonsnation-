-- ═══════════════════════════════════════════════════════════
-- ParlonsNation — FIX : admin_set_config unique (3 paramètres)
-- Supprime l'ambiguïté "Could not choose best candidate function"
-- À coller dans Supabase > SQL Editor > New Query > Run
-- ═══════════════════════════════════════════════════════════

-- 1. Supprimer les deux versions en conflit
DROP FUNCTION IF EXISTS admin_set_config(uuid, text, text);
DROP FUNCTION IF EXISTS admin_set_config(uuid, text, text, text);

-- 2. Recréer une seule version propre (3 params)
--    - Préserve le type existant lors d'un UPDATE
--    - Masque la valeur dans les logs si type='api_key'
--    - INSERT avec type='text' si clé inconnue (cas rare)
CREATE OR REPLACE FUNCTION admin_set_config(
  p_admin_id uuid,
  p_cle      text,
  p_valeur   text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_existing_type text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM admins WHERE id = p_admin_id AND actif = true
  ) THEN
    RETURN jsonb_build_object('success', false, 'message', 'Non autorisé');
  END IF;

  SELECT type INTO v_existing_type FROM configuration WHERE cle = p_cle;

  IF FOUND THEN
    UPDATE configuration
    SET valeur     = p_valeur,
        updated_at = now(),
        updated_by = p_admin_id
    WHERE cle = p_cle;
  ELSE
    -- Clé inconnue (ne devrait pas arriver si les scripts seed ont tourné)
    INSERT INTO configuration (cle, valeur, type, updated_by)
    VALUES (p_cle, p_valeur, 'text', p_admin_id);
  END IF;

  INSERT INTO admin_logs (admin_id, action, details)
  VALUES (
    p_admin_id,
    'set_config',
    jsonb_build_object(
      'cle',    p_cle,
      'valeur', CASE WHEN v_existing_type = 'api_key' THEN '***' ELSE p_valeur END
    )
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Vérification
-- SELECT proname, pg_get_function_identity_arguments(oid)
-- FROM pg_proc WHERE proname = 'admin_set_config';
-- → doit retourner exactement 1 ligne : admin_set_config(uuid, text, text)
