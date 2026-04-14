class ChatThread {
  final String id;
  final String title;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unread;
  final bool online;

  ChatThread({
    required this.id,
    required this.title,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    required this.unread,
    required this.online,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString(),
    lastMessage: json['lastMessage']?.toString(),
    lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
    unread: (json['unread'] is num) ? (json['unread'] as num).toInt() : 0,
    online: json['online'] == true,
  );
}

class ChatMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String? senderName;
  final String body;
  final DateTime createdAt;
  final bool mine;

  ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    this.senderName,
    required this.body,
    required this.createdAt,
    required this.mine,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final senderId = json['senderId']?.toString() ?? '';
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      threadId: json['threadId']?.toString() ?? '',
      senderId: senderId,
      senderName: json['senderName']?.toString(),
      body: json['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      mine: senderId == currentUserId,
    );
  }
}
