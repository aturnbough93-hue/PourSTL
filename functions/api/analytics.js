const MAX_EVENTS_PER_BATCH = 20;
const MAX_BODY_BYTES = 4096;

const ALLOWED_EVENTS = new Set([
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

const ALLOWED_PATHS = new Set(['/try', '/try.html']);

function json(data, status) {
  return Response.json(data, {
    status,
    headers: { 'cache-control': 'no-store' },
  });
}

function validEvent(entry) {
  if (!entry || typeof entry !== 'object') return null;
  const name = entry.name;
  if (typeof name !== 'string' || !ALLOWED_EVENTS.has(name)) return null;
  const path = typeof entry.path === 'string' && ALLOWED_PATHS.has(entry.path) ? entry.path : '/try';
  return { name, path };
}

export async function onRequestPost(context) {
  const { request, env } = context;
  if (!env.FEATURE_ANALYTICS) return json({ error: 'Analytics unavailable' }, 503);

  const contentType = request.headers.get('content-type') || '';
  if (!contentType.toLowerCase().includes('application/json')) {
    return json({ error: 'Expected application/json' }, 415);
  }

  const contentLength = Number(request.headers.get('content-length') || 0);
  if (contentLength > MAX_BODY_BYTES) return json({ error: 'Request too large' }, 413);

  let payload;
  try {
    const body = await request.text();
    if (body.length > MAX_BODY_BYTES) return json({ error: 'Request too large' }, 413);
    payload = JSON.parse(body);
  } catch {
    return json({ error: 'Invalid JSON' }, 400);
  }

  if (!payload || typeof payload !== 'object' || !Array.isArray(payload.events)) {
    return json({ error: 'Expected an events array' }, 400);
  }
  if (payload.events.length === 0 || payload.events.length > MAX_EVENTS_PER_BATCH) {
    return json({ error: 'Expected 1 to 20 events' }, 400);
  }

  const events = payload.events.map(validEvent);
  if (events.some(event => event === null)) {
    return json({ error: 'Unsupported event' }, 400);
  }

  for (const event of events) {
    env.FEATURE_ANALYTICS.writeDataPoint({
      indexes: [event.name],
      blobs: ['web_try', event.path],
      doubles: [1],
    });
  }

  return json({ accepted: events.length }, 202);
}

export function onRequest() {
  return json({ error: 'Method not allowed' }, 405);
}
