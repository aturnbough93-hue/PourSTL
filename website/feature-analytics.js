(function () {
  'use strict';

  // Privacy boundary: only these coarse action names may leave the browser.
  // Never add recipe names, ingredient names, user-entered text, identifiers,
  // or precise location data to this endpoint.
  const allowedEvents = new Set([
    'app_open',
    'recipe_view',
    'my_bar_add',
    'my_bar_remove',
    'shopping_list_add',
    'custom_recipe_save',
    'serving_scale',
    'unit_toggle',
    'timer_start',
    'timer_complete',
    'assistant_open',
    'assistant_turn_success',
    'assistant_turn_failure',
  ]);

  function eventPath() {
    try {
      const path = window.location && window.location.pathname;
      return path === '/try' || path === '/try.html' ? path : '/try';
    } catch (_) {
      return '/try';
    }
  }

  function track(name) {
    if (!allowedEvents.has(name)) return false;
    const body = JSON.stringify({ events: [{ name, path: eventPath() }] });
    try {
      if (typeof window.fetch === 'function') {
        window.fetch('/api/analytics', {
          method: 'POST',
          body,
          headers: { 'content-type': 'application/json' },
          credentials: 'omit',
          referrerPolicy: 'no-referrer',
          keepalive: true,
        }).catch(() => {});
        return true;
      }
    } catch (_) {
      // Analytics must never interrupt the local-first app.
    }
    return false;
  }

  window.PourFeatureAnalytics = Object.freeze({ track });
})();
