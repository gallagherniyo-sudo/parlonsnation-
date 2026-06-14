/**
 * ParlonsNation — config.js v2
 * Charge toute la configuration depuis Supabase et l'applique sur la page.
 * À inclure APRÈS le CDN Supabase sur toutes les pages publiques.
 */
(function () {
  const SUPABASE_URL = 'https://yagvezgfmxvrnngrxeuv.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_ZwpN3mfLueArH7Iq_dJdYA_4ZxY2Ke_';

  async function applyConfig() {
    if (!window.supabase) { console.warn('[PNConfig] Supabase non chargé'); return; }

    const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

    // Charger toutes les configs non-api_key
    const { data, error } = await db
      .from('configuration')
      .select('cle,valeur,type')
      .neq('type', 'api_key');

    if (error) { console.warn('[PNConfig] Erreur:', error.message); return; }

    // ── Construire window.PNConfig avec typage ────────────
    const cfg = {};
    (data || []).forEach(({ cle, valeur, type }) => {
      if (type === 'booleen' || type === 'boolean') {
        cfg[cle] = valeur === 'true';
      } else if (type === 'nombre' || type === 'number') {
        cfg[cle] = valeur !== null ? Number(valeur) : null;
      } else {
        cfg[cle] = valeur;
      }
    });
    window.PNConfig = cfg;

    // ── Couleurs principales CSS ──────────────────────────
    const root = document.documentElement;
    if (cfg.couleur_principale) root.style.setProperty('--green',   cfg.couleur_principale);
    if (cfg.couleur_accent)     root.style.setProperty('--gold',    cfg.couleur_accent);
    if (cfg.couleur_rouge)      root.style.setProperty('--red-drc', cfg.couleur_rouge);

    // ── Couleurs des 4 options (variables CSS) ────────────
    if (cfg.couleur_option_a) root.style.setProperty('--color-a', cfg.couleur_option_a);
    if (cfg.couleur_option_b) root.style.setProperty('--color-b', cfg.couleur_option_b);
    if (cfg.couleur_option_c) root.style.setProperty('--color-c', cfg.couleur_option_c);
    if (cfg.couleur_option_d) root.style.setProperty('--color-d', cfg.couleur_option_d);

    // ── Exposer les labels/couleurs pour les scripts JS ───
    // Usage: window.PNLabels['A'] → 'Changer totalement'
    window.PNLabels = {
      A: cfg.label_option_a || 'Changer totalement',
      B: cfg.label_option_b || 'Réviser partiellement',
      C: cfg.label_option_c || 'Conserver telle quelle',
      D: cfg.label_option_d || 'Abstention',
    };
    window.PNColors = {
      A: cfg.couleur_option_a || '#2563EB',
      B: cfg.couleur_option_b || '#7C3AED',
      C: cfg.couleur_option_c || '#CE1020',
      D: cfg.couleur_option_d || '#6B7280',
    };
    window.PNDescs = {
      A: cfg.desc_option_a || '',
      B: cfg.desc_option_b || '',
      C: cfg.desc_option_c || '',
      D: cfg.desc_option_d || '',
    };

    // ── Appliquer textes data-config ──────────────────────
    // <span data-config="site_slogan"></span>
    // <div data-config="bandeau_texte" data-config-html></div>
    document.querySelectorAll('[data-config]').forEach(el => {
      const key = el.dataset.config;
      const val = cfg[key];
      if (val === undefined || val === null) return;
      if ('configHtml' in el.dataset) el.innerHTML = String(val);
      else el.textContent = String(val);
    });

    // ── Bandeau d'annonce ─────────────────────────────────
    // Le bandeau doit avoir : id="site-bandeau" et data-config="bandeau_texte"
    // Il est géré par data-config ci-dessus pour le texte
    // Ici on gère l'affichage actif/inactif
    const bandeau = document.getElementById('site-bandeau');
    if (bandeau) {
      bandeau.style.display = cfg.bandeau_actif === false ? 'none' : '';
    }

    // ── Copyright dynamique ───────────────────────────────
    // <span data-config="copyright_texte"></span> géré par data-config ci-dessus
    // Fallback sur les éléments avec class footer-bottom qui contiennent "©"
    if (cfg.copyright_texte) {
      document.querySelectorAll('[data-copyright]').forEach(el => {
        el.textContent = cfg.copyright_texte;
      });
    }

    // ── nb_provinces ──────────────────────────────────────
    if (cfg.nb_provinces !== undefined) {
      document.querySelectorAll('[data-config="nb_provinces"]').forEach(el => {
        el.textContent = String(cfg.nb_provinces);
      });
    }

    // ── Fermeture inscriptions ────────────────────────────
    if (cfg.inscriptions_ouvertes === false) {
      document.querySelectorAll('[data-require="inscriptions"]').forEach(el => el.style.display = 'none');
      document.querySelectorAll('[data-closed="inscriptions"]').forEach(el => el.style.removeProperty('display'));
    }

    // ── Fermeture votes ───────────────────────────────────
    if (cfg.votes_ouverts === false) {
      document.querySelectorAll('[data-require="votes"]').forEach(el => el.style.display = 'none');
      document.querySelectorAll('[data-closed="votes"]').forEach(el => el.style.removeProperty('display'));
    }

    // ── Fermeture forum ───────────────────────────────────
    if (cfg.forum_ouvert === false) {
      document.querySelectorAll('[data-require="forum"]').forEach(el => el.style.display = 'none');
    }

    // ── Résultats masqués ─────────────────────────────────
    if (cfg.afficher_resultats === false) {
      document.querySelectorAll('[data-require="resultats"]').forEach(el => el.style.display = 'none');
    }

    // ── Message fermeture global ──────────────────────────
    if (cfg.message_fermeture) {
      document.querySelectorAll('[data-fermeture-msg]').forEach(el => {
        el.textContent = cfg.message_fermeture;
        el.style.removeProperty('display');
      });
    }

    // ── Contenu pages Supabase ────────────────────────────
    const pageSlugs = new Set();
    document.querySelectorAll('[data-page]').forEach(el => pageSlugs.add(el.dataset.page));
    if (pageSlugs.size > 0) {
      const { data: pages } = await db
        .from('pages_contenu')
        .select('slug,contenu')
        .in('slug', [...pageSlugs])
        .eq('actif', true);
      (pages || []).forEach(p => {
        document.querySelectorAll(`[data-page="${p.slug}"]`).forEach(el => {
          el.innerHTML = p.contenu || '';
        });
      });
    }

    // ── Événement pour les scripts dépendants ─────────────
    // Les scripts qui lisent PNLabels/PNColors doivent écouter cet événement
    // ou tester if (window.PNConfig) directement.
    document.dispatchEvent(new CustomEvent('pn:config', { detail: cfg }));
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyConfig);
  } else {
    applyConfig();
  }
})();
