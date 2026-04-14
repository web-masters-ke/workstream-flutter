import '../models/notification.dart';
import 'api_service.dart';

class NotificationsService {
  final _api = ApiService.instance;

  Future<List<AppNotification>> list() async {
    final r = await _api.get('/notifications');
    final data = unwrap<dynamic>(r);
    final list = data is List ? data : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _api.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.post('/notifications/read-all');
  }
}
