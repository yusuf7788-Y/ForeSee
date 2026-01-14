import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/auth_models.dart';

class OtpService {
  OtpService() {
    _baseUrl = dotenv.env['OTP_API_BASE_URL'] ?? '';
    _apiKey = dotenv.env['OTP_API_KEY'] ?? '';
    // Backend yoksa her zaman Mock modunu kullan (SMTP paketi sorunlu olduğu için)
    _mockMode = _baseUrl.isEmpty;
  }

  late final String _baseUrl;
  late final String _apiKey;
  late final bool _mockMode;
  final Map<String, String> _mockCodes = {};

  bool get isMock => _mockMode;
  bool get usingLocalSmtp => false; // SMTP devre dışı

  Future<OtpRequestResult> requestOtp({
    required String email,
    required AuthFlow flow,
    String? name,
  }) async {
    // 1. Durum: Mock Mod (SMTP paketi olmadığı için varsayılan)
    if (_mockMode) {
      final code = _generateCode();
      _mockCodes[email] = code;
      debugPrint('==========================================');
      debugPrint('[MOCK OTP] Kimden: ForeSee');
      debugPrint('[MOCK OTP] Kime: $email');
      debugPrint('[MOCK OTP] Mesaj: Doğrulama kodunuz: $code');
      debugPrint('==========================================');
      return OtpRequestResult(
        sessionId: email,
        isMock: true,
        validFor: const Duration(minutes: 5),
      );
    }

    // 2. Durum: Backend API Modu
    final uri = Uri.parse('$_baseUrl/request');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
      },
      body: jsonEncode({'email': email, 'name': name, 'flow': flow.name}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return OtpRequestResult(
        sessionId: data['sessionId'] as String,
        isMock: false,
        validFor: Duration(seconds: data['expiresIn'] ?? 300),
      );
    }

    throw Exception('OTP isteği başarısız (${response.statusCode})');
  }

  Future<OtpVerifyResult> verifyOtp({
    required String email,
    required String code,
    required AuthFlow flow,
    required String sessionId,
  }) async {
    // Mock modunda yerel doğrulama
    if (_mockMode) {
      final stored = _mockCodes[email];
      if (stored == null) {
        throw Exception('Süresi dolmuş veya geçersiz işlem');
      }
      if (stored != code) {
        throw Exception('Kod doğru değil');
      }
      _mockCodes.remove(email);
      return const OtpVerifyResult(customToken: null);
    }

    final uri = Uri.parse('$_baseUrl/verify');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
      },
      body: jsonEncode({
        'email': email,
        'code': code,
        'flow': flow.name,
        'sessionId': sessionId,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return OtpVerifyResult(
        customToken: data['customToken'] as String?,
        profileName: data['profileName'] as String?,
      );
    }

    throw Exception('OTP doğrulaması başarısız (${response.statusCode})');
  }

  String _generateCode() {
    final rnd = Random();
    return (rnd.nextInt(90000) + 10000).toString();
  }
}
