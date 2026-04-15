import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'admin_tasks_screen.dart';
import 'admin_team_screen.dart';
import 'agents_manage_screen.dart';
import 'disputes_list_screen.dart';
import 'reports_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _data;
  List<dynamic> _activity = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final platform = unwrap<Map<String, dynamic>>(
        await ApiService.instance.get('/analytics/overview', query: {'period': '30d'}),
      );

      // Audit logs require ADMIN — gracefully skip for other roles
      List<dynamic> auditItems = [];
      try {
        final auditRaw = unwrap<dynamic>(
          await ApiService.instance.get('/admin/audit-logs', query: {'limit': '10'}),
        );
        auditItems = auditRaw is Map
            ? (auditRaw['items'] as List? ?? [])
            : (auditRaw is List ? auditRaw : []);
      } catch (_) { /* non-ADMIN users won't see audit logs */ }

      if (mounted) setState(() { _data = platform; _activity = auditItems; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst(RegExp(r'^[A-Za-z]+Exception\([^)]*\):\s*'), ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final user = context.watch<AuthController>().user;

    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: subtext)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _data ?? {};
    final totalUsers = _num(d['totalUsers'] ?? d['users']);
    final totalBiz = _num(d['totalBusinesses'] ?? d['businesses']);
    final totalAgents = _num(d['totalAgents'] ?? d['agents']);
    // tasks may be nested: { total, completed, open, completionRate }
    final tasksObj = d['tasks'] is Map ? d['tasks'] as Map : <String, dynamic>{};
    final activeTasks = _num(d['activeTasks'] ?? tasksObj['open'] ?? tasksObj['total']);
    final completedTasks = _num(d['completedTasks'] ?? tasksObj['completed']);
    final openDisputes = _num(d['openDisputes']);
    final pendingKyc = _num(d['pendingKyc']);
    final gmv = _dbl(d['gmv']);
    final revenue = _dbl(d['revenue']);

    // Task breakdown
    final tasksByStatus = d['tasksByStatus'] is List ? d['tasksByStatus'] as List : [];

    // Top agents
    final topAgents = d['topAgents'] is List ? d['topAgents'] as List : [];

    // Top businesses
    final topBiz = d['topBusinesses'] is List ? d['topBusinesses'] as List : [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Greeting ──────────────────────────────────────
          Text(
            'Welcome back${user?.firstName != null && user!.firstName.isNotEmpty ? ', ${user.firstName}' : ''}',
            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text('30-day workspace overview', style: TextStyle(color: subtext, fontSize: 13)),
          const SizedBox(height: 20),

          // ── KPI Cards ─────────────────────────────────────
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _KpiCard(label: 'Users', value: '$totalUsers', icon: Icons.people_rounded, color: AppColors.primary,
                onTap: () => _push(context, const AdminTeamScreen())),
              _KpiCard(label: 'Businesses', value: '$totalBiz', icon: Icons.business_rounded, color: AppColors.primarySoft,
                onTap: () => _push(context, const ReportsScreen())),
              _KpiCard(label: 'Agents', value: '$totalAgents', icon: Icons.groups_rounded, color: AppColors.success,
                onTap: () => _push(context, const AgentsManageScreen())),
              _KpiCard(label: 'Active Tasks', value: '$activeTasks', icon: Icons.assignment_rounded, color: AppColors.warn,
                onTap: () => _push(context, const AdminTasksScreen())),
              _KpiCard(label: 'GMV (30d)', value: _money(gmv), icon: Icons.trending_up_rounded, color: AppColors.success,
                onTap: () => _push(context, const ReportsScreen())),
              _KpiCard(label: 'Revenue (30d)', value: _money(revenue), icon: Icons.payments_rounded, color: AppColors.primary,
                onTap: () => _push(context, const ReportsScreen())),
              _KpiCard(label: 'Open Disputes', value: '$openDisputes', icon: Icons.gavel_rounded, color: AppColors.danger,
                onTap: () => _push(context, const DisputesListScreen())),
              _KpiCard(label: 'Pending KYC', value: '$pendingKyc', icon: Icons.verified_user_outlined, color: AppColors.warn,
                onTap: () => _push(context, const AdminTeamScreen())),
            ],
          ),
          const SizedBox(height: 24),

          // ── Quick Actions ─────────────────────────────────
          _SectionTitle('Quick Actions'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: GestureDetector(
                onTap: () => _push(context, const AdminTeamScreen()),
                child: _ActionChip(icon: Icons.verified_outlined, label: 'KYC Queue', count: pendingKyc, color: AppColors.warn),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => _push(context, const DisputesListScreen()),
                child: _ActionChip(icon: Icons.gavel_rounded, label: 'Disputes', count: openDisputes, color: AppColors.danger),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => _push(context, const AdminTasksScreen()),
                child: _ActionChip(icon: Icons.task_alt_rounded, label: 'Completed', count: completedTasks, color: AppColors.success),
              )),
            ],
          ),
          const SizedBox(height: 24),

          // ── Task Breakdown ────────────────────────────────
          if (tasksByStatus.isNotEmpty) ...[
            _SectionTitle('Tasks by Status'),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: tasksByStatus.map<Widget>((item) {
                    final status = item['status']?.toString() ?? '?';
                    final count = _num(item['count']);
                    final total = tasksByStatus.fold<int>(0, (sum, i) => sum + _num(i['count']));
                    final ratio = total > 0 ? count / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtext),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(_statusColor(status)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 30,
                            child: Text('$count', textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Top Agents ────────────────────────────────────
          if (topAgents.isNotEmpty) ...[
            _SectionTitle('Top Agents'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: topAgents.take(5).map<Widget>((a) {
                  final u = a['user'] is Map ? a['user'] as Map : a;
                  final name = '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim();
                  final rating = _dbl(a['rating'] ?? a['currentRating']);
                  final completed = _num(a['tasksCompleted'] ?? a['completedTasks']);
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    title: Text(name.isNotEmpty ? name : 'Agent', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('$completed tasks', style: TextStyle(color: subtext, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.warn, size: 16),
                        const SizedBox(width: 2),
                        Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Top Businesses ────────────────────────────────
          if (topBiz.isNotEmpty) ...[
            _SectionTitle('Top Businesses'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: topBiz.take(5).map<Widget>((b) {
                  final name = b['name']?.toString() ?? 'Business';
                  final tasks = _num(b['taskCount'] ?? b['tasksPosted']);
                  final status = b['status']?.toString() ?? '';
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primarySoft.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppColors.primarySoft, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('$tasks tasks', style: TextStyle(color: subtext, fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (status == 'ACTIVE' ? AppColors.success : AppColors.warn).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(status, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: status == 'ACTIVE' ? AppColors.success : AppColors.warn,
                      )),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Recent Activity ───────────────────────────────
          _SectionTitle('Recent Activity'),
          const SizedBox(height: 10),
          if (_activity.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('No recent activity', style: TextStyle(color: subtext, fontSize: 13)),
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: _activity.take(8).map<Widget>((log) {
                  final action = log['action']?.toString() ?? '';
                  final actor = log['actorEmail']?.toString() ?? log['actorName']?.toString() ?? '';
                  final resource = log['resource']?.toString() ?? '';
                  final createdAt = log['createdAt']?.toString() ?? '';
                  final timeStr = _relativeTime(createdAt);
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _actionColor(action).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(_actionIcon(action), size: 16, color: _actionColor(action)),
                    ),
                    title: Text(
                      '$action ${resource.isNotEmpty ? '· $resource' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      actor.isNotEmpty ? actor : 'System',
                      style: TextStyle(color: subtext, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(timeStr, style: TextStyle(color: subtext, fontSize: 11)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  static int _num(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _dbl(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static String _money(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  static String _statusLabel(String s) {
    return s.replaceAll('_', ' ').toLowerCase().replaceRange(0, 1, s[0].toUpperCase());
  }

  static Color _statusColor(String status) {
    return switch (status.toUpperCase()) {
      'COMPLETED' => AppColors.success,
      'IN_PROGRESS' || 'ASSIGNED' => AppColors.primary,
      'OPEN' || 'PENDING' || 'DRAFT' => AppColors.warn,
      'DISPUTED' || 'CANCELLED' => AppColors.danger,
      _ => AppColors.primarySoft,
    };
  }

  static IconData _actionIcon(String action) {
    final a = action.toUpperCase();
    if (a.contains('CREATE') || a.contains('ADD')) return Icons.add_circle_outline_rounded;
    if (a.contains('UPDATE') || a.contains('EDIT') || a.contains('PATCH')) return Icons.edit_rounded;
    if (a.contains('DELETE') || a.contains('REMOVE')) return Icons.delete_outline_rounded;
    if (a.contains('LOGIN') || a.contains('AUTH')) return Icons.login_rounded;
    if (a.contains('APPROVE') || a.contains('VERIFY')) return Icons.check_circle_outline_rounded;
    if (a.contains('REJECT') || a.contains('DENY')) return Icons.cancel_outlined;
    return Icons.info_outline_rounded;
  }

  static Color _actionColor(String action) {
    final a = action.toUpperCase();
    if (a.contains('CREATE') || a.contains('APPROVE')) return AppColors.success;
    if (a.contains('DELETE') || a.contains('REJECT')) return AppColors.danger;
    if (a.contains('UPDATE') || a.contains('EDIT')) return AppColors.primary;
    return AppColors.primarySoft;
  }

  static String _relativeTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}

// ── Widgets ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark ? AppColors.darkSubtext : AppColors.lightSubtext;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color)),
                  Text(label, style: TextStyle(color: subtext, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _ActionChip({required this.icon, required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
