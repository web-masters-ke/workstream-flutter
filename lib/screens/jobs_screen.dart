import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'job_detail_screen.dart';
import 'new_job_screen.dart';

// ─── Job Model ──────────────────────────────────────────────────────────────

class Job {
  final String id;
  final String title;
  final String status;
  final String? slaStatus;
  final String? priority;
  final String? description;
  final bool isTemplate;
  final int tasksTotal;
  final int tasksCompleted;
  final double? costEstimate;
  final String currency;
  final DateTime? dueAt;
  final List<String> tags;
  final String? assignedAgent;

  const Job({
    required this.id,
    required this.title,
    required this.status,
    this.slaStatus,
    this.priority,
    this.description,
    this.isTemplate = false,
    this.tasksTotal = 0,
    this.tasksCompleted = 0,
    this.costEstimate,
    this.currency = 'KES',
    this.dueAt,
    this.tags = const [],
    this.assignedAgent,
  });

  factory Job.fromJson(Map<String, dynamic> j) {
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

    // Parse tasks progress
    final taskCounts = j['taskCounts'] ?? j['tasks'];
    int total = 0;
    int completed = 0;
    if (taskCounts is Map) {
      total = _toInt(taskCounts['total'] ?? taskCounts['count']);
      completed = _toInt(taskCounts['completed'] ?? taskCounts['done']);
    } else {
      total = _toInt(j['tasksTotal'] ?? j['taskCount']);
      completed = _toInt(j['tasksCompleted'] ?? j['tasksDone']);
    }

    return Job(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Untitled',
      status: j['status']?.toString() ?? 'DRAFT',
      slaStatus: j['slaStatus']?.toString(),
      priority: j['priority']?.toString(),
      description: j['description']?.toString(),
      isTemplate: j['isTemplate'] == true || j['template'] == true,
      tasksTotal: total,
      tasksCompleted: completed,
      costEstimate: _toDoubleOrNull(j['costEstimate'] ?? j['estimatedCost'] ?? j['budget']),
      currency: j['currency']?.toString() ?? 'KES',
      dueAt: due,
      tags: j['tags'] is List
          ? (j['tags'] as List).map((e) => e.toString()).toList()
          : const [],
      assignedAgent: agentName,
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

// ─── Jobs Screen ────────────────────────────────────────────────────────────

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<Job> _jobs = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _slaFilter = 'ALL';
  final _searchCtrl = TextEditingController();

  static const _statuses = [
    'ALL',
    'DRAFT',
    'PUBLISHED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED',
    'ARCHIVED',
  ];
  static const _slaStatuses = ['ALL', 'ON_TRACK', 'AT_RISK', 'BREACHED'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, dynamic>{'limit': '100'};
      if (_statusFilter != 'ALL') query['status'] = _statusFilter;
      if (_slaFilter != 'ALL') query['slaStatus'] = _slaFilter;
      if (_searchQuery.isNotEmpty) query['search'] = _searchQuery;

      final resp = await ApiService.instance.get('/jobs', query: query);
      final raw = unwrap<dynamic>(resp);
      final list = raw is List
          ? raw
          : (raw is Map
              ? (raw['items'] ?? raw['jobs'] ?? [])
              : []);
      _jobs = (list as List)
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .toList();
    } catch (e) {
      _error = e.toString().replaceFirst(
          RegExp(r'^ApiException\(\d+\):\s*'), '');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Job> get _filtered {
    if (_searchQuery.isEmpty) return _jobs;
    final q = _searchQuery.toLowerCase();
    return _jobs.where((j) {
      return j.title.toLowerCase().contains(q) ||
          (j.description?.toLowerCase().contains(q) ?? false) ||
          j.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final filtered = _filtered;

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
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextFormField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                prefixIcon:
                    Icon(Icons.search_rounded, size: 20, color: subtext),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _load();
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              onFieldSubmitted: (_) => _load(),
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(height: 8),

          // ── Status filter chips ────────────────────────────
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final active = _statusFilter == s;
                return FilterChip(
                  label: Text(s.replaceAll('_', ' ')),
                  selected: active,
                  onSelected: (_) {
                    setState(() => _statusFilter = s);
                    _load();
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                    color: active ? AppColors.primary : subtext,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // ── SLA filter chips ───────────────────────────────
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _slaStatuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _slaStatuses[i];
                final active = _slaFilter == s;
                return FilterChip(
                  label: Text(
                    s == 'ALL' ? 'Any SLA' : s.replaceAll('_', ' '),
                  ),
                  selected: active,
                  onSelected: (_) {
                    setState(() => _slaFilter = s);
                    _load();
                  },
                  selectedColor: _slaChipColor(s).withValues(alpha: 0.18),
                  checkmarkColor: _slaChipColor(s),
                  labelStyle: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                    color: active ? _slaChipColor(s) : subtext,
                  ),
                );
              },
            ),
          ),

          // ── Result count ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtered.length} job${filtered.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: subtext,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ── Job list ───────────────────────────────────────
          Expanded(
            child: _loading
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
                    : filtered.isEmpty
                        ? const EmptyState(
                            icon: Icons.work_outline_rounded,
                            title: 'No jobs found',
                            message:
                                'Try adjusting your filters or create a new job.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _JobCard(
                                job: filtered[i],
                                subtext: subtext,
                                onTap: () => _openDetail(filtered[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const NewJobScreen()),
          );
          if (created == true) _load();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New job',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _openDetail(Job job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(jobId: job.id),
      ),
    );
  }

  Color _slaChipColor(String s) {
    switch (s) {
      case 'ON_TRACK':
        return AppColors.success;
      case 'AT_RISK':
        return AppColors.warn;
      case 'BREACHED':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }
}

// ─── Job Card ───────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final Job job;
  final Color subtext;
  final VoidCallback onTap;
  const _JobCard({
    required this.job,
    required this.subtext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final df = DateFormat('MMM d, yyyy');
    final money = NumberFormat.currency(
      symbol: '${job.currency} ',
      decimalDigits: 0,
    );
    final progress = job.tasksTotal > 0
        ? job.tasksCompleted / job.tasksTotal
        : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
            // ── Row 1: icon + title + badges ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              job.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (job.isTemplate) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Template',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Badges row
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          StatusPill(
                            label: job.status.replaceAll('_', ' '),
                            color: _statusColor(job.status),
                          ),
                          if (job.slaStatus != null)
                            StatusPill(
                              label: job.slaStatus!.replaceAll('_', ' '),
                              color: _slaColor(job.slaStatus!),
                              icon: _slaIcon(job.slaStatus!),
                            ),
                          if (job.priority != null)
                            StatusPill(
                              label: job.priority!,
                              color: _priorityColor(job.priority!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Row 2: tasks progress bar ─────────────────────
            if (job.tasksTotal > 0) ...[
              Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 14, color: subtext),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: t.dividerColor,
                        color: progress >= 1.0
                            ? AppColors.success
                            : AppColors.primary,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${job.tasksCompleted}/${job.tasksTotal}',
                    style: TextStyle(
                      color: subtext,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // ── Row 3: cost + due date + tags ─────────────────
            Row(
              children: [
                if (job.costEstimate != null) ...[
                  Icon(Icons.payments_outlined, size: 14, color: subtext),
                  const SizedBox(width: 4),
                  Text(
                    money.format(job.costEstimate),
                    style: TextStyle(
                      color: subtext,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (job.dueAt != null) ...[
                  Icon(Icons.schedule_rounded, size: 14, color: subtext),
                  const SizedBox(width: 4),
                  Text(
                    'Due ${df.format(job.dueAt!)}',
                    style: TextStyle(color: subtext, fontSize: 12),
                  ),
                ],
                const Spacer(),
                if (job.tags.isNotEmpty)
                  ...job.tags.take(2).map(
                        (tag) => Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: t.dividerColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                color: subtext,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                if (job.tags.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '+${job.tags.length - 2}',
                      style: TextStyle(
                        fontSize: 10,
                        color: subtext,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return AppColors.lightSubtext;
      case 'PUBLISHED':
        return AppColors.primary;
      case 'IN_PROGRESS':
        return AppColors.primarySoft;
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      case 'ARCHIVED':
        return AppColors.darkSubtext;
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
