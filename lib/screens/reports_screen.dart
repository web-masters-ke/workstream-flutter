import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportSummary? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    try {
      // Try the summary endpoint; fall back gracefully if not yet available
      final resp = await ApiService.instance.get('/reports/summary');
      final raw = unwrap<dynamic>(resp);
      if (raw is Map<String, dynamic>) {
        _data = _ReportSummary.fromJson(raw);
      } else {
        _data = _ReportSummary.mock();
      }
    } catch (_) {
      // Backend endpoint may not exist yet — show mock totals
      _data = _ReportSummary.mock();
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
        title: const Text('Reports'),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _buildSummaryGrid(t, subtext),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Monthly task completions'),
                  const SizedBox(height: 12),
                  _buildBarChart(t, subtext),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Top agent'),
                  const SizedBox(height: 10),
                  _buildTopAgent(t, subtext),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryGrid(ThemeData t, Color subtext) {
    final d = _data!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.assignment_rounded,
                label: 'Total tasks',
                value: '${d.totalTasks}',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: Icons.check_circle_rounded,
                label: 'Completed',
                value: '${d.completed}',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.pending_actions_rounded,
                label: 'Active',
                value: '${d.active}',
                color: AppColors.warn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                icon: Icons.timer_rounded,
                label: 'Avg days',
                value: d.avgDays.toStringAsFixed(1),
                color: AppColors.primarySoft,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart(ThemeData t, Color subtext) {
    final d = _data!;
    if (d.monthlyPoints.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.dividerColor),
        ),
        child: Text('No monthly data available',
            style: TextStyle(color: subtext)),
      );
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= d.monthlyPoints.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      d.monthlyPoints[i].label,
                      style: TextStyle(fontSize: 10, color: subtext),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(d.monthlyPoints.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: d.monthlyPoints[i].count.toDouble(),
                width: 18,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6)),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppColors.primary, AppColors.primaryDeep],
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildTopAgent(ThemeData t, Color subtext) {
    final d = _data!;
    if (d.topAgentName == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.dividerColor),
        ),
        child: Text('No agent data available',
            style: TextStyle(color: subtext)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: AppColors.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.topAgentName!,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${d.topAgentTasks} tasks completed',
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ],
            ),
          ),
          StatusPill(label: 'Top Agent', color: AppColors.success),
        ],
      ),
    );
  }
}

// ─── Model ───────────────────────────────────────────────────────────────────

class _MonthlyPoint {
  final String label;
  final int count;
  const _MonthlyPoint(this.label, this.count);
}

class _ReportSummary {
  final int totalTasks;
  final int completed;
  final int active;
  final double avgDays;
  final String? topAgentName;
  final int topAgentTasks;
  final List<_MonthlyPoint> monthlyPoints;

  const _ReportSummary({
    required this.totalTasks,
    required this.completed,
    required this.active,
    required this.avgDays,
    this.topAgentName,
    this.topAgentTasks = 0,
    required this.monthlyPoints,
  });

  factory _ReportSummary.fromJson(Map<String, dynamic> j) {
    final agent = j['topAgent'];
    String? agentName;
    int agentTasks = 0;
    if (agent is Map) {
      agentName = agent['name']?.toString() ?? agent['fullName']?.toString();
      agentTasks = int.tryParse(agent['tasks']?.toString() ?? '0') ?? 0;
    }

    final rawMonthly = j['monthly'] ?? j['monthlyTasks'] ?? <dynamic>[];
    final monthly = <_MonthlyPoint>[];
    if (rawMonthly is List) {
      for (final m in rawMonthly) {
        if (m is Map) {
          final label = m['month']?.toString() ??
              m['label']?.toString() ??
              DateFormat('MMM').format(
                DateTime.tryParse(m['date']?.toString() ?? '') ??
                    DateTime.now(),
              );
          final count = int.tryParse(m['count']?.toString() ?? '0') ??
              int.tryParse(m['tasks']?.toString() ?? '0') ??
              0;
          monthly.add(_MonthlyPoint(label, count));
        }
      }
    }

    return _ReportSummary(
      totalTasks: int.tryParse(j['totalTasks']?.toString() ?? '0') ?? 0,
      completed: int.tryParse(j['completed']?.toString() ?? '0') ?? 0,
      active: int.tryParse(j['active']?.toString() ?? '0') ?? 0,
      avgDays: double.tryParse(j['avgDays']?.toString() ?? '0') ?? 0.0,
      topAgentName: agentName,
      topAgentTasks: agentTasks,
      monthlyPoints: monthly,
    );
  }

  factory _ReportSummary.mock() {
    final now = DateTime.now();
    return _ReportSummary(
      totalTasks: 84,
      completed: 61,
      active: 18,
      avgDays: 2.4,
      topAgentName: 'Top Agent',
      topAgentTasks: 23,
      monthlyPoints: List.generate(6, (i) {
        final month = DateTime(now.year, now.month - (5 - i), 1);
        return _MonthlyPoint(
          DateFormat('MMM').format(month),
          10 + i * 3 + (i % 2 == 0 ? 5 : 0),
        );
      }),
    );
  }
}
