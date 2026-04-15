import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthResult {
  final User user;
  final String token;
  AuthResult(this.user, this.token);
}

class AuthService {
  final _api = ApiService.instance;

  Future<AuthResult> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final resp = await _api.post(
      '/auth/login',
      body: {'email': emailOrPhone, 'password': password},
    );
    return _consumeAuth(resp);
  }

  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final resp = await _api.post(
      '/auth/register',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'password': password,
        'role': 'AGENT',
      },
    );
    return _consumeAuth(resp);
  }

  Future<void> requestPasswordReset(String identifier) async {
    await _api.post('/auth/forgot-password', body: {'identifier': identifier});
  }

  Future<void> verifyOtp({required String identifier, required String otp}) async {
    await _api.post('/auth/verify-otp',
        body: {'identifier': identifier, 'otp': otp});
  }

  Future<void> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post('/auth/reset-password', body: {
      'identifier': identifier,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  Future<User> me() async {
    final resp = await _api.get('/auth/me');
    final data = unwrap<Map<String, dynamic>>(resp);
    final user = User.fromJson(data);
    await _persistUser(user);
    return user;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefsKeys.auth);
    await prefs.remove(PrefsKeys.refresh);
    await prefs.remove(PrefsKeys.user);
  }

  Future<User?> cachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefsKeys.user);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<AuthResult> _consumeAuth(Map<String, dynamic> resp) async {
    final data = unwrap<Map<String, dynamic>>(resp);
    final token =
        data['token']?.toString() ?? data['accessToken']?.toString() ?? '';
    final userMap = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data;
    final user = User.fromJson(userMap);
    await _api.setToken(token);
    await _persistUser(user);
    return AuthResult(user, token);
  }

  Future<void> _persistUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.user, jsonEncode(user.toJson()));
  }
}
