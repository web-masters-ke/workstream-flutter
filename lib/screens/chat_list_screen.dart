import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/message.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatThread> _threads = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _threads = await ChatService().threads();
    } catch (e) {
      _threads = [];
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final taskThreads =
        _threads.where((t) => t.id.startsWith('task-')).toList();
    final directThreads =
        _threads.where((t) => !t.id.startsWith('task-')).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _threads.isEmpty
              ? const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No conversations yet',
                  message: 'Chats from businesses will show up here.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      if (taskThreads.isNotEmpty) ...[
                        _sectionLabel('Task conversations'),
                        ...taskThreads.map(
                            (t) => _ThreadTile(thread: t)),
                      ],
                      if (directThreads.isNotEmpty) ...[
                        _sectionLabel('Direct'),
                        ...directThreads.map(
                            (t) => _ThreadTile(thread: t)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  final ChatThread thread;
  const _ThreadTile({required this.thread});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    return ListTile(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ChatScreen(threadId: thread.id, title: thread.title),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.accent.withValues(alpha: 0.18),
            child: Text(
              thread.title.isNotEmpty ? thread.title[0] : '?',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (thread.online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: t.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        thread.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        thread.lastMessage ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: subtext),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            thread.lastMessageAt == null
                ? ''
                : _shortTime(thread.lastMessageAt!),
            style: TextStyle(fontSize: 11, color: subtext),
          ),
          const SizedBox(height: 4),
          if (thread.unread > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${thread.unread}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _shortTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(d);
  }
}
