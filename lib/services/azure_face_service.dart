import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AzureFaceService {
  static const _endpoint = String.fromEnvironment('AZURE_FACE_ENDPOINT',
      defaultValue: 'https://irequest.cognitiveservices.azure.com');
  static const _key = String.fromEnvironment('AZURE_FACE_KEY');

  /// Detects the first face and returns its bounding box width in pixels.
  /// Returns null if no face found.
  static Future<int?> detectFaceWidth(Uint8List imageBytes) async {
    final uri = Uri.parse(
        '$_endpoint/face/v1.0/detect?returnFaceId=false&detectionModel=detection_03');
    final res = await http.post(
      uri,
      headers: {
        'Ocp-Apim-Subscription-Key': _key,
        'Content-Type': 'application/octet-stream',
      },
      body: imageBytes,
    );
    if (res.statusCode != 200) {
      throw Exception('Face detection failed (${res.statusCode}): ${res.body}');
    }
    final List<dynamic> faces = jsonDecode(res.body);
    if (faces.isEmpty) return null;
    final rect = faces.first['faceRectangle'] as Map<String, dynamic>;
    return rect['width'] as int;
  }
}
