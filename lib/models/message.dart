class ChatThread {
  final String id;
  final String title;
  final String type; // 'TASK' | 'DIRECT' | 'GROUP'
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unread;
  final bool online;

  ChatThread({
    required this.id,
    required this.title,
    required this.type,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    required this.unread,
    required this.online,
  });

  bool get isTask => type == 'TASK';

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    // Last message from embedded messages array (if present)
    String? lastMsg;
    DateTime? lastAt;
    final msgs = json['messages'];
    if (msgs is List && msgs.isNotEmpty) {
      final last = msgs.last;
      if (last is Map) {
        lastMsg = last['body']?.toString();
        lastAt = DateTime.tryParse(last['createdAt']?.toString() ?? '');
      }
    }

    // Title: use explicit title, or derive from participants if missing
    String title = json['title']?.toString() ?? '';
    if (title.isEmpty) {
      final participants = json['participants'];
      if (participants is List && participants.isNotEmpty) {
        title = participants
            .whereType<Map>()
            .map((p) {
              final u = p['user'];
              if (u is Map) return u['name']?.toString() ?? '';
              return '';
            })
            .where((n) => n.isNotEmpty)
            .join(', ');
      }
    }

    return ChatThread(
      id: json['id']?.toString() ?? '',
      title: title.isEmpty ? 'Chat' : title,
      type: json['type']?.toString() ?? 'DIRECT',
      avatarUrl: json['avatarUrl']?.toString(),
      lastMessage: lastMsg ?? json['lastMessage']?.toString(),
      lastMessageAt: lastAt ??
          DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ??
          DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      unread: (json['unread'] is num) ? (json['unread'] as num).toInt() : 0,
      online: json['online'] == true,
    );
  }
}

class ChatMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String? senderName;
  final String body;
  final String? attachmentUrl;
  final DateTime createdAt;
  final bool mine;

  ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    this.senderName,
    required this.body,
    this.attachmentUrl,
    required this.createdAt,
    required this.mine,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final senderId = json['senderId']?.toString() ?? '';
    // Sender name from embedded sender object or flat field
    String? senderName;
    if (json['sender'] is Map) {
      senderName = (json['sender'] as Map)['name']?.toString();
    }
    senderName ??= json['senderName']?.toString();

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      threadId: (json['conversationId'] ?? json['threadId'])?.toString() ?? '',
      senderId: senderId,
      senderName: senderName,
      body: json['body']?.toString() ?? '',
      attachmentUrl: json['attachmentUrl']?.toString(),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      mine: senderId == currentUserId,
    );
  }
}
