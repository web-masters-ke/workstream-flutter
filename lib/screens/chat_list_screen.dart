import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'call_screen.dart';
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

  void _showNewConversationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NewConversationSheet(
        onCreated: (thread) {
          Navigator.of(ctx).pop();
          _load();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ChatScreen(threadId: thread.id, title: thread.title),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskThreads = _threads.where((t) => t.isTask).toList();
    final directThreads = _threads.where((t) => !t.isTask).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call_rounded),
            tooltip: 'Start a call',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CallsScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
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
              ? EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No conversations yet',
                  message: 'Tap + to start a new conversation.',
                  action: FilledButton.icon(
                    onPressed: _showNewConversationSheet,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New conversation'),
                  ),
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
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─── Thread tile ──────────────────────────────────────────────────────────────

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
            backgroundColor: AppColors.primary.withValues(alpha: 0.18),
            child: Text(
              thread.title.isNotEmpty ? thread.title[0] : '?',
              style: const TextStyle(
                color: AppColors.primary,
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
                color: AppColors.primary,
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

// ─── New Conversation Bottom Sheet ────────────────────────────────────────────

class _MemberItem {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  _MemberItem({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  String get initials {
    final parts = name.split(' ');
    final a = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }

  factory _MemberItem.fromJson(Map<String, dynamic> j) {
    final first = j['firstName']?.toString() ?? '';
    final last = j['lastName']?.toString() ?? '';
    final name = '$first $last'.trim();
    return _MemberItem(
      id: j['id']?.toString() ?? '',
      name: name.isEmpty ? (j['email']?.toString() ?? 'Unknown') : name,
      email: j['email']?.toString() ?? '',
      avatarUrl: j['avatarUrl']?.toString(),
    );
  }
}

class _NewConversationSheet extends StatefulWidget {
  final void Function(ChatThread thread) onCreated;
  const _NewConversationSheet({required this.onCreated});

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  bool _isGroup = false;
  final _searchCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  List<_MemberItem> _allMembers = [];
  List<_MemberItem> _filtered = [];
  final Set<String> _selectedIds = {};
  bool _loadingMembers = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _groupNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final currentUserId =
        context.read<AuthController>().user?.id ?? '';
    try {
      final resp = await ApiService.instance.get('/agents');
      final data = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else if (data is Map && data['agents'] is List) {
        list = data['agents'] as List;
      } else {
        list = [];
      }
      _allMembers = list
          .whereType<Map<String, dynamic>>()
          .map(_MemberItem.fromJson)
          .where((m) => m.id != currentUserId && m.id.isNotEmpty)
          .toList();
      _filtered = List.of(_allMembers);
    } catch (e) {
      _error = 'Could not load team members';
    }
    if (mounted) setState(() => _loadingMembers = false);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.of(_allMembers);
      } else {
        _filtered = _allMembers
            .where((m) =>
                m.name.toLowerCase().contains(q) ||
                m.email.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  void _toggleMember(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        // Direct message: only one member at a time
        if (!_isGroup) _selectedIds.clear();
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _create() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _creating = true);

    try {
      final type = _isGroup ? 'GROUP' : 'DIRECT';
      final body = <String, dynamic>{
        'participantIds': _selectedIds.toList(),
        'type': type,
      };
      if (_isGroup) {
        final name = _groupNameCtrl.text.trim();
        if (name.isNotEmpty) body['title'] = name;
      }

      final resp = await ApiService.instance
          .post('/communication/conversations', body: body);
      final data = unwrap<Map<String, dynamic>>(resp);
      final thread = ChatThread.fromJson(data);
      widget.onCreated(thread);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  List<_MemberItem> get _selectedMembers =>
      _allMembers.where((m) => _selectedIds.contains(m.id)).toList();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // ── Handle ────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: t.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'New Conversation',
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Toggle: DM vs Group ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.dividerColor),
              ),
              child: Row(
                children: [
                  _toggleTab('Direct Message', !_isGroup, () {
                    setState(() {
                      _isGroup = false;
                      // Keep only one selection in DM mode
                      if (_selectedIds.length > 1) {
                        final first = _selectedIds.first;
                        _selectedIds
                          ..clear()
                          ..add(first);
                      }
                    });
                  }),
                  _toggleTab('Group Chat', _isGroup, () {
                    setState(() => _isGroup = true);
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Group name (only if group) ────────────────────
          if (_isGroup)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _groupNameCtrl,
                decoration: InputDecoration(
                  hintText: 'Group name (optional)',
                  prefixIcon:
                      const Icon(Icons.group_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.dividerColor),
                  ),
                ),
              ),
            ),

          // ── Selected chips ────────────────────────────────
          if (_selectedMembers.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _selectedMembers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = _selectedMembers[i];
                  return Chip(
                    label: Text(m.name,
                        style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => _toggleMember(m.id),
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  );
                },
              ),
            ),
          if (_selectedMembers.isNotEmpty) const SizedBox(height: 8),

          // ── Search field ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search team members...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.dividerColor),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Member list ───────────────────────────────────
          Expanded(
            child: _loadingMembers
                ? const Center(
                    child:
                        CircularProgressIndicator(strokeWidth: 2.5))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: TextStyle(color: subtext)))
                    : _filtered.isEmpty
                        ? Center(
                            child: Text('No members found',
                                style: TextStyle(color: subtext)))
                        : ListView.builder(
                            controller: scrollCtrl,
                            itemCount: _filtered.length,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            itemBuilder: (_, i) {
                              final m = _filtered[i];
                              final selected =
                                  _selectedIds.contains(m.id);
                              return ListTile(
                                onTap: () => _toggleMember(m.id),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.primary
                                      .withValues(alpha: 0.18),
                                  child: Text(
                                    m.initials,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(m.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(m.email,
                                    style: TextStyle(
                                        color: subtext, fontSize: 12)),
                                trailing: selected
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.primary)
                                    : Icon(
                                        Icons.circle_outlined,
                                        color: t.dividerColor),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              );
                            },
                          ),
          ),

          // ── Create button ─────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selectedIds.isEmpty || _creating ? null : _create,
                  child: _creating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isGroup
                          ? 'Create Group (${_selectedIds.length})'
                          : 'Start Conversation'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
