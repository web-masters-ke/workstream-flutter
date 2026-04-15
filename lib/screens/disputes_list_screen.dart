import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class _Escalation {
  final String id;
  final String subject;
  final String reason;
  final String category;
  final String taskTitle;
  final String taskId;
  final String severity;
  final String status;
  final String raisedBy;
  final String assignedTo;
  final String? slaRemaining;
  final String? businessImpact;
  final String? evidence;
  final DateTime createdAt;

  const _Escalation({
    required this.id,
    required this.subject,
    required this.reason,
    required this.category,
    required this.taskTitle,
    required this.taskId,
    required this.severity,
    required this.status,
    required this.raisedBy,
    required this.assignedTo,
    this.slaRemaining,
    this.businessImpact,
    this.evidence,
    required this.createdAt,
  });

  factory _Escalation.fromJson(Map<String, dynamic> j) {
    final task = j['task'];
    String taskTitle = j['taskTitle']?.toString() ?? '';
    String taskId = j['taskId']?.toString() ?? '';
    if (task is Map) {
      taskTitle = task['title']?.toString() ?? taskTitle;
      taskId = task['id']?.toString() ?? taskId;
    }

    String nameOf(dynamic v) {
      if (v is Map) {
        final first = v['firstName']?.toString() ?? '';
        final last = v['lastName']?.toString() ?? '';
        return '$first $last'.trim();
      }
      return v?.toString() ?? '';
    }

    DateTime created = DateTime.now();
    final raw = j['createdAt'] ?? j['created_at'] ?? j['raisedAt'];
    if (raw != null) created = DateTime.tryParse(raw.toString()) ?? created;

    return _Escalation(
      id: j['id']?.toString() ?? '',
      subject: j['subject']?.toString() ?? j['title']?.toString() ?? 'Escalation',
      reason: j['reason']?.toString() ?? '',
      category: j['category']?.toString() ?? 'OTHER',
      taskTitle: taskTitle.isNotEmpty ? taskTitle : 'Unknown task',
      taskId: taskId,
      severity: j['severity']?.toString() ?? j['priority']?.toString() ?? 'MEDIUM',
      status: j['status']?.toString() ?? 'OPEN',
      raisedBy: nameOf(j['raisedBy'] ?? j['raisedByUser'] ?? j['createdBy']),
      assignedTo: nameOf(j['assignedTo'] ?? j['assignedToUser'] ?? j['supervisor']),
      slaRemaining: j['slaRemaining']?.toString(),
      businessImpact: j['businessImpact']?.toString(),
      evidence: j['evidence']?.toString() ?? j['context']?.toString(),
      createdAt: created,
    );
  }
}

class _TaskOption {
  final String id;
  final String title;
  const _TaskOption({required this.id, required this.title});
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class DisputesListScreen extends StatefulWidget {
  const DisputesListScreen({super.key});

  @override
  State<DisputesListScreen> createState() => _DisputesListScreenState();
}

class _DisputesListScreenState extends State<DisputesListScreen> {
  List<_Escalation> _escalations = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'All';
  String _priorityFilter = 'All';

