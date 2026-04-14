import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/constants.dart';

/// Real-time event payload dispatched to widgets.
class RealtimeEvent {
  final String type; // task, chat, payout, notification
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  RealtimeEvent({
    required this.type,
    required this.title,
    required this.body,
    this.data,
  });
}

/// Socket.IO-backed realtime service. Falls back to a no-op stream when the
/// backend is unreachable (so the UI stays usable in demo/offline mode).
class RealtimeService {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();

  io.Socket? _socket;
  final _controller = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get events => _controller.stream;

  bool get connected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(PrefsKeys.auth) ?? '';

    try {
      _socket = io.io(
        '$kWsBaseUrl/notifications',
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );

      _socket!
        ..on('connect', (_) => _log('socket connected'))
        ..on('disconnect', (_) => _log('socket disconnected'))
        ..on('task.assigned', (d) => _emit('task', d, 'New task assigned'))
        ..on('task.updated', (d) => _emit('task', d, 'Task updated'))
        ..on('chat.message', (d) => _emit('chat', d, 'New message'))
        ..on(
          'payout.status',
          (d) => _emit('payout', d, 'Payout status updated'),
        )
        ..on('notification', (d) => _emit('notification', d, 'Notification'));
    } catch (e) {
      _log('socket init failed: $e');
    }
  }

  void _emit(String type, dynamic data, String fallbackTitle) {
    final map = data is Map<String, dynamic>
        ? data
        : (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
    _controller.add(
      RealtimeEvent(
        type: type,
        title: map['title']?.toString() ?? fallbackTitle,
        body: map['body']?.toString() ?? map['message']?.toString() ?? '',
        data: map,
      ),
    );
  }

  void _log(String s) {
    if (kDebugMode) debugPrint('[realtime] $s');
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
