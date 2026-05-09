import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img_lib;
import 'groq_secrets.dart';

class LlamaIdResult {
  final String idType;
  final String fullName;
  final bool hasFace;
  final String side; // 'front', 'back', or 'unknown'
  final bool success;

  const LlamaIdResult({
    required this.idType,
    required this.fullName,
    required this.hasFace,
    required this.side,
    required this.success,
  });

  static const LlamaIdResult failed = LlamaIdResult(
    idType: '',
    fullName: '',
    hasFace: false,
    side: 'unknown',
    success: false,
  );
}

class LlamaService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'meta-llama/llama-4-scout-17b-16e-instruct';

  static const _idTypes = [
    'Philippine National ID',
    'Philippine Passport',
    "Driver's License",
    'Postal ID',
    "Voter's ID",
    'Senior PWD ID',
    'TIN ID',
    'PhilHealth ID',
    'Pagibig Loyalty Card',
    'NBI Clearance',
    'Police Clearance',
    'Company ID',
    'School ID',
    'PSA Birth Certificate',
    'Marriage Certificate',
    'Unknown',
  ];

  /// Compares a face from an ID against a live selfie.
  /// Sends both images as separate blocks — higher quality than a stitched composite.
  /// Returns true = same person, false = different person, null = API error.
  static Future<bool?> compareFaces(Uint8List idFace, Uint8List selfie) async {
    try {
      final base64Id     = base64Encode(idFace);
      final base64Selfie = base64Encode(selfie);

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $kGroqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Id'},
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Selfie'},
                },
                {
                  'type': 'text',
                  'text':
                      'You are a face verification assistant. '
                      'The FIRST image is a face photo cropped from a Philippine government ID card. '
                      'The SECOND image is a live selfie captured for identity verification. '
                      'Compare the facial features carefully: face shape, eyes, nose, mouth, '
                      'eyebrows, skin tone, and overall facial structure. '
                      'Allow for natural differences in lighting, angle, age, and image quality. '
                      'Do NOT be fooled by accessories (glasses, hats) or minor expression changes. '
                      'Respond in JSON only — no explanation: '
                      '{"same_person": true} if they are the same person, '
                      '{"same_person": false} if they are clearly different people. '
                      'If the face in either image is unclear or too small to determine, respond {"same_person": false}.',
                },
              ],
            },
          ],
          'temperature': 0,
          'max_tokens': 50,
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[LLaMA face] API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (body['choices'] as List).first['message']['content'] as String;
      final json = jsonDecode(content) as Map<String, dynamic>;
      return json['same_person'] as bool?;
    } catch (e) {
      debugPrint('[LLaMA face] exception: $e');
      return null;
    }
  }

  /// Validates a proof document uploaded during Step 1 profiling.
  /// [expectedDocType] — 'PWD ID', 'PSA Birth Certificate', or 'Senior Citizen ID'.
  /// Returns (valid: bool, reason: String). On API error, returns valid=true (fail open).
  /// Returns valid=true (confirmed valid), valid=false (confirmed invalid),
  /// or valid=null (API error — treat as unverified, not an error to surface).
  static Future<({bool? valid, String reason})> validateProofDocument({
    required Uint8List imageBytes,
    required String expectedDocType,
  }) async {
    try {
      // Re-encode to JPEG to guarantee a valid format before sending to the API
      Uint8List sendBytes = imageBytes;
      try {
        final decoded = img_lib.decodeImage(imageBytes);
        if (decoded != null) {
          sendBytes = Uint8List.fromList(img_lib.encodeJpg(decoded, quality: 85));
        }
      } catch (_) {}
      final base64Image = base64Encode(sendBytes);

      final String prompt;

      if (expectedDocType == 'PSA Birth Certificate') {
        prompt = '''You are a strict document verifier. The user claims this image is a PSA (Philippine Statistics Authority) Birth Certificate.

STEP 1 — Check the paper background FIRST (most important):
A genuine PSA Birth Certificate is printed on SECURITY PAPER. The background is NOT plain white. It has a distinctive COLORED microprint pattern — fine, dense, interlocking lines covering the entire background, similar to banknote security paper. The color is typically teal, blue-green, pink, or light blue. If the document background is plain white or off-white with no security pattern, it is IMMEDIATELY invalid — stop and return valid: false.

STEP 2 — Check these required elements (all must be present):
[ ] "Philippine Statistics Authority" or "PSA" in the header (older copies may say "National Statistics Office" or "NSO")
[ ] "Certificate of Live Birth" as the document title
[ ] A barcode OR QR code (usually at the bottom or side)
[ ] Printed form fields with typed/printed personal data (not handwritten)

STEP 3 — These ALWAYS mean invalid:
- Plain white paper background → INVALID
- "Local Civil Registrar" header with NO PSA authentication mark → INVALID
- Hospital birth certificate → INVALID
- Handwritten document → INVALID
- Any document that is NOT a birth certificate → INVALID
- Image is blurry/dark and security paper pattern is not visible → INVALID
- Any other ID, certificate, or document type → INVALID

RULE: If you are not fully certain this is a PSA security-paper Birth Certificate, return valid: false. Do NOT give the benefit of the doubt.

Respond in JSON only:
{
  "valid": <true ONLY if the document clearly shows PSA security paper background AND Certificate of Live Birth title AND barcode/QR, false in all other cases>,
  "reason": "<required if invalid: one sentence stating the specific missing or wrong feature. Empty string only if valid>"
}''';
      } else if (expectedDocType == 'PWD ID') {
        prompt = '''Analyze this document image. The user claims this is a Philippine PWD (Person with Disability) ID.

A valid Philippine PWD ID typically contains:
- "Person With Disability" or "PWD" text prominently displayed
- Name of the ID holder
- Type or category of disability
- Issued by an LGU (Local Government Unit), municipal/city office, or DSWD
- Photo of the person
- ID/control number
- Signature and official seal

Respond in JSON only — no explanation:
{
  "valid": <true if this is clearly a Philippine PWD ID, false if it is a different document or not recognizable as a PWD ID>,
  "reason": "<one short sentence if invalid, or empty string if valid>"
}''';
      } else {
        // Senior Citizen ID
        prompt = '''Analyze this document image. The user claims this is a Philippine Senior Citizen ID.

A valid Philippine Senior Citizen ID typically contains:
- "Senior Citizen" text
- OSCA (Office for Senior Citizens Affairs) text or logo
- Name of the cardholder
- Photo of the person
- Issued by the LGU/municipality/city
- ID number or OSCA number
- Official seal or signature

Respond in JSON only — no explanation:
{
  "valid": <true if this is clearly a Philippine Senior Citizen ID, false if it is a different document or not recognizable>,
  "reason": "<one short sentence if invalid, or empty string if valid>"
}''';
      }

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $kGroqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                },
                {'type': 'text', 'text': prompt},
              ],
            },
          ],
          'temperature': 0,
          'max_completion_tokens': 150,
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        debugPrint('[LLaMA proof] API error ${response.statusCode}: ${response.body}');
        return (valid: null, reason: ''); // unverified — don't surface to user
      }

      final body    = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (body['choices'] as List).first['message']['content'] as String;
      final json    = jsonDecode(content) as Map<String, dynamic>;

      final valid  = json['valid'] as bool?;
      final reason = (json['reason'] as String? ?? '').trim();
      debugPrint('[LLaMA proof] valid=$valid reason=$reason');
      return (valid: valid, reason: reason);
    } catch (e) {
      debugPrint('[LLaMA proof] exception: $e');
      return (valid: null, reason: ''); // unverified — don't surface to user
    }
  }

  /// Analyzes a Philippine ID image using LLaMA 3.2 Vision.
  /// Returns detected ID type, full name on the ID, and whether a face is present.
  /// [referenceImageUrl] — optional URL of a reference/sample image sent as extra
  /// context so the model can compare the scanned ID against a known example.
  static Future<LlamaIdResult> analyzeId(
    Uint8List imageBytes, {
    String? referenceImageUrl,
  }) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final hasReference = referenceImageUrl != null && referenceImageUrl.isNotEmpty;

      final prompt = hasReference
          ? '''You are given TWO images:
1. REFERENCE IMAGE (first image): an official sample of the back of a Philippine Driver\'s License issued by the Land Transportation Office (LTO). Use it as a visual reference for what a legitimate Driver\'s License back looks like.
2. SCAN IMAGE (second image): the actual ID scan submitted by the user.

Analyze the SCAN IMAGE only. Respond in JSON only, no explanation.

Return exactly this structure:
{
  "idType": "<one of: ${_idTypes.join(', ')}>",
  "fullName": "<full name exactly as printed on the ID, in uppercase>",
  "hasFace": <true or false>,
  "side": "<front or back or unknown>"
}

Rules:
- idType must exactly match one of the listed types, or "Unknown"
- fullName should be the complete name on the card (e.g. "DELA CRUZ, MARIA SANTOS")
- hasFace is true if there is a portrait/photo of a person on the ID
- side is "front" if this is the front of the ID (contains the holder\'s photo, full name, and ID number); "back" if this is the back side (contains barcode, QR code, signature line, thumbmark area, address fields, or machine-readable zone with no portrait); "unknown" if it cannot be determined
- Use the reference image to help determine if the scan matches the expected layout of a Driver\'s License back'''
          : '''Analyze this Philippine ID image. Respond in JSON only, no explanation.

Return exactly this structure:
{
  "idType": "<one of: ${_idTypes.join(', ')}>",
  "fullName": "<full name exactly as printed on the ID, in uppercase>",
  "hasFace": <true or false>,
  "side": "<front or back or unknown>"
}

Rules:
- idType must exactly match one of the listed types, or "Unknown"
- fullName should be the complete name on the card (e.g. "DELA CRUZ, MARIA SANTOS")
- hasFace is true if there is a portrait/photo of a person on the ID
- side is "front" if this is the front of the ID (contains the holder\'s photo, full name, and ID number); "back" if this is the back side (contains barcode, QR code, signature line, thumbmark area, address fields, or machine-readable zone with no portrait); "unknown" if it cannot be determined''';

      final contentBlocks = <Map<String, dynamic>>[
        if (hasReference)
          {
            'type': 'image_url',
            'image_url': {'url': referenceImageUrl},
          },
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
        },
        {
          'type': 'text',
          'text': prompt,
        },
      ];

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $kGroqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': contentBlocks,
            },
          ],
          'temperature': 0,
          'max_tokens': 150,
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) return LlamaIdResult.failed;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (body['choices'] as List).first['message']['content'] as String;
      final json = jsonDecode(content) as Map<String, dynamic>;

      return LlamaIdResult(
        idType: (json['idType'] as String? ?? '').trim(),
        fullName: (json['fullName'] as String? ?? '').trim(),
        hasFace: json['hasFace'] as bool? ?? false,
        side: (json['side'] as String? ?? 'unknown').trim().toLowerCase(),
        success: true,
      );
    } catch (_) {
      return LlamaIdResult.failed;
    }
  }
}
