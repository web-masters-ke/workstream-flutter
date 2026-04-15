import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

// ─── Lightweight models for this screen ──────────────────────────────────────

class _Agent {
  final String id;
  final String name;
  final String email;
  _Agent({required this.id, required this.name, required this.email});

  factory _Agent.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map<String, dynamic> : j;
    final fn = (user['firstName'] ?? j['firstName'])?.toString() ?? '';
    final ln = (user['lastName'] ?? j['lastName'])?.toString() ?? '';
    final email = (user['email'] ?? j['email'])?.toString() ?? '';
    var name = '$fn $ln'.trim();
    if (name.isEmpty) name = j['name']?.toString() ?? email;
    if (name.isEmpty) name = 'Agent';
    return _Agent(id: j['id']?.toString() ?? '', name: name, email: email);
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d, y').format(dt);
}

Color _statusColor(String s) {
  switch (s.toUpperCase()) {
    case 'COMPLETED':
      return AppColors.success;
    case 'IN_PROGRESS':
    case 'ASSIGNED':
      return AppColors.primary;
    case 'CANCELLED':
    case 'FAILED':
    case 'REJECTED':
      return AppColors.danger;
    case 'UNDER_REVIEW':
    case 'SUBMITTED':
    case 'ON_HOLD':
      return AppColors.warn;
    default:
      return AppColors.lightSubtext;
  }
}

Color _priorityColor(String p) {
  switch (p.toUpperCase()) {
    case 'URGENT':
      return AppColors.danger;
    case 'HIGH':
      return const Color(0xFFEA580C);
    case 'MEDIUM':
      return AppColors.warn;
    default:
      return AppColors.lightSubtext;
  }
}

String _agentNameFromMap(Map<String, dynamic>? agent) {
  if (agent == null) return 'Unassigned';
  final fn = agent['firstName']?.toString() ?? '';
  final ln = agent['lastName']?.toString() ?? '';
  final name = '$fn $ln'.trim();
  if (name.isNotEmpty) return name;
  return agent['name']?.toString() ?? agent['email']?.toString() ?? 'Agent';
}

