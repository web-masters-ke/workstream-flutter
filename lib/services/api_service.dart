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
        onError: (e, handler) {
          handler.next(e);
        },
      ),
    );
  }

  static final ApiService instance = ApiService._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(PrefsKeys.auth);
  }

  Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(PrefsKeys.auth);
    } else {
      await prefs.setString(PrefsKeys.auth, token);
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
    String msg = e.message ?? 'Network error';
    if (resp is Map && resp['message'] != null) {
      msg = resp['message'].toString();
    }
    return ApiException(msg, status: e.response?.statusCode, data: resp);
  }
}
