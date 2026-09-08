import 'dart:convert';
import 'package:http/http.dart' as http;

import 'kiosk_config.dart';

/// Thin HTTP client for the two kiosk endpoints. No auth token — the printed
/// purok-clearance control number is the credential. Every call carries the
/// shared `X-Kiosk-Key` device header.
class KioskApi {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (KioskConfig.kioskKey.isNotEmpty) 'X-Kiosk-Key': KioskConfig.kioskKey,
      };

  /// POST /api/kiosk/clearance/verify
  ///
  /// Returns the decoded body with `statusCode` merged in. A usable clearance
  /// comes back as `{ ok: true, clearance: {...} }`; an unusable one as
  /// `{ ok: false, reason, message }` (still HTTP 200).
  static Future<Map<String, dynamic>> verifyClearance({
    required String controlNo,
    String? surname,
    String? birthday,
  }) async {
    final res = await http.post(
      Uri.parse('${KioskConfig.apiBase}/kiosk/clearance/verify'),
      headers: _headers,
      body: jsonEncode({
        'controlNo': controlNo,
        if (surname != null && surname.trim().isNotEmpty) 'surname': surname.trim(),
        if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
      }),
    );
    return _decode(res);
  }

  /// POST /api/kiosk/requests
  ///
  /// `items` is a list of `{documentType, purpose, additionalDetails?}`.
  /// Success is HTTP 201 `{ ok: true, controlNo, requests: [...] }`.
  static Future<Map<String, dynamic>> submitRequests({
    required String controlNo,
    String? surname,
    String? birthday,
    required List<Map<String, String>> items,
  }) async {
    final res = await http.post(
      Uri.parse('${KioskConfig.apiBase}/kiosk/requests'),
      headers: _headers,
      body: jsonEncode({
        'controlNo': controlNo,
        if (surname != null && surname.trim().isNotEmpty) 'surname': surname.trim(),
        if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
        'items': items,
      }),
    );
    return _decode(res);
  }

  static Map<String, dynamic> _decode(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        return {'statusCode': res.statusCode, ...body};
      }
      return {'statusCode': res.statusCode, 'data': body};
    } catch (_) {
      return {
        'statusCode': res.statusCode,
        'message': 'Unexpected response from the server.',
      };
    }
  }
}
