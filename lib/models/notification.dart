enum NotificationKind {
  task,
  chat,
  wallet,
  system;

  static NotificationKind fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'TASK':
        return NotificationKind.task;
      case 'CHAT':
        return NotificationKind.chat;
      case 'WALLET':
      case 'PAYMENT':
        return NotificationKind.wallet;
      default:
        return NotificationKind.system;
    }
  }
}

class AppNotification {
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id']?.toString() ?? '',
        kind: NotificationKind.fromString(json['kind']?.toString()),
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        read: json['read'] == true,
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        data: json['data'] is Map<String, dynamic>
            ? Map<String, dynamic>.from(json['data'] as Map)
            : <String, dynamic>{},
      );
}
