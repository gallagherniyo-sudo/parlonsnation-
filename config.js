/**
 * ParlonsNation — config.js
 * Charge la configuration depuis Supabase et l'applique sur la page courante.
 * À inclure APRÈS le CDN Supabase sur toutes les pages publiques.
 */
(function () {
  const SUPABASE_URL = 'https://yagvezgfmxvrnngrxeuv.supabase.co';
  const SUPABASE_KEY = 'sb_publishable_ZwpN3mfLueArH7Iq_dJdYA_4ZxY2Ke_';

  async function applyConfig() {
    if (!window.supabase) { console.warn('[PNConfig] Supabase non chargé'); return; }

    const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

    // Charger toutes les configs non-api_key (les clés API ne sont jamais exposées côté client)
    const { data, error } = await db
      .from('configuration')
      .select('cle,valeur,type')
      .neq('type', 'api_key');

    if (error) { console.warn('[PNConfig] Erreur chargement config:', error.message); return; }

    // Construire l'objet config avec les bons types
    const cfg = {};
    (data || []).forEach(({ cle, valeur, type }) => {
      if (type === 'boolean') cfg[cle] = valeur === 'true';
      else if (type === 'number') cfg[cle] = valeur !== null ? Number(valeur) : null;
      else cfg[cle] = valeur;
    });

    window.PNConfig = cfg;

    // ── Appliquer les couleurs CSS ────────────────────────
    const root = document.documentElement;
    if (cfg.couleur_principale) root.style.setProperty('--green',   cfg.couleur_principale);
    if (cfg.couleur_accent)     root.style.setProperty('--gold',    cfg.couleur_accent);
    if (cfg.couleur_rouge)      root.style.setProperty('--red-drc', cfg.couleur_rouge);

    // ── Appliquer les textes data-config ─────────────────
    // Usage: <span data-config="site_slogan"></span>
    // Usage: <div data-config="banniere_accueil" data-config-html></div>
    document.querySelectorAll('[data-config]').forEach(el => {
      const key = el.dataset.config;
      if (cfg[key] === undefined || cfg[key] === null) return;
      if ('configHtml' in el.dataset) el.innerHTML = String(cfg[key]);
      else el.textContent = String(cfg[key]);
    });

    // ── Fermeture des inscriptions ────────────────────────
    // Usage: <div data-require="inscriptions">...</div>   → caché si fermé
    // Usage: <div data-closed="inscriptions">...</div>    → visible si fermé
    if (cfg.inscriptions_ouvertes === false) {
      document.querySelectorAll('[data-require="inscriptions"]').forEach(el => {
        el.style.display = 'none';
      });
      document.querySelectorAll('[data-closed="inscriptions"]').forEach(el => {
        el.style.removeProperty('display');
      });
    }

    // ── Fermeture des votes ───────────────────────────────
    if (cfg.votes_ouverts === false) {
      document.querySelectorAll('[data-require="votes"]').forEach(el => {
        el.style.display = 'none';
      });
      document.querySelectorAll('[data-closed="votes"]').forEach(el => {
        el.style.removeProperty('display');
      });
    }

    // ── Fermeture du forum ────────────────────────────────
    if (cfg.forum_ouvert === false) {
      document.querySelectorAll('[data-require="forum"]').forEach(el => {
        el.style.display = 'none';
      });
    }

    // ── Résultats masqués ─────────────────────────────────
    if (cfg.afficher_resultats === false) {
      document.querySelectorAll('[data-require="resultats"]').forEach(el => {
        el.style.display = 'none';
      });
    }

    // ── Message de fermeture global ───────────────────────
    // Usage: <div data-fermeture-msg style="display:none"></div>
    if (cfg.message_fermeture) {
      document.querySelectorAll('[data-fermeture-msg]').forEach(el => {
        el.textContent = cfg.message_fermeture;
        el.style.removeProperty('display');
      });
    }

    // ── Charger le contenu d'une page spécifique ──────────
    // Usage: <div data-page="banniere_accueil"></div>
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

    // ── Émettre un événement pour les scripts dépendants ──
    document.dispatchEvent(new CustomEvent('pn:config', { detail: cfg }));
  }

  // Lancer dès que le DOM est prêt
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applyConfig);
  } else {
    applyConfig();
  }
})();
