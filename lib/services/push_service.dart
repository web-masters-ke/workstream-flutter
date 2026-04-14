import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import 'api_service.dart';

/// Firebase Cloud Messaging stub.
///
/// The full `firebase_messaging` plugin requires `google-services.json` /
/// `GoogleService-Info.plist`. Until those are wired, this stub:
/// - assigns a stable device identifier (persisted locally),
/// - registers it with the backend (`POST /notifications/devices/register`),
/// - and no-ops if the backend is unreachable.
class PushService {
  static final PushService instance = PushService._();
  PushService._();

  final _api = ApiService.instance;

  Future<void> init() async {
    final token = await _ensureToken();
    try {
      await _api.post('/notifications/devices/register', body: {
        'token': token,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[push] register failed: $e');
    }
  }

  Future<String> _ensureToken() async {
    final prefs = await SharedPreferences.getInstance();
    var t = prefs.getString(PrefsKeys.fcmToken);
    if (t == null || t.isEmpty) {
      t = 'stub-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(PrefsKeys.fcmToken, t);
    }
    return t;
  }
}
