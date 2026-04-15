import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<_Job> _jobs = [];
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
      final resp = await ApiService.instance.get('/jobs');
      final raw = unwrap<dynamic>(resp);
      final list = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['jobs'] ?? []) : []);
      _jobs = (list as List).map((e) => _Job.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), '');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
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
                        Text(_error!, textAlign: TextAlign.center,
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
              : _jobs.isEmpty
                  ? const EmptyState(
                      icon: Icons.work_outline_rounded,
                      title: 'No jobs yet',
                      message:
                          'Internal jobs posted by your business will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _jobs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _JobCard(job: _jobs[i], subtext: subtext),
                      ),
                    ),
    );
  }
}

// ─── Job Card ────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final _Job job;
  final Color subtext;
  const _JobCard({required this.job, required this.subtext});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final statusColor = _statusColor(job.status);
    final df = DateFormat('MMM d, yyyy');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetail(context),
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
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.work_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (job.assignedAgent != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Assigned: ${job.assignedAgent}',
                          style: TextStyle(color: subtext, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(label: job.status, color: statusColor),
              ],
            ),
            if (job.dueAt != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 14, color: subtext),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${df.format(job.dueAt!)}',
                    style: TextStyle(color: subtext, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'IN_PROGRESS':
        return AppColors.primary;
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      case 'PENDING':
      default:
        return AppColors.warn;
    }
  }

  void _showDetail(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final df = DateFormat('MMM d, yyyy');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(job.title,
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _detailRow('Status', job.status, subtext, t),
            if (job.assignedAgent != null)
              _detailRow('Assigned to', job.assignedAgent!, subtext, t),
            if (job.dueAt != null)
              _detailRow(
                  'Due date', df.format(job.dueAt!), subtext, t),
            if (job.description != null && job.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Description',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: subtext,
                      fontSize: 13)),
              const SizedBox(height: 4),
              Text(job.description!,
                  style: t.textTheme.bodyMedium?.copyWith(height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      String label, String value, Color subtext, ThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: subtext, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Model ───────────────────────────────────────────────────────────────────

class _Job {
  final String id;
  final String title;
  final String status;
  final String? assignedAgent;
  final DateTime? dueAt;
  final String? description;

  const _Job({
    required this.id,
    required this.title,
    required this.status,
    this.assignedAgent,
    this.dueAt,
    this.description,
  });

  factory _Job.fromJson(Map<String, dynamic> j) {
    final agent = j['assignedAgent'] ?? j['agent'];
    String? agentName;
    if (agent is Map) {
      agentName = agent['name']?.toString() ??
          agent['fullName']?.toString() ??
          agent['firstName']?.toString();
    } else if (agent is String) {
      agentName = agent;
    }

    DateTime? due;
    final dueRaw = j['dueAt'] ?? j['dueDate'] ?? j['deadline'];
    if (dueRaw != null) {
      due = DateTime.tryParse(dueRaw.toString());
    }

    return _Job(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Untitled',
      status: j['status']?.toString() ?? 'PENDING',
      assignedAgent: agentName,
      dueAt: due,
      description: j['description']?.toString(),
    );
  }
}
