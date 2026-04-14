import '../models/user.dart';
import 'api_service.dart';

class ProfileService {
  final _api = ApiService.instance;

  Future<User> update({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    String? address,
    String? avatarUrl,
  }) async {
    final r = await _api.patch('/agents/me', body: {
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return User.fromJson(unwrap<Map<String, dynamic>>(r));
  }

  Future<User> updateSkills(List<String> skills) async {
    final r = await _api.patch('/agents/me/skills', body: {'skills': skills});
    return User.fromJson(unwrap<Map<String, dynamic>>(r));
  }

  Future<void> setAvailability(bool available) async {
    await _api.patch('/agents/me/availability', body: {'available': available});
  }

  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    await _api.post('/auth/change-password',
        body: {'currentPassword': current, 'newPassword': next});
  }

  Future<void> submitKyc({
    required String idType,
    required String idNumber,
    String? frontImageUrl,
    String? backImageUrl,
    String? selfieUrl,
    String? address,
  }) async {
    await _api.post('/agents/me/kyc', body: {
      'idType': idType,
      'idNumber': idNumber,
      if (frontImageUrl != null) 'frontImageUrl': frontImageUrl,
      if (backImageUrl != null) 'backImageUrl': backImageUrl,
      if (selfieUrl != null) 'selfieUrl': selfieUrl,
      if (address != null) 'address': address,
    });
  }
}
