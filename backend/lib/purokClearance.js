const crypto = require('crypto');
const prisma = require('./prisma');

/**
 * Purok clearance control numbers, and the rules for redeeming one.
 *
 * A clearance is issued ahead of time by a Purok Leader and redeemed once at
 * the kiosk. Online requests do not use this — they keep the in-app per-request
 * approval — so nothing here should be wired into the app or website flows.
 */

// Deliberately excludes 0/O, 1/I/L and U: the number is read off a printed slip
// and typed on a touchscreen, often by an elderly resident.
const ALPHABET = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
const CODE_LEN = 6;

// Default shelf life of an unused clearance. Long enough to be convenient,
// short enough that a lost slip stops being useful.
const DEFAULT_VALID_DAYS = 30;

function randomCode() {
  const bytes = crypto.randomBytes(CODE_LEN);
  let out = '';
  for (let i = 0; i < CODE_LEN; i++) out += ALPHABET[bytes[i] % ALPHABET.length];
  // Grouped for legibility on the printed form: PC-A7K2-M9
  return `PC-${out.slice(0, 4)}-${out.slice(4)}`;
}

// Accepts what a resident actually types: spaces, lowercase, a missing prefix.
function normaliseCode(input) {
  const raw = String(input || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  const body = raw.startsWith('PC') ? raw.slice(2) : raw;
  if (body.length !== CODE_LEN) return null;
  if ([...body].some((c) => !ALPHABET.includes(c))) return null;
  return `PC-${body.slice(0, 4)}-${body.slice(4)}`;
}

// Generates a control number that is not already taken.
async function nextControlNo(client = prisma) {
  for (let attempt = 0; attempt < 10; attempt++) {
    const controlNo = randomCode();
    const clash = await client.purokClearance.findUnique({ where: { controlNo } });
    if (!clash) return controlNo;
  }
  throw new Error('Could not allocate an unused control number');
}

/**
 * Looks up a clearance for redemption.
 *
 * The control number alone is not enough. It is short by necessity, so it is
 * paired with a detail only the holder should know — their birth date, or their
 * surname. Both come off the same slip the leader handed them, so a legitimate
 * resident always has both, while a guessed code on its own gets nowhere.
 *
 * Returns { ok: false, reason } rather than throwing, so the kiosk can show a
 * plain message.
 */
async function verifyClearance({ controlNo, birthday, surname }, client = prisma) {
  const code = normaliseCode(controlNo);
  if (!code) return { ok: false, reason: 'malformed', message: 'That control number does not look right.' };

  const clearance = await client.purokClearance.findUnique({ where: { controlNo: code } });
  if (!clearance) return { ok: false, reason: 'not_found', message: 'No clearance found with that control number.' };

  if (clearance.status === 'used') {
    return {
      ok: false,
      reason: 'used',
      message: 'This clearance has already been used. Please obtain a new one from your Purok Leader.',
    };
  }
  if (clearance.status === 'void') {
    return { ok: false, reason: 'void', message: 'This clearance was cancelled.' };
  }
  if (clearance.validUntil && clearance.validUntil < new Date()) {
    return {
      ok: false,
      reason: 'expired',
      message: 'This clearance has expired. Please obtain a new one from your Purok Leader.',
    };
  }

  // Second factor. Either detail is accepted — whichever the kiosk asked for.
  const matchesBirthday =
    birthday && clearance.birthday &&
    new Date(birthday).toISOString().slice(0, 10) ===
      clearance.birthday.toISOString().slice(0, 10);

  const lastName = String(clearance.fullName || '').trim().split(/\s+/).pop() || '';
  const matchesSurname =
    surname && lastName && String(surname).trim().toLowerCase() === lastName.toLowerCase();

  if (!matchesBirthday && !matchesSurname) {
    return {
      ok: false,
      reason: 'mismatch',
      message: 'The details do not match this clearance.',
    };
  }

  return { ok: true, clearance };
}

/**
 * Spends a clearance on one submission.
 *
 * One clearance covers one process: several documents may be requested
 * together, and the clearance is consumed by that submission. The update is
 * conditional on the row still being 'issued', so two kiosks redeeming the same
 * code at once cannot both succeed.
 */
async function redeemClearance(clearanceId, requestIds, client = prisma) {
  const { count } = await client.purokClearance.updateMany({
    where: { id: clearanceId, status: 'issued' },
    data: { status: 'used', usedAt: new Date() },
  });
  if (count === 0) return { ok: false, reason: 'already_used' };

  const clearance = await client.purokClearance.findUnique({ where: { id: clearanceId } });

  // The requests it authorised inherit the attestation: approved, by the leader
  // who issued it, at the time they issued it. The fee is zero because the
  // resident already paid it in cash at the purok.
  await client.request.updateMany({
    where: { id: { in: requestIds } },
    data: {
      purokClearanceId: clearanceId,
      purokLeaderStatus: 'approved',
      purokLeaderBy: clearance.issuedById,
      purokLeaderAt: clearance.issuedAt,
      purokLeaderRemarks: `Purok clearance ${clearance.controlNo} presented at kiosk`,
      purokClearanceFee: 0,
    },
  });

  return { ok: true, clearance };
}

module.exports = {
  ALPHABET,
  DEFAULT_VALID_DAYS,
  randomCode,
  normaliseCode,
  nextControlNo,
  verifyClearance,
  redeemClearance,
};
