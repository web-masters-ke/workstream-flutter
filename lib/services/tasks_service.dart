import '../models/task.dart';
import 'api_service.dart';

class TasksService {
  final _api = ApiService.instance;

  Future<List<Task>> available({int page = 1, int size = 20}) async {
    final r = await _api.get(
      '/tasks/available',
      query: {'page': page, 'size': size},
    );
    return _parseList(r);
  }

  Future<List<Task>> mine({TaskStatus? status}) async {
    final r = await _api.get(
      '/tasks/mine',
      query: status == null ? null : {'status': status.apiValue},
    );
    return _parseList(r);
  }

  Future<Task> getById(String id) async {
    final r = await _api.get('/tasks/$id');
    final data = unwrap<Map<String, dynamic>>(r);
    return Task.fromJson(data);
  }

  Future<Task> accept(String id) async {
    final r = await _api.post('/tasks/$id/accept');
    final data = unwrap<Map<String, dynamic>>(r);
    return Task.fromJson(data);
  }

  Future<Task> reject(String id, {String? reason}) async {
    final r = await _api.post(
      '/tasks/$id/reject',
      body: {if (reason != null) 'reason': reason},
    );
    final data = unwrap<Map<String, dynamic>>(r);
    return Task.fromJson(data);
  }

  Future<Task> start(String id) async {
    final r = await _api.post('/tasks/$id/start');
    final data = unwrap<Map<String, dynamic>>(r);
    return Task.fromJson(data);
  }

  Future<Task> submit(
    String id, {
    String? notes,
    String? outcome,
    String? attachmentUrl,
  }) async {
    final r = await _api.post(
      '/tasks/$id/submit',
      body: {
        if (notes != null) 'notes': notes,
        if (outcome != null) 'outcome': outcome,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      },
    );
    final data = unwrap<Map<String, dynamic>>(r);
    return Task.fromJson(data);
  }

  List<Task> _parseList(Map<String, dynamic> r) {
    final data = unwrap<dynamic>(r);
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['items'] is List
              ? data['items'] as List
              : const []);
    return list
        .whereType<Map>()
        .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
