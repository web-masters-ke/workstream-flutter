import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

/// Lists all disputes/escalations for the current user or business.
class DisputesListScreen extends StatefulWidget {
  const DisputesListScreen({super.key});

  @override
  State<DisputesListScreen> createState() => _DisputesListScreenState();
}

class _DisputesListScreenState extends State<DisputesListScreen> {
  List<_Dispute> _disputes = [];
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
      final resp = await ApiService.instance.get('/disputes');
      final raw = unwrap<dynamic>(resp);
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['items'] ?? raw['disputes'] ?? []) : []);
      _disputes =
          (list as List).map((e) => _Dispute.fromJson(e as Map<String, dynamic>)).toList();
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
        title: const Text('Escalations'),
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
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subtext)),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _disputes.isEmpty
                  ? const EmptyState(
                      icon: Icons.gavel_rounded,
                      title: 'No escalations',
                      message:
                          'Disputes and escalations will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _disputes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _DisputeTile(d: _disputes[i], subtext: subtext),
                      ),
                    ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _DisputeTile extends StatelessWidget {
  final _Dispute d;
  final Color subtext;
  const _DisputeTile({required this.d, required this.subtext});

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'RESOLVED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.danger;
      case 'IN_REVIEW':
      case 'UNDER_REVIEW':
        return AppColors.primary;
      default:
        return AppColors.warn;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final statusColor = _statusColor(d.status);
    final df = DateFormat('MMM d, yyyy');

    return Container(
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.gavel_rounded,
                    color: statusColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.taskTitle,
                      style:
                          const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.reason,
                      style: TextStyle(color: subtext, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: d.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: subtext),
              const SizedBox(width: 4),
              Text(
                df.format(d.createdAt),
                style: TextStyle(color: subtext, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _Dispute {
  final String id;
  final String taskTitle;
  final String reason;
  final String status;
  final DateTime createdAt;

  const _Dispute({
    required this.id,
    required this.taskTitle,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory _Dispute.fromJson(Map<String, dynamic> j) {
    final task = j['task'];
    String taskTitle = 'Unknown task';
    if (task is Map) {
      taskTitle = task['title']?.toString() ?? taskTitle;
    } else if (j['taskTitle'] != null) {
      taskTitle = j['taskTitle'].toString();
    }

    DateTime created = DateTime.now();
    final createdRaw = j['createdAt'] ?? j['created_at'] ?? j['raisedAt'];
    if (createdRaw != null) {
      created = DateTime.tryParse(createdRaw.toString()) ?? created;
    }

    return _Dispute(
      id: j['id']?.toString() ?? '',
      taskTitle: taskTitle,
      reason: j['reason']?.toString() ?? 'Dispute',
      status: j['status']?.toString() ?? 'PENDING',
      createdAt: created,
    );
  }
}