List<dynamic> _extractList(dynamic data, [String? key]) {
  if (data is List) return data;
  if (data is Map) {
    if (key != null && data[key] is List) return data[key] as List;
    if (data['items'] is List) return data['items'] as List;
  }
  return [];
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class AdminTaskDetailScreen extends StatefulWidget {
  final String taskId;
  const AdminTaskDetailScreen({super.key, required this.taskId});

  @override
  State<AdminTaskDetailScreen> createState() => _AdminTaskDetailScreenState();
}

class _AdminTaskDetailScreenState extends State<AdminTaskDetailScreen> {
  Map<String, dynamic>? _task;
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _activity = [];
  List<Map<String, dynamic>> _messages = [];
  String? _conversationId;
  bool _loading = true;
  String? _error;
  final _chatCtrl = TextEditingController();
  bool _sendingChat = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get('/tasks/${widget.taskId}'),
        ApiService.instance
            .get('/tasks/${widget.taskId}/submissions')
            .catchError((_) => <String, dynamic>{'success': true, 'data': []}),
        ApiService.instance
            .get('/tasks/${widget.taskId}/activity')
            .catchError((_) => <String, dynamic>{'success': true, 'data': []}),
      ]);

      final taskData = unwrap<Map<String, dynamic>>(results[0]);
      final subData = unwrap<dynamic>(results[1]);
      final actData = unwrap<dynamic>(results[2]);

      // Find or create a conversation for this task
      List<Map<String, dynamic>> messages = [];
      try {
        final convResp = await ApiService.instance.get('/communication/conversations');
        final convRaw = unwrap<dynamic>(convResp);
        final convList = convRaw is List ? convRaw : (convRaw is Map ? (convRaw['items'] ?? []) : []);
        // Find conversation linked to this task
        for (final c in convList) {
          if (c is Map && c['taskId']?.toString() == widget.taskId) {
            _conversationId = c['id']?.toString();
            break;
          }
        }
        // Load messages if conversation exists
        if (_conversationId != null) {
          final msgResp = await ApiService.instance
              .get('/communication/conversations/$_conversationId/messages');
          final msgData = unwrap<dynamic>(msgResp);
          messages = _extractList(msgData, 'messages')
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      } catch (_) {
        // Chat not available — that's OK
      }

      setState(() {
        _task = taskData;
        _submissions = _extractList(subData, 'submissions')
            .whereType<Map<String, dynamic>>()
            .toList();
        _activity = _extractList(actData, 'activity')
            .whereType<Map<String, dynamic>>()
            .toList();
        _messages = messages;
      });
    } catch (e) {
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _status =>
      _task?['status']?.toString().toUpperCase() ?? 'PENDING';

  Future<void> _patchTask(Map<String, dynamic> body,
      {String? successMsg}) async {
    try {
      final resp = await ApiService.instance.patch(
        '/tasks/${widget.taskId}',
        body: body,
      );
      final updated = unwrap<Map<String, dynamic>>(resp);
      if (!mounted) return;
      setState(() => _task = updated);
      _loadAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg ?? 'Task updated'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanError(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingChat = true);
    try {
      // Create conversation for this task if one doesn't exist
      if (_conversationId == null) {
        // Get assigned agent's userId to add as participant
        final agentId = _task?['assignedAgentId']?.toString();
        final participantIds = <String>[];
        if (agentId != null && agentId.isNotEmpty) {
          // The agent record has a userId field
          try {
            final agentResp = await ApiService.instance.get('/agents/$agentId');
            final agentData = unwrap<Map<String, dynamic>>(agentResp);
            final userId = agentData['userId']?.toString();
            if (userId != null) participantIds.add(userId);
          } catch (_) {}
        }
        final convResp = await ApiService.instance.post(
          '/communication/conversations',
          body: {
            'type': 'DIRECT',
            'title': _task?['title']?.toString() ?? 'Task chat',
            'taskId': widget.taskId,
            'participantUserIds': participantIds,
          },
        );
        final convData = unwrap<Map<String, dynamic>>(convResp);
        _conversationId = convData['id']?.toString();
      }

      await ApiService.instance.post(
        '/communication/conversations/$_conversationId/messages',
        body: {'body': text},
      );
      _chatCtrl.clear();
      // Reload messages
      final resp = await ApiService.instance
          .get('/communication/conversations/$_conversationId/messages');
      final data = unwrap<dynamic>(resp);
      if (mounted) {
        setState(() {
          _messages = _extractList(data, 'messages')
              .whereType<Map<String, dynamic>>()
              .toList();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanError(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sendingChat = false);
    }
  }

  void _showReassignSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReassignAgentSheet(
        currentAgentId: _task?['assignedAgentId']?.toString(),
        onPicked: (id, name) {
          Navigator.pop(context);
          _patchTask(
            {'assignedAgentId': id},
            successMsg: id != null ? 'Reassigned to $name' : 'Agent unassigned',
          );
        },
      ),
    );
  }

  void _showReviewSheet(Map<String, dynamic> submission) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReviewSubmissionSheet(
        taskId: widget.taskId,
        submissionId: submission['id']?.toString() ?? '',
        onDone: () {
          Navigator.pop(context);
          _loadAll();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task details')),
        body: const Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_error != null || _task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(_error ?? 'Failed to load task',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger)),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final task = _task!;
    final title = task['title']?.toString() ?? 'Untitled';
    final status = _status;
    final priority = task['priority']?.toString() ?? '';
    final description = task['description']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clone') {
                _patchTask({'clone': true}, successMsg: 'Task cloned');
              } else if (v == 'force_fail') {
                _patchTask(
                    {'status': 'FAILED'}, successMsg: 'Task marked as failed');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clone',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Clone'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'force_fail',
                child: Row(
                  children: [
                    Icon(Icons.dangerous_rounded,
                        size: 18, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Force fail',
                        style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // ── 1. Status + Priority badges ──────────────────────
            Row(
              children: [
                StatusPill(
                  label: status.replaceAll('_', ' '),
                  color: _statusColor(status),
                ),
                if (priority.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  StatusPill(
                    label: priority,
                    color: _priorityColor(priority),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),

            // ── 2. Details card ──────────────────────────────────
            _buildDetailsCard(task, t, subtext),
            const SizedBox(height: 18),

            // ── 3. Description ───────────────────────────────────
            if (description.isNotEmpty) ...[
              const SectionHeader(title: 'Description'),
              const SizedBox(height: 8),
              Text(description,
                  style: t.textTheme.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 18),
            ],

            // ── 4. Agent assignment ──────────────────────────────
            _buildAgentSection(task, t, subtext),
            const SizedBox(height: 18),

            // ── 5. Status controls ───────────────────────────────
            _buildStatusControls(status),
            const SizedBox(height: 18),

            // ── 6. Work submissions ──────────────────────────────
            _buildSubmissionsSection(t, subtext),
            const SizedBox(height: 18),

            // ── 7. Activity timeline ─────────────────────────────
            _buildActivitySection(t, subtext),
            const SizedBox(height: 18),

            // ── 8. Chat section ──────────────────────────────────
            _buildChatSection(t, subtext, isDark),
          ],
        ),
      ),
    );
  }

  // ─── Details card ────────────────────────────────────────────────────────

  Widget _buildDetailsCard(
      Map<String, dynamic> task, ThemeData t, Color subtext) {
    final sla = task['slaMinutes'];
    final agent = task['agent'] is Map
        ? task['agent'] as Map<String, dynamic>
        : null;
    final skill = task['skill']?.toString() ??
        task['category']?.toString() ??
        '';
    final startedAt = _parseDate(task['startedAt']);
    final completedAt = _parseDate(task['completedAt']);
    final job = task['job'] is Map
        ? (task['job'] as Map)['title']?.toString()
        : task['jobId']?.toString();
    final qaScore = task['qaScore'];
    final dueAt = _parseDate(task['dueAt'] ?? task['deadline']);
    final priority = task['priority']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        children: [
          // Row 1
          Row(
            children: [
              Expanded(child: _detailItem('Priority', priority, subtext)),
              Expanded(
                child: _detailItem(
                  'SLA',
                  sla != null ? '$sla min' : '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Agent',
                  _agentNameFromMap(agent),
                  subtext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row 2
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  'Skill',
                  skill.isNotEmpty
                      ? skill.replaceAll('_', ' ')
                      : '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Started',
                  startedAt != null
                      ? DateFormat('MMM d, HH:mm').format(startedAt)
                      : '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Completed',
                  completedAt != null
                      ? DateFormat('MMM d, HH:mm').format(completedAt)
                      : '--',
                  subtext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row 3
          Row(
            children: [
              Expanded(
                child: _detailItem(
                  'Job',
                  job ?? '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'QA score',
                  qaScore != null ? '$qaScore' : '--',
                  subtext,
                ),
              ),
              Expanded(
                child: _detailItem(
                  'Due date',
                  dueAt != null
                      ? DateFormat('MMM d, HH:mm').format(dueAt)
                      : '--',
                  subtext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value, Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: subtext,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ─── Agent assignment ───────────────────────────────────────────────────

  Widget _buildAgentSection(
      Map<String, dynamic> task, ThemeData t, Color subtext) {
    final agent = task['agent'] is Map
        ? task['agent'] as Map<String, dynamic>
        : null;
    final agentName = _agentNameFromMap(agent);
    final initial = agentName.isNotEmpty ? agentName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (agent != null && agent['email'] != null)
                  Text(
                    agent['email'].toString(),
                    style: TextStyle(color: subtext, fontSize: 12),
                  ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _showReassignSheet,
            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
            label: const Text('Reassign'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Status controls ────────────────────────────────────────────────────

  Widget _buildStatusControls(String status) {
    final List<Widget> buttons = [];

    switch (status) {
      case 'PENDING':
      case 'AVAILABLE':
        buttons.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: _showReassignSheet,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Assign'),
            ),
          ),
        );
        break;

      case 'ASSIGNED':
      case 'IN_PROGRESS':
        buttons.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _patchTask(
                {'status': 'FAILED'},
                successMsg: 'Task marked as failed',
              ),
              icon: const Icon(Icons.dangerous_rounded,
                  size: 18, color: AppColors.danger),
              label: const Text('Force fail',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ),
        );
        buttons.add(const SizedBox(width: 10));
        buttons.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _patchTask(
                {'status': 'ON_HOLD'},
                successMsg: 'Task put on hold',
              ),
              icon: const Icon(Icons.pause_circle_rounded, size: 18),
              label: const Text('Put on hold'),
            ),
          ),
        );
        break;

      case 'UNDER_REVIEW':
      case 'SUBMITTED':
        buttons.add(
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _patchTask(
                {'status': 'ASSIGNED'},
                successMsg: 'Task rejected, sent back to agent',
              ),
              icon: const Icon(Icons.replay_rounded,
                  size: 18, color: AppColors.danger),
              label: const Text('Reject',
                  style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
              ),
            ),
          ),
        );
        buttons.add(const SizedBox(width: 10));
        buttons.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _patchTask(
                {'status': 'COMPLETED'},
                successMsg: 'Task approved and completed',
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Approve'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
            ),
          ),
        );
        break;

      case 'ON_HOLD':
        buttons.add(
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _patchTask(
                {'status': 'IN_PROGRESS'},
                successMsg: 'Task resumed',
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Resume'),
            ),
          ),
        );
        break;

      default:
        // COMPLETED, FAILED, CANCELLED — no actions
        return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Actions'),
        const SizedBox(height: 8),
        Row(children: buttons),
      ],
    );
  }

  // ─── Submissions ────────────────────────────────────────────────────────

  Widget _buildSubmissionsSection(ThemeData t, Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Work submissions (${_submissions.length})',
        ),
        const SizedBox(height: 8),
        if (_submissions.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Text(
              'No submissions yet.',
              style: TextStyle(color: subtext, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...List.generate(_submissions.length, (i) {
            final sub = _submissions[i];
            return _buildSubmissionTile(sub, i + 1, t, subtext);
          }),
      ],
    );
  }

  Widget _buildSubmissionTile(
    Map<String, dynamic> sub,
    int round,
    ThemeData t,
    Color subtext,
  ) {
    final type = sub['type']?.toString() ?? 'text';
    final content = sub['content']?.toString() ??
        sub['url']?.toString() ??
        '';
    final notes = sub['notes']?.toString() ?? '';
    final subStatus = sub['status']?.toString().toUpperCase() ?? '';
    final reviewer = sub['reviewer'] is Map
        ? _agentNameFromMap(sub['reviewer'] as Map<String, dynamic>)
        : sub['reviewerName']?.toString();
    final createdAt = _parseDate(sub['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Round $round',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: subtext.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subtext,
                  ),
                ),
              ),
              const Spacer(),
              if (subStatus.isNotEmpty)
                StatusPill(
                  label: subStatus.replaceAll('_', ' '),
                  color: _statusColor(subStatus),
                ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              content,
              style: t.textTheme.bodySmall?.copyWith(height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: $notes',
              style: TextStyle(
                  color: subtext, fontSize: 12, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (reviewer != null) ...[
                Icon(Icons.person_outline_rounded, size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  reviewer,
                  style: TextStyle(color: subtext, fontSize: 11),
                ),
                const SizedBox(width: 12),
              ],
              if (createdAt != null) ...[
                Icon(Icons.schedule_rounded, size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  _relativeTime(createdAt),
                  style: TextStyle(color: subtext, fontSize: 11),
                ),
              ],
              const Spacer(),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: () => _showReviewSheet(sub),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Activity timeline ──────────────────────────────────────────────────

  Widget _buildActivitySection(ThemeData t, Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Activity (${_activity.length})'),
        const SizedBox(height: 8),
        if (_activity.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Text(
              'No activity yet.',
              style: TextStyle(color: subtext, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...List.generate(_activity.length, (i) {
            final entry = _activity[i];
            return _buildActivityEntry(entry, i, t, subtext);
          }),
      ],
    );
  }

  Widget _buildActivityEntry(
    Map<String, dynamic> entry,
    int index,
    ThemeData t,
    Color subtext,
  ) {
    final action = entry['action']?.toString() ??
        entry['description']?.toString() ??
        entry['type']?.toString() ??
        'Activity';
    final actorMap = entry['actor'] is Map
        ? entry['actor'] as Map<String, dynamic>
        : null;
    final actor = actorMap != null
        ? _agentNameFromMap(actorMap)
        : entry['actorName']?.toString() ?? '';
    final ts = _parseDate(entry['createdAt'] ?? entry['timestamp']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary, width: 2),
                  ),
                ),
                if (index < _activity.length - 1)
                  Container(
                    width: 2,
                    height: 32,
                    color: t.dividerColor,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: t.textTheme.bodySmall?.copyWith(height: 1.3),
                      children: [
                        if (actor.isNotEmpty)
                          TextSpan(
                            text: '$actor ',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                        TextSpan(text: action),
                      ],
                    ),
                  ),
                  if (ts != null)
                    Text(
                      _relativeTime(ts),
                      style: TextStyle(
                          color: subtext, fontSize: 11),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Chat section ───────────────────────────────────────────────────────

  Widget _buildChatSection(ThemeData t, Color subtext, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Chat (${_messages.length})'),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 350),
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Messages list
              if (_messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No messages yet.',
                    style: TextStyle(color: subtext, fontSize: 13),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _buildChatBubble(_messages[i], t, subtext, isDark),
                  ),
                ),
              // Input
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: t.dividerColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          isDense: true,
                        ),
                        maxLines: 2,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _sendingChat ? null : _sendMessage,
                      icon: _sendingChat
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded,
                              color: AppColors.primary, size: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble(
    Map<String, dynamic> msg,
    ThemeData t,
    Color subtext,
    bool isDark,
  ) {
    final senderMap = msg['sender'] is Map
        ? msg['sender'] as Map<String, dynamic>
        : null;
    final senderName = senderMap != null
        ? _agentNameFromMap(senderMap)
        : msg['senderName']?.toString() ?? '';
    final body = msg['body']?.toString() ?? msg['text']?.toString() ?? '';
    final ts = _parseDate(msg['createdAt'] ?? msg['timestamp']);
    final isAdmin = msg['isAdmin'] == true ||
        msg['senderRole']?.toString().toUpperCase() == 'ADMIN' ||
        msg['senderRole']?.toString().toUpperCase() == 'BUSINESS';
    final align = isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isAdmin
        ? AppColors.primary.withValues(alpha: 0.12)
        : (isDark ? AppColors.darkCard : const Color(0xFFF3F4F6));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (senderName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subtext,
                ),
              ),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(body, style: const TextStyle(fontSize: 13)),
          ),
          if (ts != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _relativeTime(ts),
                style: TextStyle(fontSize: 10, color: subtext),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Reassign Agent Bottom Sheet ─────────────────────────────────────────────

class _ReassignAgentSheet extends StatefulWidget {
  final String? currentAgentId;
  final void Function(String? id, String? name) onPicked;

  const _ReassignAgentSheet({
    required this.currentAgentId,
    required this.onPicked,
  });

  @override
  State<_ReassignAgentSheet> createState() => _ReassignAgentSheetState();
}

class _ReassignAgentSheetState extends State<_ReassignAgentSheet> {
  final _searchCtrl = TextEditingController();
  List<_Agent> _agents = [];
  List<_Agent> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    try {
      final resp =
          await ApiService.instance.get('/agents', query: {'limit': '100'});
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
      if (!mounted) return;
      setState(() {
        _agents = list
            .whereType<Map<String, dynamic>>()
            .map(_Agent.fromJson)
            .toList();
        _filtered = _agents;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter(String q) {
    final query = q.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _agents;
      } else {
        _filtered = _agents
            .where((a) =>
                a.name.toLowerCase().contains(query) ||
                a.email.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Reassign agent',
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => widget.onPicked(null, null),
                    child: const Text('Unassign'),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filter('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            // Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtered.length} agent${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Agent list
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(strokeWidth: 2.5))
                  : _filtered.isEmpty
                      ? Center(
                          child: Text('No agents found',
                              style: TextStyle(color: subtext)),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          itemBuilder: (_, i) {
                            final a = _filtered[i];
                            final selected =
                                a.id == widget.currentAgentId;
                            return ListTile(
                              selected: selected,
                              selectedTileColor:
                                  AppColors.primary.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary
                                    .withValues(alpha: 0.15),
                                child: Text(
                                  a.name.isNotEmpty
                                      ? a.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              title: Text(a.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              subtitle: Text(a.email,
                                  style: TextStyle(
                                      color: subtext, fontSize: 12)),
                              trailing: selected
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primary,
                                      size: 20)
                                  : null,
                              onTap: () =>
                                  widget.onPicked(a.id, a.name),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Review Submission Bottom Sheet ──────────────────────────────────────────

class _ReviewSubmissionSheet extends StatefulWidget {
  final String taskId;
  final String submissionId;
  final VoidCallback onDone;

  const _ReviewSubmissionSheet({
    required this.taskId,
    required this.submissionId,
    required this.onDone,
  });

  @override
  State<_ReviewSubmissionSheet> createState() =>
      _ReviewSubmissionSheetState();
}

class _ReviewSubmissionSheetState extends State<_ReviewSubmissionSheet> {
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _review(String verdict) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.instance.patch(
        '/tasks/${widget.taskId}/submissions/${widget.submissionId}',
        body: {
          'verdict': verdict,
          'note': _noteCtrl.text.trim(),
        },
      );
      widget.onDone();
    } catch (e) {
      setState(() {
        _error = cleanError(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomNav = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset + bottomNav),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
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
            Text('Review submission',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            // Note field
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Review note',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add review comments...',
              ),
            ),
            const SizedBox(height: 16),

            // Error
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => _review('REJECTED'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    child: const Text('Reject',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => _review('REVISION_REQUESTED'),
                    child: const Text('Request revision',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : () => _review('APPROVED'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Approve',
                            style:
                                TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
