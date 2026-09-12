/// Rule for the "Purpose of document" field, shared by the resident app and
/// the kiosk.
///
/// The forms offer a fixed list plus "Other". "Other" on its own is not an
/// answer: the resident has to type what the purpose actually is, and that
/// text — not the word "Other" — is what is submitted, stored and printed on
/// the certificate ("for `purpose` purposes"). Keeping it to 1-2 words keeps
/// the printed line readable.
library;

class PurposeRule {
  PurposeRule._();

  /// The dropdown entry that asks for a typed answer.
  static const String other = 'Other';

  static const int maxWords = 2;
  static const int maxChars = 40;

  static final RegExp _spaces = RegExp(r'\s+');
  static final RegExp _placeholder = RegExp(r'^others?$', caseSensitive: false);
  static final RegExp _word = RegExp(r"^[A-Za-z0-9]+(?:[-'./&][A-Za-z0-9]+)*$");

  /// Trim and collapse the whitespace a touch keyboard tends to leave behind.
  static String clean(String raw) => raw.trim().replaceAll(_spaces, ' ');

  /// `null` when [raw] is an acceptable answer for "Other"; otherwise the
  /// reason to show under the field.
  static String? validateOther(String raw) {
    final value = clean(raw);
    if (value.isEmpty) return 'Please specify the purpose (1-2 words)';
    if (_placeholder.hasMatch(value)) return 'Type the actual purpose, not "Other"';
    if (value.length > maxChars) return 'Keep it within $maxChars characters';
    final words = value.split(' ');
    if (words.length > maxWords) return 'Use $maxWords words at most';
    if (!words.every(_word.hasMatch)) return 'Letters and numbers only';
    return null;
  }

  /// What to submit as the purpose: the typed answer when the resident picked
  /// "Other", the chosen option otherwise.
  static String resolve(String? selected, String typedOther) =>
      selected == other ? clean(typedOther) : (selected ?? '');
}
