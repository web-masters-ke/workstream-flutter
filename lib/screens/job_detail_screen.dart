import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

// ─── Job Detail Screen ──────────────────────────────────────────────────────

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Map<String, dynamic>? _job;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _activity = [];
  List<Map<String, dynamic>> _agents = [];
  bool _loading = true;
  String? _error;
  final _noteCtrl = TextEditingController();
  bool _addingNote = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get('/jobs/${widget.jobId}'),
        ApiService.instance.get('/tasks', query: {'jobId': widget.jobId}).catchError((_) => <String, dynamic>{}),
        ApiService.instance.get('/jobs/${widget.jobId}/activity').catchError((_) => <String, dynamic>{'success': true, 'data': []}),
        ApiService.instance.get('/agents').catchError((_) => <String, dynamic>{}),
      ]);

      final jobData = unwrap<dynamic>(results[0]);
      final jobMap = jobData is Map<String, dynamic> ? jobData : <String, dynamic>{};

      _job = jobMap;
      _tasks = _parseList(results[1], ['items', 'tasks']);
      _notes = _parseNotes(jobMap);
      _activity = _parseList(results[2], ['items', 'activity', 'events']);
      _agents = _parseList(results[3], ['items', 'agents']);
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), '');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _parseList(
      Map<String, dynamic> resp, List<String> keys) {
    try {
      final data = unwrap<dynamic>(resp);
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
      if (data is Map<String, dynamic>) {
        for (final k in keys) {
          if (data[k] is List) {
            return (data[k] as List).whereType<Map<String, dynamic>>().toList();
          }
        }
      }
    } catch (_) {}
    return [];
  }

  List<Map<String, dynamic>> _parseNotes(Map<String, dynamic> job) {
    final raw = job['notes'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  // ── KPI helpers ──────────────────────────────────────────────────────────
  int _countTasksByStatus(String status) {
    return _tasks.where((t) {
      final s = t['status']?.toString().toUpperCase() ?? '';
      return s == status;
    }).length;
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  Future<void> _updateTaskStatus(String taskId, String newStatus) async {
    try {
      await ApiService.instance.patch(
        '/tasks/$taskId',
        body: {'status': newStatus},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    }
  }

  Future<void> _updateTaskAgent(String taskId, String agentId) async {
    try {
      await ApiService.instance.patch(
        '/tasks/$taskId',
        body: {'assignedAgentId': agentId},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    }
  }

  Future<void> _addNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _addingNote = true);
    try {
      await ApiService.instance.post(
        '/jobs/${widget.jobId}/notes',
        body: {'content': text},
      );
      _noteCtrl.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    }
    if (mounted) setState(() => _addingNote = false);
  }

  Future<void> _escalate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escalate job?'),
        content: const Text(
            'This will flag the job for immediate supervisor attention.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Escalate')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.post('/jobs/${widget.jobId}/escalate');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job escalated')),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escalation coming soon')),
        );
      }
    }
  }

  Future<void> _duplicate() async {
    try {
      await ApiService.instance.post('/jobs/${widget.jobId}/duplicate');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job duplicated')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duplicate coming soon')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'escalate') _escalate();
              if (v == 'duplicate') _duplicate();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'escalate',
                child: Row(
                  children: [
                    Icon(Icons.priority_high_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Escalate'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Duplicate'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.danger, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subtext)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      _buildHeader(t, subtext),
                      const SizedBox(height: 16),
                      _buildKpiRow(t),
                      const SizedBox(height: 16),
                      _buildSlaCountdown(t, subtext),
                      const SizedBox(height: 16),
                      _buildTaskProgress(t, subtext),
                      const SizedBox(height: 20),
                      _buildDescription(t, subtext),
                      const SizedBox(height: 20),
                      _buildRateInfo(t, subtext),
                      const SizedBox(height: 20),
                      _buildTasksList(t, subtext),
                      const SizedBox(height: 20),
                      _buildNotesSection(t, subtext),
                      const SizedBox(height: 20),
                      _buildActivityTimeline(t, subtext),
                    ],
                  ),
                ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeData t, Color subtext) {
    final status = _job?['status']?.toString() ?? 'DRAFT';
    final sla = _job?['slaStatus']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _job?['title']?.toString() ?? 'Untitled',
          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            StatusPill(
              label: status.replaceAll('_', ' '),
              color: _statusColor(status),
            ),
            if (sla != null)
              StatusPill(
                label: sla.replaceAll('_', ' '),
                color: _slaColor(sla),
                icon: _slaIcon(sla),
              ),
          ],
        ),
      ],
    );
  }

  // ── KPI Cards ─────────────────────────────────────────────────────────────
  Widget _buildKpiRow(ThemeData t) {
    final total = _tasks.length;
    final pending = _countTasksByStatus('PENDING');
    final inProgress = _countTasksByStatus('IN_PROGRESS');
    final completed = _countTasksByStatus('COMPLETED');
    final failed = _countTasksByStatus('FAILED') + _countTasksByStatus('CANCELLED');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _KpiCard(label: 'Total', value: '$total', color: AppColors.primary, t: t),
          const SizedBox(width: 8),
          _KpiCard(label: 'Pending', value: '$pending', color: AppColors.warn, t: t),
          const SizedBox(width: 8),
          _KpiCard(label: 'In Progress', value: '$inProgress', color: AppColors.primarySoft, t: t),
          const SizedBox(width: 8),
          _KpiCard(label: 'Completed', value: '$completed', color: AppColors.success, t: t),
          const SizedBox(width: 8),
          _KpiCard(label: 'Failed', value: '$failed', color: AppColors.danger, t: t),
        ],
      ),
    );
  }

  // ── SLA Countdown ─────────────────────────────────────────────────────────
  Widget _buildSlaCountdown(ThemeData t, Color subtext) {
    final slaMinutes = _job?['slaMinutes'] ?? _job?['sla'];
    if (slaMinutes == null) return const SizedBox.shrink();

    final totalMin = int.tryParse(slaMinutes.toString()) ?? 0;
    if (totalMin <= 0) return const SizedBox.shrink();

    // Calculate elapsed from createdAt
    DateTime? created;
    final createdRaw = _job?['createdAt'] ?? _job?['startedAt'];
    if (createdRaw != null) {
      created = DateTime.tryParse(createdRaw.toString());
    }

    final elapsed = created != null
        ? DateTime.now().difference(created).inMinutes
        : 0;
    final remaining = (totalMin - elapsed).clamp(0, totalMin);
    final progress = totalMin > 0 ? (remaining / totalMin).clamp(0.0, 1.0) : 0.0;

    final hours = remaining ~/ 60;
    final mins = remaining % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m remaining' : '${mins}m remaining';

    final slaColor = progress > 0.5
        ? AppColors.success
        : progress > 0.2
            ? AppColors.warn
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_rounded, size: 16, color: slaColor),
              const SizedBox(width: 6),
              const Text('SLA Countdown',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Text(
                remaining > 0 ? timeStr : 'Breached',
                style: TextStyle(
                  color: slaColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: t.dividerColor,
              color: slaColor,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Task Progress Bar ─────────────────────────────────────────────────────
  Widget _buildTaskProgress(ThemeData t, Color subtext) {
    if (_tasks.isEmpty) return const SizedBox.shrink();

    final total = _tasks.length;
    final completed = _countTasksByStatus('COMPLETED');
    final pct = total > 0 ? completed / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 16, color: subtext),
              const SizedBox(width: 6),
              const Text('Task Progress',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Text(
                '${(pct * 100).round()}% ($completed/$total)',
                style: TextStyle(
                  color: subtext,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: t.dividerColor,
              color: pct >= 1.0 ? AppColors.success : AppColors.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ── Description ───────────────────────────────────────────────────────────
  Widget _buildDescription(ThemeData t, Color subtext) {
    final desc = _job?['description']?.toString();
    if (desc == null || desc.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Description'),
        const SizedBox(height: 8),
        Text(desc, style: t.textTheme.bodyMedium?.copyWith(height: 1.5)),
      ],
    );
  }

  // ── Rate Info ─────────────────────────────────────────────────────────────
  Widget _buildRateInfo(ThemeData t, Color subtext) {
    final rateType = _job?['rateType']?.toString();
    final rateAmount = _job?['rateAmount'] ?? _job?['rate'];
    if (rateType == null && rateAmount == null) return const SizedBox.shrink();

    final currency = _job?['currency']?.toString() ?? 'KES';
    final money = NumberFormat.currency(symbol: '$currency ', decimalDigits: 0);
    double? amount;
    if (rateAmount != null) {
      if (rateAmount is num) {
        amount = rateAmount.toDouble();
      } else {
        amount = double.tryParse(rateAmount.toString());
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Text(
            amount != null ? money.format(amount) : '--',
            style: const TextStyle(
                color: AppColors.success, fontWeight: FontWeight.w700),
          ),
          if (rateType != null) ...[
            const SizedBox(width: 8),
            StatusPill(
              label: rateType.replaceAll('_', ' '),
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }

  // ── Tasks List ────────────────────────────────────────────────────────────
  Widget _buildTasksList(ThemeData t, Color subtext) {
    const taskStatuses = [
      'PENDING',
      'ASSIGNED',
      'IN_PROGRESS',
      'UNDER_REVIEW',
      'ON_HOLD',
      'COMPLETED',
      'FAILED',
      'CANCELLED',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Tasks (${_tasks.length})',
        ),
        const SizedBox(height: 8),
        if (_tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Center(
              child: Text(
                'No tasks yet',
                style: TextStyle(color: subtext, fontSize: 13),
              ),
            ),
          )
        else
          ...List.generate(_tasks.length, (i) {
            final task = _tasks[i];
            final taskId = task['id']?.toString() ?? '';
            final title = task['title']?.toString() ?? 'Untitled';
            final status = task['status']?.toString() ?? 'PENDING';
            final priority = task['priority']?.toString();
            final agentId = task['assignedAgentId']?.toString();

            // Try to get agent name
            String? agentName;
            if (task['agent'] is Map) {
              final a = task['agent'] as Map;
              agentName = a['name']?.toString() ??
                  a['firstName']?.toString() ??
                  a['fullName']?.toString();
            }

            return Container(
              margin: EdgeInsets.only(top: i == 0 ? 0 : 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (priority != null) ...[
                        const SizedBox(width: 6),
                        StatusPill(
                          label: priority,
                          color: _priorityColor(priority),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Status dropdown
                      Expanded(
                        child: _MiniDropdown(
                          value: status,
                          items: taskStatuses,
                          icon: Icons.flag_rounded,
                          color: _statusColor(status),
                          onChanged: (v) {
                            if (v != null && v != status) {
                              _updateTaskStatus(taskId, v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Agent dropdown
                      Expanded(
                        child: _agents.isEmpty
                            ? Row(
                                children: [
                                  Icon(Icons.person_outline_rounded,
                                      size: 14, color: subtext),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      agentName ?? 'Unassigned',
                                      style: TextStyle(
                                        color: subtext,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : _AgentDropdown(
                                selectedAgentId: agentId,
                                agentName: agentName,
                                agents: _agents,
                                onChanged: (id) {
                                  if (id != null) {
                                    _updateTaskAgent(taskId, id);
                                  }
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Notes Section ─────────────────────────────────────────────────────────
  Widget _buildNotesSection(ThemeData t, Color subtext) {
    final df = DateFormat('MMM d, HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Notes'),
        const SizedBox(height: 8),
        // Add note input
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  hintText: 'Add a note...',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: (_) => _addNote(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _addingNote ? null : _addNote,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _addingNote
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
        if (_notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...List.generate(_notes.length, (i) {
            final note = _notes[i];
            final content = note['content']?.toString() ??
                note['text']?.toString() ??
                '';
            final author = note['author']?.toString() ??
                note['createdBy']?.toString();
            DateTime? at;
            final rawAt = note['createdAt'] ?? note['timestamp'];
            if (rawAt != null) at = DateTime.tryParse(rawAt.toString());

            return Container(
              margin: EdgeInsets.only(top: i == 0 ? 0 : 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(content,
                      style:
                          t.textTheme.bodySmall?.copyWith(height: 1.4)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (author != null) ...[
                        Icon(Icons.person_outline_rounded,
                            size: 12, color: subtext),
                        const SizedBox(width: 3),
                        Text(author,
                            style: TextStyle(
                                color: subtext, fontSize: 11)),
                        const SizedBox(width: 8),
                      ],
                      if (at != null) ...[
                        Icon(Icons.schedule_rounded,
                            size: 12, color: subtext),
                        const SizedBox(width: 3),
                        Text(df.format(at),
                            style: TextStyle(
                                color: subtext, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  // ── Activity Timeline ─────────────────────────────────────────────────────
  Widget _buildActivityTimeline(ThemeData t, Color subtext) {
    if (_activity.isEmpty) return const SizedBox.shrink();

    final df = DateFormat('MMM d, HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Activity'),
        const SizedBox(height: 8),
        ...List.generate(_activity.length, (i) {
          final event = _activity[i];
          final action = event['action']?.toString() ??
              event['type']?.toString() ??
              event['event']?.toString() ??
              '';
          final desc = event['description']?.toString() ??
              event['message']?.toString() ??
              action;
          final actor = event['actor']?.toString() ??
              event['user']?.toString() ??
              event['performedBy']?.toString();
          DateTime? at;
          final rawAt =
              event['createdAt'] ?? event['timestamp'] ?? event['at'];
          if (rawAt != null) at = DateTime.tryParse(rawAt.toString());

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: i == 0
                          ? AppColors.primary
                          : subtext.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i < _activity.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: subtext.withValues(alpha: 0.2),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              i == 0 ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (actor != null) ...[
                            Text(actor,
                                style: TextStyle(
                                    color: subtext, fontSize: 11)),
                            const SizedBox(width: 6),
                          ],
                          if (at != null)
                            Text(df.format(at),
                                style: TextStyle(
                                    color: subtext, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ── Color helpers ─────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return AppColors.lightSubtext;
      case 'PUBLISHED':
        return AppColors.primary;
      case 'IN_PROGRESS':
      case 'ASSIGNED':
        return AppColors.primarySoft;
      case 'UNDER_REVIEW':
      case 'ON_HOLD':
        return AppColors.warn;
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
      case 'FAILED':
        return AppColors.danger;
      default:
        return AppColors.warn;
    }
  }

  Color _slaColor(String sla) {
    switch (sla.toUpperCase()) {
      case 'ON_TRACK':
        return AppColors.success;
      case 'AT_RISK':
        return AppColors.warn;
      case 'BREACHED':
        return AppColors.danger;
      default:
        return AppColors.lightSubtext;
    }
  }

  IconData _slaIcon(String sla) {
    switch (sla.toUpperCase()) {
      case 'ON_TRACK':
        return Icons.check_circle_outline;
      case 'AT_RISK':
        return Icons.warning_amber_rounded;
      case 'BREACHED':
        return Icons.error_outline;
      default:
        return Icons.schedule_rounded;
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

// ─── KPI Card ───────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final ThemeData t;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: t.brightness == Brightness.dark
                  ? AppColors.darkSubtext
                  : AppColors.lightSubtext,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Mini Status Dropdown ───────────────────────────────────────────────────

class _MiniDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final Color color;
  final ValueChanged<String?> onChanged;
  const _MiniDropdown({
    required this.value,
    required this.items,
    required this.icon,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, size: 16, color: color),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          dropdownColor: t.cardColor,
          items: items
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.replaceAll('_', ' '),
                      style: TextStyle(fontSize: 12, color: t.colorScheme.onSurface),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Agent Dropdown ─────────────────────────────────────────────────────────

class _AgentDropdown extends StatelessWidget {
  final String? selectedAgentId;
  final String? agentName;
  final List<Map<String, dynamic>> agents;
  final ValueChanged<String?> onChanged;
  const _AgentDropdown({
    required this.selectedAgentId,
    required this.agentName,
    required this.agents,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.dividerColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedAgentId != null &&
                  agents.any((a) => a['id']?.toString() == selectedAgentId)
              ? selectedAgentId
              : null,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 14, color: subtext),
              const SizedBox(width: 4),
              Text(
                agentName ?? 'Assign',
                style: TextStyle(fontSize: 12, color: subtext),
              ),
            ],
          ),
          icon: Icon(Icons.expand_more_rounded, size: 16, color: subtext),
          style: TextStyle(fontSize: 12, color: t.colorScheme.onSurface),
          dropdownColor: t.cardColor,
          items: agents.map((a) {
            final id = a['id']?.toString() ?? '';
            final name = a['name']?.toString() ??
                a['firstName']?.toString() ??
                a['fullName']?.toString() ??
                'Agent';
            return DropdownMenuItem(value: id, child: Text(name));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
