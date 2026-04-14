import '../models/message.dart';
import 'api_service.dart';

class ChatService {
  final _api = ApiService.instance;

  Future<List<ChatThread>> threads() async {
    final r = await _api.get('/chat/threads');
    final data = unwrap<dynamic>(r);
    final list = data is List ? data : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ChatMessage>> messages(
    String threadId, {
    required String currentUserId,
  }) async {
    final r = await _api.get('/chat/threads/$threadId/messages');
    final data = unwrap<dynamic>(r);
    final list = data is List ? data : const <dynamic>[];
    return list
        .whereType<Map>()
        .map(
          (e) => ChatMessage.fromJson(
            Map<String, dynamic>.from(e),
            currentUserId: currentUserId,
          ),
        )
        .toList();
  }

  Future<ChatMessage> send(
    String threadId,
    String body, {
    required String currentUserId,
  }) async {
    final r = await _api.post(
      '/chat/threads/$threadId/messages',
      body: {'body': body},
    );
    final data = unwrap<Map<String, dynamic>>(r);
    return ChatMessage.fromJson(data, currentUserId: currentUserId);
  }
}
