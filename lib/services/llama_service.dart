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
  static const _model = 'llama-3.2-11b-vision-preview';

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
  /// Composites both into one side-by-side image (the model only accepts 1 image per call).
  /// Returns true = same person, false = different person, null = API error.
  static Future<bool?> compareFaces(Uint8List idFace, Uint8List selfie) async {
    try {
      final composite = _sideBySide(idFace, selfie);
      final base64Img = base64Encode(composite);

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
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Img'},
                },
                {
                  'type': 'text',
                  'text':
                      'This image shows two photos placed side by side. The LEFT photo is a face portrait from a Philippine government ID card (or the full ID card). The RIGHT photo is a live selfie for identity verification. Are both photos showing the SAME person? Consider differences in lighting, angle, and image quality. Respond in JSON only: {"same_person": true} or {"same_person": false}. If uncertain, respond {"same_person": false}.',
                },
              ],
            },
          ],
          'temperature': 0,
          'max_tokens': 50,
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 25));

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

  // Stitch two images side-by-side at a fixed height so the result is one image.
  static Uint8List _sideBySide(Uint8List left, Uint8List right) {
    try {
      const targetH = 320;
      const gap = 8;
      final l = img_lib.decodeImage(left);
      final r = img_lib.decodeImage(right);
      if (l == null || r == null) return left;

      final rl = img_lib.copyResize(l, height: targetH);
      final rr = img_lib.copyResize(r, height: targetH);

      final canvas = img_lib.Image(
        width: rl.width + gap + rr.width,
        height: targetH,
        numChannels: 3,
      );
      img_lib.compositeImage(canvas, rl, dstX: 0, dstY: 0);
      img_lib.compositeImage(canvas, rr, dstX: rl.width + gap, dstY: 0);

      return Uint8List.fromList(img_lib.encodeJpg(canvas, quality: 85));
    } catch (_) {
      return left;
    }
  }

  /// Analyzes a Philippine ID image using LLaMA 3.2 Vision.
  /// Returns detected ID type, full name on the ID, and whether a face is present.
  static Future<LlamaIdResult> analyzeId(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final prompt = '''Analyze this Philippine ID image. Respond in JSON only, no explanation.

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
- side is "front" if this is the front of the ID (contains the holder's photo, full name, and ID number); "back" if this is the back side (contains barcode, QR code, signature line, thumbmark area, address fields, or machine-readable zone with no portrait); "unknown" if it cannot be determined''';

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
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
                {
                  'type': 'text',
                  'text': prompt,
                },
              ],
            },
          ],
          'temperature': 0,
          'max_tokens': 150,
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 20));

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
