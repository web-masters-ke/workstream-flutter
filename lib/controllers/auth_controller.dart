import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  final _auth = AuthService();
  final _profile = ProfileService();

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  User? _user;
  User? get user => _user;

  String? _error;
  String? get error => _error;

  bool _busy = false;
  bool get busy => _busy;

  Future<void> bootstrap() async {
    final cached = await _auth.cachedUser();
    if (cached != null) {
      _user = cached;
      _status = AuthStatus.authenticated;
      // Try to refresh — ignore failures (offline).
      try {
        final fresh = await _auth.me();
        _user = fresh;
      } catch (_) {}
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _auth.login(
        emailOrPhone: identifier,
        password: password,
      );
      _user = r.user;
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      _error = _clean(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final r = await _auth.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone,
        password: password,
      );
      _user = r.user;
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      _error = _clean(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> requestPasswordReset(String identifier) async {
    try {
      await _auth.requestPasswordReset(identifier);
      return true;
    } catch (e) {
      _error = _clean(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _auth.resetPassword(
        identifier: identifier,
        otp: otp,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _error = _clean(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp({required String identifier, required String otp}) async {
    try {
      await _auth.verifyOtp(identifier: identifier, otp: otp);
      return true;
    } catch (e) {
      _error = _clean(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleAvailability() async {
    if (_user == null) return false;
    final next = !_user!.available;
    _user = _user!.copyWith(available: next);
    notifyListeners();
    try {
      await _profile.setAvailability(next);
    } catch (_) {
      // keep optimistic update; best-effort sync.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.availability, next);
    return next;
  }

  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? address,
    String? avatarUrl,
  }) async {
    try {
      final u = await _profile.update(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        address: address,
        avatarUrl: avatarUrl,
      );
      _user = u;
      notifyListeners();
      return true;
    } catch (_) {
      // fallback: local update
      _user = _user?.copyWith(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        address: address,
        avatarUrl: avatarUrl,
      );
      notifyListeners();
      return true;
    }
  }

  Future<bool> updateSkills(List<String> skills) async {
    try {
      final u = await _profile.updateSkills(skills);
      _user = u;
    } catch (_) {
      _user = _user?.copyWith(skills: skills);
    }
    notifyListeners();
    return true;
  }

  Future<bool> submitKyc({
    required String idType,
    required String idNumber,
    String? frontImageUrl,
    String? backImageUrl,
    String? selfieUrl,
    String? address,
  }) async {
    try {
      await _profile.submitKyc(
        idType: idType,
        idNumber: idNumber,
        frontImageUrl: frontImageUrl,
        backImageUrl: backImageUrl,
        selfieUrl: selfieUrl,
        address: address,
      );
      _user = _user?.copyWith(kycVerified: true, idNumber: idNumber, address: address);
      notifyListeners();
      return true;
    } catch (e) {
      _error = _clean(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String current,
    required String next,
  }) async {
    try {
      await _profile.changePassword(current: current, next: next);
      return true;
    } catch (e) {
      _error = _clean(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _clean(Object e) {
    final s = e.toString();
    return s.startsWith('ApiException') ? s.replaceFirst(RegExp(r'^[^:]+:\s*'), '') : s;
  }
}
