// Prisma 7 exposes Decimal on the Prisma namespace; there is no
// `@prisma/client/runtime/library` entry point any more.
const { Prisma } = require('@prisma/client');
const { Decimal } = Prisma;

// The Flutter app reads `_id` from request and completed-document objects
// (dashboard_screen.dart, my_requests_screen.dart) and casts money fields with
// `as num?`. Prisma returns `id` and serialises Decimal as a string, so every
// row handed to res.json() goes through here first:
//
//   - `_id` is added alongside `id`, so existing clients keep working
//   - Decimal becomes a JS number, so `as num?` still parses
//   - null email becomes '' — Mongo stored the empty string, and the app
//     expects a string rather than null
//
// Once the Flutter side reads `id` instead of `_id`, the alias can be dropped.
function toApi(value) {
  if (value === null || value === undefined) return value;

  if (Array.isArray(value)) return value.map(toApi);

  if (value instanceof Date) return value;

  if (Decimal.isDecimal?.(value) || value instanceof Decimal) {
    return value.toNumber();
  }

  if (typeof value === 'object') {
    // Leave Buffers and other exotic types alone.
    if (Buffer.isBuffer(value)) return value;

    const out = {};
    for (const [k, v] of Object.entries(value)) out[k] = toApi(v);
    if (out.id !== undefined && out._id === undefined) out._id = out.id;
    if ('email' in out && out.email === null) out.email = '';
    return out;
  }

  return value;
}

module.exports = { toApi };
