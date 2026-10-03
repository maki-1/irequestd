const crypto = require('crypto');

/**
 * Signed, expiring links that let a Purok Leader approve from email without
 * logging in. The link carries the leader's id, expiry, session version and an
 * HMAC over them. Current account state is checked on each use. It can only
 * ever authorise approvals for that one leader's own purok.
 *
 * APPROVE_LINK_SECRET must be set (and identical on every backend that builds a
 * link). Without it the feature refuses to sign, so a link is never emitted
 * that the server cannot later verify.
 */

const TTL_MS = 7 * 24 * 60 * 60 * 1000; // a week — long enough for a slow reply

function portalUrl(env = process.env) {
  const value = String(env.PORTAL_URL || '').trim() || (env.NODE_ENV === 'production' ? '' : 'http://localhost:5173');
  try {
    const url = new URL(value);
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) return null;
    if (url.pathname !== '/') return null;
    if (env.NODE_ENV === 'production' && (url.protocol !== 'https:' || /^(localhost|127\.|\[::1\]|0\.0\.0\.0)/i.test(url.hostname))) return null;
    return url.origin;
  } catch { return null; }
}

function secret() {
  const s = process.env.APPROVE_LINK_SECRET;
  if (!s) throw new Error('APPROVE_LINK_SECRET is not configured');
  return s;
}

function sign(leaderId, exp, version) {
  return crypto.createHmac('sha256', secret()).update(`${leaderId}.${exp}.${version}`).digest('hex');
}

// Returns approval parameters (lid, exp, sig, v), or null if signing is not
// configured. Callers fall back to the normal portal sign-in page.
function tokenParams(leaderId, version) {
  try {
    if (!Number.isSafeInteger(version) || version < 0) return null;
    const exp = Date.now() + TTL_MS;
    const sig = sign(leaderId, exp, version);
    return { lid: leaderId, exp, sig, v: version };
  } catch {
    return null;
  }
}

// Full tap-to-approve URL, or null if it cannot be signed.
function buildLink(portalBase, leaderId, version) {
  const base = portalUrl({ PORTAL_URL: portalBase, NODE_ENV: process.env.NODE_ENV });
  if (!base) return null;
  const t = tokenParams(leaderId, version);
  if (!t) return null;
  return `${base}/purok-approve?lid=${encodeURIComponent(t.lid)}&exp=${t.exp}&sig=${t.sig}&v=${t.v}`;
}

// Verifies a link's params. Returns the leaderId when valid, else null.
function verify({ lid, exp, sig, v }) {
  if (!lid || !exp || !sig) return null;
  if (v === undefined || v === null || !/^\d+$/.test(String(v))) return null;
  const version = Number(v);
  if (!Number.isSafeInteger(version)) return null;
  const expNum = Number(exp);
  if (!Number.isFinite(expNum) || expNum < Date.now()) return null; // expired
  let expected;
  try { expected = sign(lid, expNum, version); } catch { return null; }
  const a = Buffer.from(String(sig));
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  return lid;
}

module.exports = { buildLink, tokenParams, verify, TTL_MS, portalUrl };
