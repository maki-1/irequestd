/**
 * Purpose of a document request.
 *
 * Every form (kiosk, phone app, website) offers a fixed list of purposes plus
 * "Other". "Other" on its own is not an answer: the resident has to say what
 * the purpose actually is, and that text — not the word "Other" — is what gets
 * stored and printed on the certificate ("for <purpose> purposes"), so it is
 * held to 1-2 words.
 *
 * Anything that is not one of the canned options is therefore treated as that
 * free-text answer and validated as one.
 */

const CANNED_PURPOSES = [
  'Employment',
  'Travel',
  'Bank',
  'Bank Requirements',
  'Scholarship',
  'Government Assistance',
  'Legal',
];

const MAX_WORDS = 2;
const MAX_CHARS = 40;
// "Other"/"Others" by itself means the resident never filled the field in.
const PLACEHOLDER = /^others?$/i;
const WORD = /^[A-Za-z0-9]+(?:[-'./&][A-Za-z0-9]+)*$/;

/**
 * Validate and tidy a submitted purpose.
 *
 * @param {unknown} raw
 * @returns {{ ok: true, value: string } | { ok: false, message: string }}
 */
function normalizePurpose(raw) {
  const value = String(raw ?? '').trim().replace(/\s+/g, ' ');
  if (!value) return { ok: false, message: 'Purpose is required' };

  const canned = CANNED_PURPOSES.find((p) => p.toLowerCase() === value.toLowerCase());
  if (canned) return { ok: true, value: canned };

  if (PLACEHOLDER.test(value)) {
    return { ok: false, message: 'Specify the other purpose in 1 to 2 words' };
  }
  if (value.length > MAX_CHARS) {
    return { ok: false, message: `Other purpose must be at most ${MAX_CHARS} characters` };
  }
  const words = value.split(' ');
  if (words.length > MAX_WORDS) {
    return { ok: false, message: 'Other purpose must be 1 to 2 words only' };
  }
  if (!words.every((w) => WORD.test(w))) {
    return { ok: false, message: 'Other purpose may only contain letters and numbers' };
  }
  return { ok: true, value };
}

module.exports = { normalizePurpose, CANNED_PURPOSES, MAX_WORDS, MAX_CHARS };
