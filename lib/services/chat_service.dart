import '../models/message.dart';
import 'api_service.dart';

class ChatService {
  final _api = ApiService.instance;

  Future<List<ChatThread>> threads() async {
    final r = await _api.get('/communication/conversations');
    final data = unwrap<dynamic>(r);
    final list = data is List ? data : const <dynamic>[];
    return list
        .whereType<Map>()
        .map((e) => ChatThread.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ChatMessage>> messages(
    String conversationId, {
    required String currentUserId,
  }) async {
    final r = await _api.get('/communication/conversations/$conversationId/messages');
    final data = unwrap<dynamic>(r);
    // Backend returns { items: [...] } or a plain list
    List<dynamic> list;
    if (data is Map && data['items'] is List) {
      list = data['items'] as List;
    } else if (data is List) {
      list = data;
    } else {
      list = const [];
    }
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
    String conversationId,
    String body, {
    required String currentUserId,
  }) async {
    final r = await _api.post(
      '/communication/conversations/$conversationId/messages',
      body: {'body': body, 'type': 'TEXT'},
    );
    final data = unwrap<Map<String, dynamic>>(r);
    return ChatMessage.fromJson(data, currentUserId: currentUserId);
  }
}
