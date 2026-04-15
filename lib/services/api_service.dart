import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

/// Typed network error surfaced to UI.
class ApiException implements Exception {
  final int? status;
  final String message;
  final dynamic data;
  ApiException(this.message, {this.status, this.data});
  @override
  String toString() => 'ApiException($status): $message';
}

/// Strip "SomeException(123): " prefix from error strings for UI display.
String cleanError(Object e) {
  if (e is ApiException) return e.message;
  return e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception\([^)]*\):\s*'), '');
}

/// Backend response envelope helper.
///
/// Backend wraps every response as `{ success, data, timestamp }`.
/// This extracts `.data` (or throws on failure envelopes).
T unwrap<T>(dynamic response) {
  if (response is Map<String, dynamic>) {
    if (response['success'] == false) {
      throw ApiException(
        response['message']?.toString() ?? 'Request failed',
        data: response,
      );
    }
    final data = response['data'];
    if (data is T) return data;
    // Allow unwrap<Map<String,dynamic>>() on a Map payload
    return data as T;
  }
  return response as T;
}

/// Singleton Dio-backed API service for the WorkStream backend.
class ApiService {
  bool _isRefreshing = false;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: kApiTimeout,
        receiveTimeout: kApiTimeout,
        sendTimeout: kApiTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          final url = e.requestOptions.path;
          // Skip refresh logic for auth endpoints to prevent infinite loops
          if (e.response?.statusCode == 401 &&
              !url.contains('/auth/') &&
              !_isRefreshing) {
            final refreshToken = await _readRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              _isRefreshing = true;
              try {
                final resp = await _dio.post<Map<String, dynamic>>(
                  '/auth/refresh',
                  data: {'refreshToken': refreshToken},
                );
                final body = resp.data;
                final newToken = (body?['data'] is Map
                        ? (body!['data'] as Map)['accessToken']
                        : null)
                    ?.toString();
                if (newToken != null && newToken.isNotEmpty) {
                  await setToken(newToken);
                  e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                  final retried = await _dio.fetch<dynamic>(e.requestOptions);
                  return handler.resolve(retried);
                }
              } catch (_) {
                // refresh failed — clear tokens and force re-login
                await setToken(null);
                await setRefreshToken(null);
                onAuthExpired?.call();
                return handler.next(e);
              } finally {
                _isRefreshing = false;
              }
            } else {
              // no refresh token — force re-login
              onAuthExpired?.call();
            }
          }
          handler.next(e);
        },
      ),
    );
  }

  static final ApiService instance = ApiService._internal();
  late final Dio _dio;

  /// Called when auth is fully expired (refresh failed or no refresh token).
  void Function()? onAuthExpired;

  Dio get dio => _dio;

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefsKeys.auth);
  }

  Future<String?> _readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefsKeys.refresh);
  }

  Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(PrefsKeys.auth);
    } else {
      await prefs.setString(PrefsKeys.auth, token);
    }
  }

  Future<void> setRefreshToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(PrefsKeys.refresh);
    } else {
      await prefs.setString(PrefsKeys.refresh, token);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final r = await _dio.get(path, queryParameters: query);
      return _asMap(r.data);
    } on DioException catch (e) {
      throw _toApi(e);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final r = await _dio.post(path, data: body);
      return _asMap(r.data);
    } on DioException catch (e) {
      throw _toApi(e);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final r = await _dio.patch(path, data: body);
      return _asMap(r.data);
    } on DioException catch (e) {
      throw _toApi(e);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final r = await _dio.delete(path);
      return _asMap(r.data);
    } on DioException catch (e) {
      throw _toApi(e);
    }
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'success': true, 'data': raw};
  }

  ApiException _toApi(DioException e) {
    final resp = e.response?.data;
    final status = e.response?.statusCode;
    String msg;

    if (resp is Map) {
      // Wrapped envelope: { success:false, error:{ code, message, details }, ... }
      final errField = resp['error'];
      // Standard NestJS: { statusCode, message, error }
      msg = resp['message']?.toString() ??
          (errField is Map ? errField['message']?.toString() : null) ??
          'Request failed';
    } else if (resp is String && resp.trim().isNotEmpty) {
      msg = resp.trim();
    } else if (status != null) {
      msg = _statusMessage(status);
    } else {
      msg = 'Network error — check your connection';
    }

    return ApiException(msg, status: status, data: resp);
  }

  static String _statusMessage(int status) {
    return switch (status) {
      400 => 'Bad request',
      401 => 'Unauthorized',
      403 => 'Access denied',
      404 => 'Not found',
      409 => 'Conflict — duplicate entry',
      422 => 'Validation failed',
      429 => 'Too many requests',
      500 => 'Server error — please try again',
      503 => 'Service unavailable',
      _ => 'Request failed ($status)',
    };
  }
}
