import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

class _Task {
  final String id;
  final String title;
  final String status;
  final String? agentName;
  final String? priority;
  final DateTime? createdAt;
  final DateTime? deadline;

  _Task({
    required this.id,
    required this.title,
    required this.status,
    this.agentName,
    this.priority,
    this.createdAt,
    this.deadline,
  });

  factory _Task.fromJson(Map<String, dynamic> j) {
    DateTime? dt(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    String? agentName;
    if (j['agent'] is Map) {
      final a = j['agent'] as Map;
      final fn = a['firstName']?.toString() ?? '';
      final ln = a['lastName']?.toString() ?? '';
      agentName = '$fn $ln'.trim();
      if (agentName.isEmpty) agentName = null;
    } else if (j['agentName'] != null) {
      agentName = j['agentName'].toString();
    }

    return _Task(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Untitled',
      status: j['status']?.toString() ?? 'PENDING',
      agentName: agentName,
      priority: j['priority']?.toString(),
      createdAt: dt(j['createdAt']),
      deadline: dt(j['deadline'] ?? j['dueDate']),
    );
  }
}

const _statuses = ['ALL', 'PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  List<_Task> _tasks = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'ALL';

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
      final query = <String, dynamic>{'limit': '100'};
      if (_statusFilter != 'ALL') query['status'] = _statusFilter;
      final resp = await ApiService.instance.get('/tasks', query: query);
      final data = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else if (data is Map && data['tasks'] is List) {
        list = data['tasks'] as List;
      } else {
        list = [];
      }
      setState(() {
        _tasks = list
            .whereType<Map<String, dynamic>>()
            .map(_Task.fromJson)
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text('${_tasks.length}'),
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
              labelStyle: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status filter chips ─────────────────────────────
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final active = _statusFilter == s;
                return FilterChip(
                  label: Text(s),
                  selected: active,
                  onSelected: (_) {
                    setState(() => _statusFilter = s);
                    _load();
                  },
                  selectedColor: AppColors.accent.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.accent,
                  labelStyle: TextStyle(
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                    color: active ? AppColors.accent : subtext,
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 40),
                            const SizedBox(height: 12),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.danger)),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _tasks.isEmpty
                        ? const EmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'No tasks',
                            message: 'Tasks will appear here.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.only(bottom: 24),
                              itemCount: _tasks.length,
                              itemBuilder: (_, i) =>
                                  _TaskTile(task: _tasks[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final _Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    final (statusColor, statusBg) = _statusColors(task.status);

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_statusIcon(task.status), color: statusColor, size: 20),
      ),
      title: Text(
        task.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              if (task.priority != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _priorityColor(task.priority!)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _priorityColor(task.priority!),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (task.agentName != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  task.agentName!,
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ],
            ),
          ],
          if (task.deadline != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  DateFormat('MMM d, y').format(task.deadline!),
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color) _statusColors(String s) {
    switch (s) {
      case 'COMPLETED':
        return (AppColors.success,
            AppColors.success.withValues(alpha: 0.12));
      case 'IN_PROGRESS':
        return (AppColors.accent, AppColors.accent.withValues(alpha: 0.12));
      case 'CANCELLED':
        return (AppColors.danger, AppColors.danger.withValues(alpha: 0.12));
      default:
        return (AppColors.warn, AppColors.warn.withValues(alpha: 0.12));
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'IN_PROGRESS':
        return Icons.autorenew_rounded;
      case 'CANCELLED':
        return Icons.cancel_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  Color _priorityColor(String p) {
    switch (p.toUpperCase()) {
      case 'HIGH':
      case 'URGENT':
        return AppColors.danger;
      case 'MEDIUM':
        return AppColors.warn;
      default:
        return AppColors.lightSubtext;
    }
  }
}
