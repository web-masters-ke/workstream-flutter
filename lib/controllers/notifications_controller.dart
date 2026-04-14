import 'package:flutter/foundation.dart';

import '../models/notification.dart';
import '../services/notifications_service.dart';

class NotificationsController extends ChangeNotifier {
  final _svc = NotificationsService();

  List<AppNotification> _items = [];
  bool _loading = false;
  String? _error;

  List<AppNotification> get items => _items;
  bool get loading => _loading;
  String? get error => _error;
  int get unread => _items.where((n) => !n.read).length;

  Map<String, List<AppNotification>> grouped() {
    final Map<String, List<AppNotification>> out = {};
    final now = DateTime.now();
    for (final n in _items) {
      final d = n.createdAt;
      final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
      final y = now.subtract(const Duration(days: 1));
      final isYesterday = d.year == y.year && d.month == y.month && d.day == y.day;
      final key = sameDay
          ? 'Today'
          : isYesterday
              ? 'Yesterday'
              : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      out.putIfAbsent(key, () => []).add(n);
    }
    return out;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _svc.list();
    } catch (e) {
      _error = e.toString();
      _items = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markAll() async {
    try {
      await _svc.markAllRead();
    } catch (_) {}
    _items = _items
        .map((n) => AppNotification(
              id: n.id,
              kind: n.kind,
              title: n.title,
              body: n.body,
              read: true,
              createdAt: n.createdAt,
              data: n.data,
            ))
        .toList();
    notifyListeners();
  }

  Future<void> markOne(String id) async {
    try {
      await _svc.markRead(id);
    } catch (_) {}
    _items = _items.map((n) {
      if (n.id != id) return n;
      return AppNotification(
        id: n.id,
        kind: n.kind,
        title: n.title,
        body: n.body,
        read: true,
        createdAt: n.createdAt,
        data: n.data,
      );
    }).toList();
    notifyListeners();
  }

  void injectLive({
    required NotificationKind kind,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    _items = [
      AppNotification(
        id: 'live-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        title: title,
        body: body,
        read: false,
        createdAt: DateTime.now(),
        data: data ?? {},
      ),
      ..._items,
    ];
    notifyListeners();
  }

  Future<void> reload() => load();
}