  static const _statusFilters = [
    'All', 'Open', 'In Review', 'Resolved', 'Dismissed'
  ];
  static const _priorityFilters = [
    'All', 'Low', 'Medium', 'High', 'Urgent'
  ];

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
      // Try /admin/disputes first, then /escalations, then /tasks?status=ON_HOLD
      Map<String, dynamic> resp;
      try {
        resp = await ApiService.instance.get('/admin/disputes');
      } catch (_) {
        try {
          resp = await ApiService.instance.get('/escalations');
        } catch (_) {
          resp = await ApiService.instance.get('/tasks', query: {'status': 'ON_HOLD'});
        }
      }
      final raw = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['items'] is List) {
        list = raw['items'] as List;
      } else if (raw is Map && raw['escalations'] is List) {
        list = raw['escalations'] as List;
      } else if (raw is Map && raw['disputes'] is List) {
        list = raw['disputes'] as List;
      } else {
        list = [];
      }
      _escalations = list
          .whereType<Map<String, dynamic>>()
          .map(_Escalation.fromJson)
          .toList();
    } catch (e) {
      _error = cleanError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_Escalation> get _filtered {
    var result = _escalations;

    if (_statusFilter != 'All') {
      final target = _statusFilter.toUpperCase().replaceAll(' ', '_');
      result = result
          .where((e) => e.status.toUpperCase() == target)
          .toList();
    }

    if (_priorityFilter != 'All') {
      final target = _priorityFilter.toUpperCase();
      result = result
          .where((e) => e.severity.toUpperCase() == target)
          .toList();
    }

    return result;
  }

  // Stats
  int get _openCount =>
      _escalations.where((e) => e.status.toUpperCase() == 'OPEN').length;
  int get _resolvedCount =>
      _escalations.where((e) => e.status.toUpperCase() == 'RESOLVED').length;
  int get _overdueCount => _escalations
      .where((e) =>
          e.status.toUpperCase() == 'OPEN' &&
          e.slaRemaining != null &&
          e.slaRemaining!.startsWith('-'))
      .length;

  Widget _miniStat(String label, int count, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'RESOLVED':
        return AppColors.success;
      case 'DISMISSED':
      case 'REJECTED':
        return AppColors.danger;
      case 'IN_REVIEW':
      case 'UNDER_REVIEW':
        return AppColors.primary;
      default:
        return AppColors.warn;
    }
  }

  Color _severityColor(String s) {
    switch (s.toUpperCase()) {
      case 'URGENT':
        return AppColors.danger;
      case 'HIGH':
        return const Color(0xFFEA580C); // orange-600
      case 'LOW':
        return AppColors.lightSubtext;
      default: // MEDIUM
        return AppColors.warn;
    }
  }

  void _showRaiseEscalation() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RaiseEscalationSheet(onRaised: _load),
    );
  }

  void _showDetail(_Escalation esc) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EscalationDetailSheet(
        escalation: esc,
        statusColor: _statusColor,
        severityColor: _severityColor,
        onAction: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escalations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Raise escalation',
            onPressed: _showRaiseEscalation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2.5))
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
                            child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // ── Stats row — compact inline ──
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        child: Row(
                          children: [
                            _miniStat('Open', _openCount, AppColors.warn),
                            _miniStat('Resolved', _resolvedCount, AppColors.success),
                            _miniStat('Overdue', _overdueCount, AppColors.danger),
                            _miniStat('Total', _escalations.length, AppColors.primary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Filters — single scrollable row ──
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ..._statusFilters.map((f) {
                              final active = f == _statusFilter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () => setState(() => _statusFilter = f),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: active ? AppColors.primary : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: active ? AppColors.primary : t.dividerColor),
                                    ),
                                    child: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : subtext)),
                                  ),
                                ),
                              );
                            }),
                            Container(width: 1, height: 24, color: t.dividerColor, margin: const EdgeInsets.symmetric(horizontal: 4)),
                            ..._priorityFilters.map((f) {
                              final active = f == _priorityFilter;
                              final col = _severityColor(f);
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () => setState(() => _priorityFilter = f),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: active ? col.withValues(alpha: 0.18) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: active ? col : t.dividerColor),
                                    ),
                                    child: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? col : subtext)),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Escalation list ──
                      if (filtered.isEmpty)
                        const EmptyState(
                          icon: Icons.gavel_rounded,
                          title: 'No escalations',
                          message:
                              'Disputes and escalations will appear here.',
                        )
                      else
                        ...filtered.map((esc) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10),
                              child: _EscalationTile(
                                escalation: esc,
                                subtext: subtext,
                                statusColor: _statusColor,
                                severityColor: _severityColor,
                                onTap: () => _showDetail(esc),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}

// ─── Escalation Tile ─────────────────────────────────────────────────────────

class _EscalationTile extends StatelessWidget {
  final _Escalation escalation;
  final Color subtext;
  final Color Function(String) statusColor;
  final Color Function(String) severityColor;
  final VoidCallback onTap;

  const _EscalationTile({
    required this.escalation,
    required this.subtext,
    required this.statusColor,
    required this.severityColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sColor = statusColor(escalation.status);
    final sevColor = severityColor(escalation.severity);
    final df = DateFormat('MMM d, yyyy');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: sColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.gavel_rounded,
                      color: sColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        escalation.subject,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        escalation.taskTitle,
                        style: TextStyle(
                            color: subtext, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                    label: escalation.status, color: sColor),
              ],
            ),
            const SizedBox(height: 10),

