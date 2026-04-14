import 'api_service.dart';

class PerformanceSummary {
  final double rating;
  final int totalTasks;
  final int onTimeRate; // pct
  final int qaScore; // pct
  final int ranking;
  final List<EarningsPoint> points;
  final List<QaReview> reviews;

  PerformanceSummary({
    required this.rating,
    required this.totalTasks,
    required this.onTimeRate,
    required this.qaScore,
    required this.ranking,
    required this.points,
    required this.reviews,
  });
}

class EarningsPoint {
  final DateTime day;
  final double amount;
  final int tasks;
  EarningsPoint(this.day, this.amount, this.tasks);
}

class QaReview {
  final String id;
  final String taskTitle;
  final int score;
  final String? feedback;
  final DateTime createdAt;
  QaReview({
    required this.id,
    required this.taskTitle,
    required this.score,
    this.feedback,
    required this.createdAt,
  });
}

class PerformanceService {
  final _api = ApiService.instance;

  Future<PerformanceSummary> summary() async {
    final r = await _api.get('/agents/me/performance');
    final d = unwrap<Map<String, dynamic>>(r);
    return _parse(d);
  }

  PerformanceSummary _parse(Map<String, dynamic> d) {
    final pts = (d['earnings'] as List? ?? [])
        .whereType<Map>()
        .map((e) => EarningsPoint(
              DateTime.tryParse(e['day']?.toString() ?? '') ?? DateTime.now(),
              _d(e['amount']),
              (e['tasks'] is num) ? (e['tasks'] as num).toInt() : 0,
            ))
        .toList();
    final revs = (d['reviews'] as List? ?? [])
        .whereType<Map>()
        .map((e) => QaReview(
              id: e['id']?.toString() ?? '',
              taskTitle: e['taskTitle']?.toString() ?? '',
              score: (e['score'] is num) ? (e['score'] as num).toInt() : 0,
              feedback: e['feedback']?.toString(),
              createdAt: DateTime.tryParse(e['createdAt']?.toString() ?? '') ??
                  DateTime.now(),
            ))
        .toList();
    return PerformanceSummary(
      rating: _d(d['rating']),
      totalTasks: (d['totalTasks'] is num) ? (d['totalTasks'] as num).toInt() : 0,
      onTimeRate: (d['onTimeRate'] is num) ? (d['onTimeRate'] as num).toInt() : 0,
      qaScore: (d['qaScore'] is num) ? (d['qaScore'] as num).toInt() : 0,
      ranking: (d['ranking'] is num) ? (d['ranking'] as num).toInt() : 0,
      points: pts,
      reviews: revs,
    );
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
