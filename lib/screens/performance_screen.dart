import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/performance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  PerformanceSummary? _data;
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
      _data = await PerformanceService().summary();
    } catch (e) {
      _error = e.toString();
      _data = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Performance')),
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Performance')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final d = _data!;
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.star_rounded,
                    label: 'Rating',
                    value: d.rating.toStringAsFixed(2),
                    color: AppColors.warn,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.verified_rounded,
                    label: 'QA score',
                    value: '${d.qaScore}%',
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
                    icon: Icons.task_alt_rounded,
                    label: 'Completed',
                    value: '${d.totalTasks}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    icon: Icons.leaderboard_rounded,
                    label: 'Ranking',
                    value: '#${d.ranking}',
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.av_timer_rounded,
                    label: 'On-time',
                    value: '${d.onTimeRate}%',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 22),

            // -- Earnings chart
            const SectionHeader(title: 'Earnings — last 7 days'),
            const SizedBox(height: 10),
            Container(
              height: 200,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.dividerColor),
              ),
              child: d.points.isEmpty
                  ? Center(
                      child: Text('No data', style: TextStyle(color: subtext)))
                  : BarChart(
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
                                if (i < 0 || i >= d.points.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormat('E')
                                        .format(d.points[i].day)
                                        .substring(0, 1),
                                    style:
                                        TextStyle(fontSize: 11, color: subtext),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: List.generate(d.points.length, (i) {
                          return BarChartGroupData(x: i, barRods: [
                            BarChartRodData(
                              toY: d.points[i].amount,
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
            ),

            // -- Task count chart
            const SizedBox(height: 18),
            const SectionHeader(title: 'Tasks — last 7 days'),
            const SizedBox(height: 10),
            Container(
              height: 180,
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.dividerColor),
              ),
              child: d.points.isEmpty
                  ? Center(
                      child: Text('No data', style: TextStyle(color: subtext)))
                  : LineChart(
                      LineChartData(
                        lineTouchData: const LineTouchData(enabled: false),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(),
                          rightTitles: AxisTitles(),
                          leftTitles: AxisTitles(),
                          bottomTitles: AxisTitles(),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(d.points.length, (i) {
                              return FlSpot(
                                  i.toDouble(), d.points[i].tasks.toDouble());
                            }),
                            isCurved: true,
                            color: AppColors.success,
                            barWidth: 2.5,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (_, __, ___, ____) =>
                                  FlDotCirclePainter(
                                radius: 3,
                                color: AppColors.success,
                                strokeWidth: 0,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.success.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // -- rating breakdown
            const SizedBox(height: 22),
            const SectionHeader(title: 'Rating breakdown'),
            const SizedBox(height: 10),
            _RatingBar(label: '5 stars', pct: 0.68, color: AppColors.success),
            _RatingBar(label: '4 stars', pct: 0.22, color: AppColors.primary),
            _RatingBar(label: '3 stars', pct: 0.07, color: AppColors.warn),
            _RatingBar(label: '2 stars', pct: 0.02, color: AppColors.warn),
            _RatingBar(label: '1 star', pct: 0.01, color: AppColors.danger),

            // -- improvement tips
            const SizedBox(height: 22),
            const SectionHeader(title: 'Improvement tips'),
            const SizedBox(height: 10),
            _tip(t, 'Try to close tasks 10% under SLA to boost on-time rate.'),
            _tip(t, 'Double-check edge cases in KYC reviews to raise QA score.'),
            _tip(t, 'Keep your availability on during peak hours (9-12).'),

            // -- QA reviews
            const SizedBox(height: 22),
            const SectionHeader(title: 'Recent QA reviews'),
            const SizedBox(height: 8),
            ...d.reviews.map((r) => _QaTile(
                  title: r.taskTitle,
                  score: r.score,
                  comment: r.feedback ?? '',
                )),
            if (d.reviews.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No reviews yet',
                      style: TextStyle(color: subtext)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tip(ThemeData t, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.warn),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: t.textTheme.bodySmall?.copyWith(height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final String label;
  final double pct;
  final Color color;
  const _RatingBar(
      {required this.label, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(color: subtext, fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: t.dividerColor,
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '${(pct * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _QaTile extends StatelessWidget {
  final String title;
  final int score;
  final String comment;
  const _QaTile({
    required this.title,
    required this.score,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final color = score >= 95
        ? AppColors.success
        : (score >= 85 ? AppColors.primary : AppColors.warn);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$score',
              style: TextStyle(
                color: color,
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(comment,
                      style:
                          TextStyle(fontSize: 12, color: subtext, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
