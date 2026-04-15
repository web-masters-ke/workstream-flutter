import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
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
      // Fetch agents + tasks in parallel for dashboard metrics
      final results = await Future.wait([
        ApiService.instance.get('/agents', query: {'limit': '1'}),
        ApiService.instance.get('/tasks', query: {'limit': '1'}),
        ApiService.instance
            .get('/tasks', query: {'status': 'COMPLETED', 'limit': '1'}),
        ApiService.instance
            .get('/tasks', query: {'status': 'PENDING', 'limit': '1'}),
      ]);

      int extractTotal(dynamic r) {
        final d = unwrap<dynamic>(r);
        if (d is Map) {
          return (d['total'] ?? d['count'] ?? 0) as int;
        }
        if (d is List) return d.length;
        return 0;
      }

      setState(() {
        _stats = {
          'agents': extractTotal(results[0]),
          'totalTasks': extractTotal(results[1]),
          'completedTasks': extractTotal(results[2]),
          'pendingTasks': extractTotal(results[3]),
        };
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
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
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
                          style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // ── Greeting ───────────────────────────────
                      Text(
                        'Overview',
                        style: t.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live workspace metrics',
                        style: TextStyle(color: subtext, fontSize: 13),
                      ),
                      const SizedBox(height: 24),

                      // ── Stat cards ─────────────────────────────
                      _statsGrid(context),
                      const SizedBox(height: 28),

                      // ── Task completion ────────────────────────
                      _completionCard(context, subtext),
                    ],
                  ),
                ),
    );
  }

  Widget _statsGrid(BuildContext context) {
    final total = _stats?['totalTasks'] ?? 0;
    final completed = _stats?['completedTasks'] ?? 0;
    final pending = _stats?['pendingTasks'] ?? 0;
    final agents = _stats?['agents'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _StatCard(
          label: 'Agents',
          value: '$agents',
          icon: Icons.groups_rounded,
          color: AppColors.accent,
        ),
        _StatCard(
          label: 'Total Tasks',
          value: '$total',
          icon: Icons.assignment_rounded,
          color: AppColors.primary,
        ),
        _StatCard(
          label: 'Completed',
          value: '$completed',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        ),
        _StatCard(
          label: 'Pending',
          value: '$pending',
          icon: Icons.pending_rounded,
          color: AppColors.warn,
        ),
      ],
    );
  }

  Widget _completionCard(BuildContext context, Color subtext) {
    final t = Theme.of(context);
    final total = (_stats?['totalTasks'] ?? 0) as int;
    final completed = (_stats?['completedTasks'] ?? 0) as int;
    final rate = total > 0 ? completed / total : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Completion Rate',
              style: t.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: rate,
                      minHeight: 10,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$completed of $total tasks completed',
              style: TextStyle(color: subtext, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(label,
                    style: TextStyle(color: subtext, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