            // Reason
            if (escalation.reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  escalation.reason,
                  style: TextStyle(color: subtext, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Meta row
            Row(
              children: [
                // Severity badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    escalation.severity,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sevColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Category
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color:
                        AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    escalation.category.replaceAll('_', ' '),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                // SLA remaining
                if (escalation.slaRemaining != null) ...[
                  Icon(Icons.timer_rounded,
                      size: 12, color: subtext),
                  const SizedBox(width: 3),
                  Text(
                    escalation.slaRemaining!,
                    style: TextStyle(fontSize: 11, color: subtext),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.schedule_rounded,
                    size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  df.format(escalation.createdAt),
                  style: TextStyle(fontSize: 11, color: subtext),
                ),
              ],
            ),

            // Raised by / Assigned to
            if (escalation.raisedBy.isNotEmpty ||
                escalation.assignedTo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (escalation.raisedBy.isNotEmpty) ...[
                    Icon(Icons.person_outline_rounded,
                        size: 12, color: subtext),
                    const SizedBox(width: 3),
                    Text(
                      escalation.raisedBy,
                      style: TextStyle(
                          fontSize: 11, color: subtext),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (escalation.assignedTo.isNotEmpty) ...[
                    Icon(Icons.assignment_ind_outlined,
                        size: 12, color: subtext),
                    const SizedBox(width: 3),
                    Text(
                      escalation.assignedTo,
                      style: TextStyle(
                          fontSize: 11, color: subtext),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Escalation Detail Bottom Sheet ──────────────────────────────────────────

class _EscalationDetailSheet extends StatefulWidget {
  final _Escalation escalation;
  final Color Function(String) statusColor;
  final Color Function(String) severityColor;
  final VoidCallback onAction;

  const _EscalationDetailSheet({
    required this.escalation,
    required this.statusColor,
    required this.severityColor,
    required this.onAction,
  });

  @override
  State<_EscalationDetailSheet> createState() =>
      _EscalationDetailSheetState();
}

class _EscalationDetailSheetState
    extends State<_EscalationDetailSheet> {
  bool _busy = false;

  Future<void> _transition(String newStatus) async {
    setState(() => _busy = true);
    try {
      await ApiService.instance.patch(
        '/tasks/${widget.escalation.taskId}/transition',
        body: {'status': newStatus},
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAction();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Escalation moved to $newStatus'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${cleanError(e)}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final esc = widget.escalation;
    final sColor = widget.statusColor(esc.status);
    final sevColor = widget.severityColor(esc.severity);
    final df = DateFormat('MMM d, yyyy HH:mm');

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.paddingOf(context).bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: t.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title + status
            Row(
              children: [
                Expanded(
                  child: Text(esc.subject,
                      style: t.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                StatusPill(label: esc.status, color: sColor),
              ],
            ),
            const SizedBox(height: 12),

            // Badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusPill(label: esc.severity, color: sevColor),
                StatusPill(
                  label: esc.category.replaceAll('_', ' '),
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Detail rows
            _detailRow('Task', esc.taskTitle, Icons.task_rounded, subtext),
            if (esc.reason.isNotEmpty)
              _detailRow('Reason', esc.reason, Icons.notes_rounded, subtext),
            if (esc.raisedBy.isNotEmpty)
              _detailRow(
                  'Raised by', esc.raisedBy, Icons.person_outline_rounded, subtext),
            if (esc.assignedTo.isNotEmpty)
              _detailRow(
                  'Assigned to', esc.assignedTo, Icons.assignment_ind_outlined, subtext),
            if (esc.slaRemaining != null)
              _detailRow(
                  'SLA remaining', esc.slaRemaining!, Icons.timer_rounded, subtext),
            if (esc.businessImpact != null && esc.businessImpact!.isNotEmpty)
              _detailRow('Business impact', esc.businessImpact!,
                  Icons.business_center_rounded, subtext),
            if (esc.evidence != null && esc.evidence!.isNotEmpty)
              _detailRow(
                  'Evidence/context', esc.evidence!, Icons.attach_file_rounded, subtext),
            _detailRow(
                'Created', df.format(esc.createdAt), Icons.schedule_rounded, subtext),
            const SizedBox(height: 20),

            // Action buttons
            if (esc.status.toUpperCase() == 'OPEN' ||
                esc.status.toUpperCase() == 'IN_REVIEW') ...[
              if (esc.status.toUpperCase() == 'OPEN')
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _transition('IN_REVIEW'),
                    icon: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.rate_review_rounded,
                            size: 18),
                    label: const Text('Mark In Review'),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _transition('RESOLVED'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 18),
                      label: const Text('Resolve'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _transition('DISMISSED'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side:
                            const BorderSide(color: AppColors.danger),
                      ),
                      icon: const Icon(Icons.cancel_rounded,
                          size: 18),
                      label: const Text('Dismiss'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      String label, String value, IconData icon, Color subtext) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: subtext),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: subtext,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─── Raise Escalation Bottom Sheet ───────────────────────────────────────────

class _RaiseEscalationSheet extends StatefulWidget {
  final VoidCallback onRaised;
  const _RaiseEscalationSheet({required this.onRaised});

  @override
  State<_RaiseEscalationSheet> createState() =>
      _RaiseEscalationSheetState();
}

class _RaiseEscalationSheetState
    extends State<_RaiseEscalationSheet> {
  final _formKey = GlobalKey<FormState>();
  List<_TaskOption> _tasks = [];
  String? _selectedTaskId;
  final _subjectCtrl = TextEditingController();
  String _category = 'OTHER';
  String _priority = 'MEDIUM';
  final _reasonCtrl = TextEditingController();
  final _impactCtrl = TextEditingController();
  final _evidenceCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  bool _busy = false;
  bool _loadingTasks = true;

  static const _categories = [
    'SLA_BREACH',
    'QUALITY',
    'PAYMENT',
    'AGENT_CONDUCT',
    'TECHNICAL',
    'CLIENT_COMPLAINT',
    'POLICY_VIOLATION',
    'OTHER',
  ];

  static const _priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _reasonCtrl.dispose();
    _impactCtrl.dispose();
    _evidenceCtrl.dispose();
    _hoursCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final resp = await ApiService.instance.get('/tasks');
      final raw = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['items'] is List) {
        list = raw['items'] as List;
      } else if (raw is Map && raw['tasks'] is List) {
        list = raw['tasks'] as List;
      } else {
        list = [];
      }
      _tasks = list
          .whereType<Map<String, dynamic>>()
          .map((j) => _TaskOption(
                id: j['id']?.toString() ?? '',
                title: j['title']?.toString() ?? 'Untitled',
              ))
          .toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingTasks = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTaskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a task'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.instance
          .post('/tasks/$_selectedTaskId/escalate', body: {
        'subject': _subjectCtrl.text.trim(),
        'category': _category,
        'priority': _priority,
        if (_reasonCtrl.text.trim().isNotEmpty)
          'reason': _reasonCtrl.text.trim(),
        if (_impactCtrl.text.trim().isNotEmpty)
          'businessImpact': _impactCtrl.text.trim(),
        if (_evidenceCtrl.text.trim().isNotEmpty)
          'evidence': _evidenceCtrl.text.trim(),
        if (_hoursCtrl.text.trim().isNotEmpty)
          'expectedResolutionHours':
              int.tryParse(_hoursCtrl.text.trim()),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onRaised();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Escalation raised'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${cleanError(e)}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.paddingOf(context).bottom +
              24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: t.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Raise escalation',
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),

              // Task
              const Text('Task *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              _loadingTasks
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        ),
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      initialValue: _selectedTaskId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon:
                            Icon(Icons.task_alt_rounded, size: 20),
                        hintText: 'Select a task',
                      ),
                      items: _tasks
                          .map((t) => DropdownMenuItem(
                              value: t.id,
                              child: Text(t.title,
                                  overflow:
                                      TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedTaskId = v),
                    ),
              const SizedBox(height: 14),

              // Subject
              const Text('Subject *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _subjectCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                decoration: const InputDecoration(
                  hintText: 'Brief subject line',
                ),
              ),
              const SizedBox(height: 14),

              // Category + Priority
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _category,
                          isExpanded: true,
                          items: _categories
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                      c.replaceAll('_', ' '),
                                      style: const TextStyle(
                                          fontSize: 12))))
                              .toList(),
                          onChanged: (v) => setState(
                              () => _category = v ?? 'OTHER'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Priority',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _priority,
                          isExpanded: true,
                          items: _priorities
                              .map((p) => DropdownMenuItem(
                                  value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) => setState(
                              () => _priority = v ?? 'MEDIUM'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Reason
              const Text('Detailed reason',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Explain what happened...',
                ),
              ),
              const SizedBox(height: 14),

              // Business impact
              const Text('Business impact',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _impactCtrl,
                decoration: const InputDecoration(
                  hintText: 'How does this affect the business?',
                ),
              ),
              const SizedBox(height: 14),

              // Evidence
              const Text('Evidence / context',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _evidenceCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText:
                      'Links, screenshots, references...',
                ),
              ),
              const SizedBox(height: 14),

              // Resolution hours
              const Text('Expected resolution (hours)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _hoursCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'e.g. 24',
                  prefixIcon:
                      Icon(Icons.timer_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 20),

              // Submit
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Raise escalation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
