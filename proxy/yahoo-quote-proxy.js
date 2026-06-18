// Yahoo Finance quote proxy for PulseVest (海外基金估值).
//
// Returns session-aware change % (pre-market / regular / post-market) for a
// batch of US symbols — the data mainland China can't reach directly.
//
// Deploy on any host that BOTH can reach Yahoo AND is reachable from mainland
// China (e.g. a Hong Kong / overseas serverless function, or Cloudflare Workers
// with a custom domain). Cloudflare Workers: paste this into a new Worker.
// Deno Deploy: replace the last line with `Deno.serve(handle);`.
//
//   GET /?symbols=NVDA,AAPL,QQQ,SPY,CNY=X
//   ->  {"NVDA":1.22,"AAPL":0.54,"QQQ":1.69,"SPY":0.84,"CNY=X":-0.02}
//
// Values are the % change appropriate to the current US session, so during
// pre/post market they reflect the extended-hours move (incl. pre/post).

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

let _crumb = null;
let _cookie = null;
let _crumbAt = 0;

async function ensureCrumb(force) {
  if (!force && _crumb && _cookie && Date.now() - _crumbAt < 3600_000) return;
  const r1 = await fetch('https://fc.yahoo.com', { headers: { 'User-Agent': UA } });
  let cookie = '';
  if (typeof r1.headers.getSetCookie === 'function') {
    cookie = r1.headers.getSetCookie().map((c) => c.split(';')[0]).join('; ');
  } else {
    const sc = r1.headers.get('set-cookie') || '';
    cookie = sc.split(/,(?=[^ ;]+=)/).map((c) => c.split(';')[0]).join('; ');
  }
  const r2 = await fetch('https://query1.finance.yahoo.com/v1/test/getcrumb', {
    headers: { 'User-Agent': UA, Cookie: cookie },
  });
  _crumb = (await r2.text()).trim();
  _cookie = cookie;
  _crumbAt = Date.now();
}

// Cumulative % move since the prior regular close, in the stock's OWN market.
// This works across markets/sessions: a US stock during US pre-market uses its
// pre-market move (0 if it didn't trade — it's still at the close), while an HK
// or A-share stock (whose own market has already closed for the day, so Yahoo
// reports marketState POST/POSTPOST/CLOSED) uses its full regular-session move.
function pickChange(q) {
  const st = q.marketState;
  const reg = q.regularMarketChangePercent;
  const pre = q.preMarketChangePercent;
  const post = q.postMarketChangePercent;
  if (st === 'PRE') {
    // Before today's open: only the pre-market move counts (0 if not traded).
    return pre != null ? pre : 0;
  }
  if (st === 'POST' || st === 'POSTPOST') {
    // Day's regular session done; add any after-hours move on top of it.
    return (reg != null ? reg : 0) + (post != null ? post : 0);
  }
  // REGULAR / CLOSED / other: the regular-session change from the prior close.
  return reg != null ? reg : 0;
}

async function quoteChunk(chunk) {
  const make = () =>
    'https://query1.finance.yahoo.com/v7/finance/quote?symbols=' +
    encodeURIComponent(chunk) + '&crumb=' + encodeURIComponent(_crumb);
  let r = await fetch(make(), { headers: { 'User-Agent': UA, Cookie: _cookie } });
  if (r.status === 401 || r.status === 403) {
    await ensureCrumb(true); // crumb expired — refresh and retry once
    r = await fetch(make(), { headers: { 'User-Agent': UA, Cookie: _cookie } });
  }
  if (!r.ok) return [];
  const j = await r.json();
  return (j.quoteResponse && j.quoteResponse.result) || [];
}

async function fetchQuotes(symbols) {
  await ensureCrumb(false);
  const out = {};
  for (let i = 0; i < symbols.length; i += 50) {
    const results = await quoteChunk(symbols.slice(i, i + 50).join(','));
    for (const q of results) {
      const pct = pickChange(q);
      if (pct != null && q.symbol) out[q.symbol] = Math.round(pct * 100) / 100;
    }
  }
  return out;
}

async function handle(request) {
  const url = new URL(request.url);
  const symbols = (url.searchParams.get('symbols') || '')
    .split(',').map((s) => s.trim()).filter(Boolean);
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  };
  if (!symbols.length) return new Response('{}', { headers });
  try {
    const data = await fetchQuotes(symbols);
    return new Response(JSON.stringify(data), { headers });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers,
    });
  }
}

// Cloudflare Workers (module syntax):
export default { fetch: handle };

// Deno Deploy — use this instead of the line above:
// Deno.serve(handle);
