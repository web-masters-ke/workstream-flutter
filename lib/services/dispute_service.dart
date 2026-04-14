import 'api_service.dart';

class DisputeService {
  final _api = ApiService.instance;

  Future<void> raise({
    required String taskId,
    required String reason,
    String? details,
  }) async {
    await _api.post('/disputes', body: {
      'taskId': taskId,
      'reason': reason,
      if (details != null) 'details': details,
    });
  }
}
