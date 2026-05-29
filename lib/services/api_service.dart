import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Change this to your machine's IP if running on a physical device.
  // Use 10.0.2.2 for Android emulator, localhost for web/desktop.
  // static const String _baseUrl = 'https://irequestd.onrender.com/api';
  static const String _baseUrl = 'http://192.168.1.43:5000/api'; // Physical device
  // static const String _baseUrl = 'http://localhost:5000/api'; // Flutter Web/

  // ── Token helpers ────────────────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  // ── Auth headers ─────────────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth endpoints ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> register({
    required String username,
    required String contactNumber,
    String email = '',
    required String password,
    required String confirmPassword,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'contactNumber': contactNumber,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      await saveToken(body['token'] as String);
      await saveUser(body['user'] as Map<String, dynamic>);
    }
    return {'statusCode': res.statusCode, ...body};
  }

  /// Fetches the latest user + account status from the server and refreshes local cache.
  /// Returns null on auth error (401/403). Throws on network error — callers should
  /// catch and fall back to [getUser] for offline/connection-loss scenarios.
  static Future<Map<String, dynamic>?> getMe() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await saveUser(data);
      return data;
    }
    return null;
  }

  // ── OTP endpoints ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> verifyOtp({
    required String userId,
    required String code,
    required String type, // 'register' or 'reset'
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'code': code, 'type': type}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && type == 'register' && body['user'] != null) {
      await saveToken(body['token'] as String);
      await saveUser(body['user'] as Map<String, dynamic>);
    }
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<Map<String, dynamic>> resendOtp({
    required String userId,
    required String type,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/resend-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'type': type}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<bool> checkContactAvailable(String contact) async {
    final digits = contact.replaceAll(RegExp(r'\D'), '');
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/check-contact?contact=${Uri.encodeComponent(digits)}'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['available'] as bool;
    }
    return true;
  }

  static Future<bool> checkEmailAvailable(String email) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/check-email?email=${Uri.encodeComponent(email)}'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['available'] as bool;
    }
    return true;
  }

  static Future<bool> checkUsernameAvailable(String username) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/check-username?username=${Uri.encodeComponent(username)}'),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['available'] as bool;
    }
    return true; // fail open
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String identifier,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'resetToken': resetToken,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  // ── Verification endpoints ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getVerificationStatus() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/verification/status'),
      headers: await _authHeaders(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<Map<String, dynamic>> submitStep1(
    Map<String, dynamic> data, {
    Uint8List? proofBytes,
    String? proofFileName,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/verification/step1'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    data.forEach((k, v) => request.fields[k] = v?.toString() ?? '');
    if (proofBytes != null && proofFileName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'freeDocumentProof',
        proofBytes,
        filename: proofFileName,
      ));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<Map<String, dynamic>> submitStep2(
      Map<String, dynamic> data, String? certPath) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/verification/step2'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    data.forEach((k, v) => request.fields[k] = v?.toString() ?? '');
    if (certPath != null && certPath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('educationCertificate', certPath));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<Map<String, dynamic>> submitStep3({
    required String idType,
    required String idName,
    String? facePhotoPath,
    required String idFrontPath,
    required String idBackPath,
    String? idName2,
    String? idFrontPath2,
    String? idBackPath2,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/verification/step3'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.fields['idType'] = idType;
    request.fields['idName'] = idName;
    if (facePhotoPath != null && facePhotoPath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('facePhoto', facePhotoPath));
    }
    request.files.add(await http.MultipartFile.fromPath('idFront', idFrontPath));
    if (idBackPath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('idBack', idBackPath));
    }
    // Second ID (secondary type only)
    if (idName2 != null && idName2.isNotEmpty) {
      request.fields['idName2'] = idName2;
    }
    if (idFrontPath2 != null && idFrontPath2.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('idFront2', idFrontPath2));
    }
    if (idBackPath2 != null && idBackPath2.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('idBack2', idBackPath2));
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  // ── Request endpoints ─────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchRequests() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/requests'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load requests');
  }

  static Future<List<dynamic>> fetchClaimedDocuments() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/requests/claimed'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load claimed documents');
  }

  static Future<List<dynamic>> fetchCompletedDocuments() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/requests/completed'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load completed documents');
  }

  static Future<Map<String, dynamic>> fetchSummary() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/requests/summary'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load summary');
  }

  static Future<Map<String, dynamic>> createRequest({
    required String documentType,
    required String purpose,
    String additionalDetails = '',
    required String deliveryMethod,
    Uint8List? proofFileBytes,
    String? proofFileName,
  }) async {
    final token = await getToken();

    if (proofFileBytes != null && proofFileName != null) {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/requests'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.fields['documentType'] = documentType;
      request.fields['purpose'] = purpose;
      request.fields['additionalDetails'] = additionalDetails;
      request.fields['deliveryMethod'] = deliveryMethod;
      request.files.add(http.MultipartFile.fromBytes(
        'freeDocumentProof',
        proofFileBytes,
        filename: proofFileName,
      ));
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return {'statusCode': res.statusCode, ...body};
    }

    final res = await http.post(
      Uri.parse('$_baseUrl/requests'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'documentType': documentType,
        'purpose': purpose,
        'additionalDetails': additionalDetails,
        'deliveryMethod': deliveryMethod,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<void> deleteRequest(String id) async {
    await http.delete(
      Uri.parse('$_baseUrl/requests/$id'),
      headers: await _authHeaders(),
    );
  }

  // ── Document prices ───────────────────────────────────────────────────────

  /// Fetches all document prices from the DB (set by admin).
  /// Returns a list of { documentType, pricecentavos, description }
  static Future<List<dynamic>> fetchDocumentPrices() async {
    final res = await http.get(Uri.parse('$_baseUrl/admin/prices'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    return [];
  }

  // ── Payment endpoints ─────────────────────────────────────────────────────

  /// Creates a PayMongo checkout session for approved, unpaid requests.
  /// Returns { checkoutUrl, sessionId, requestIds } on success.
  static Future<Map<String, dynamic>> createCheckoutSession({
    required List<String> requestIds,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/payment/create-session'),
      headers: await _authHeaders(),
      body: jsonEncode({'requestIds': requestIds}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  /// Submits one or more document requests (no photos required).
  static Future<Map<String, dynamic>> createBulkRequest({
    required List<Map<String, String>> items,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/requests/bulk'),
      headers: await _authHeaders(),
      body: jsonEncode({'items': items}),
    );
    final body = jsonDecode(res.body);
    // Success returns a JSON array; errors return a JSON object with 'message'
    if (body is List) {
      return {'statusCode': res.statusCode};
    }
    return {'statusCode': res.statusCode, ...(body as Map<String, dynamic>)};
  }

  /// Returns the current purok clearance fee.
  static Future<Map<String, dynamic>> fetchPurokClearanceFee() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/payment/purok-fee'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return {'feeCentavos': 0, 'feePHP': 0.0};
  }

  /// Creates a new PayMongo checkout session for an existing unpaid request.
  /// Returns { checkoutUrl, sessionId, requestId } on success.
  static Future<Map<String, dynamic>> retryPaymentSession(String requestId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/payment/retry-session/$requestId'),
      headers: await _authHeaders(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  /// DEV ONLY — skips PayMongo and marks the request as paid instantly.
  static Future<Map<String, dynamic>> devSkipPayment(String requestId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/payment/dev-skip/$requestId'),
      headers: await _authHeaders(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  /// Polls whether a checkout session has been paid.
  /// Returns { paid: bool, requestId: String }
  static Future<Map<String, dynamic>> checkPaymentStatus(String sessionId) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/payment/status/$sessionId'),
      headers: await _authHeaders(),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  // ── Demographic profile ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> fetchDemographicProfile() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/profile'),
      headers: await _authHeaders(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to load profile');
  }

  // ── Profile endpoints ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> uploadAvatar(
      String filePath, Uint8List bytes, String filename) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl/auth/avatar'),
    );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'avatar',
      bytes,
      filename: filename,
    ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final res = await http.put(
      Uri.parse('$_baseUrl/auth/change-password'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return {'statusCode': res.statusCode, ...body};
  }

  static String avatarUrl(String url) {
    // Avatar is now a full Cloudinary URL stored directly
    return url;
  }
}
