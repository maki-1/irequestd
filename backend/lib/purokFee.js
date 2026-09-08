const prisma = require('./prisma');

// Escape regex metacharacters before building a matcher from stored data.
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * Finds which configured purok an address belongs to.
 *
 * The match is anchored with word boundaries. A plain substring test — which is
 * what both backends did — makes "Purok 1" match "Purok 10, Brgy. Dologon", so
 * a resident of Purok 10 could be charged Purok 1's fee depending on the order
 * rows come back in. `\b` fixes that: "1" followed by "0" is not a boundary,
 * "1" followed by "," is.
 *
 * This is a stopgap. Purok is not stored as a field anywhere — it is recovered
 * from free-text `address` — so a resident who writes their address without a
 * recognisable purok matches nothing and is charged zero. Adding a real `purok`
 * column removes the guesswork entirely.
 */
function matchPurok(address, fees) {
  if (!address) return null;
  return (
    fees.find((f) => {
      const name = String(f.purokName || '').trim();
      if (!name) return false;
      return new RegExp(`\\b${escapeRe(name)}\\b`, 'i').test(address);
    }) || null
  );
}

// Resolves the purok clearance fee for a free-text address.
async function resolvePurokFee(address, client = prisma) {
  const fees = await client.purokClearanceFee.findMany();
  const matched = matchPurok(address, fees);
  if (!matched) {
    if (address) console.warn(`[purok] no configured purok matches address: ${address}`);
    return { purokName: null, feecentavos: 0 };
  }
  return { purokName: matched.purokName, feecentavos: matched.feecentavos };
}

// The 21 configured puroks, for populating the registration dropdown.
async function listPuroks(client = prisma) {
  const fees = await client.purokClearanceFee.findMany({ orderBy: { purokName: 'asc' } });
  // "Purok 2" must not sort after "Purok 10" in a picker.
  const num = (s) => {
    const m = String(s).match(/(\d+)/);
    return m ? parseInt(m[1], 10) : Number.MAX_SAFE_INTEGER;
  };
  return fees
    .sort((a, b) => num(a.purokName) - num(b.purokName) || a.purokName.localeCompare(b.purokName))
    .map((f) => ({ purokName: f.purokName, feecentavos: f.feecentavos }));
}

// True when `name` is one of the configured puroks. Used to validate the value
// a client submits, so an unknown purok is rejected instead of silently
// resolving to a zero fee later.
async function isKnownPurok(name, client = prisma) {
  if (!name) return false;
  const fees = await client.purokClearanceFee.findMany({ select: { purokName: true } });
  return fees.some((f) => f.purokName.trim().toLowerCase() === String(name).trim().toLowerCase());
}

// Resolve the fee for a resident. Prefers the stored `purok` field; falls back
// to parsing the address only for profiles created before that field existed.
async function purokFeeCentavosForUser(userId, client = prisma) {
  if (!userId) return 0;
  const profile = await client.verificationProfile.findUnique({
    where: { userId },
    select: { purok: true, address: true },
  });
  if (!profile) return 0;

  if (profile.purok) {
    const fee = await client.purokClearanceFee.findUnique({
      where: { purokName: profile.purok },
    });
    if (fee) return fee.feecentavos;
    console.warn(`[purok] profile names an unconfigured purok: ${profile.purok}`);
  }

  const { feecentavos } = await resolvePurokFee(profile.address, client);
  return feecentavos;
}

module.exports = {
  matchPurok,
  resolvePurokFee,
  purokFeeCentavosForUser,
  listPuroks,
  isKnownPurok,
};
