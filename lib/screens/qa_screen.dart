import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class _Review {
  final String id;
  final String taskTitle;
  final String agentName;
  final String reviewerName;
  final int score;
  final String feedback;
  final String reviewType;
  final DateTime createdAt;

  const _Review({
    required this.id,
    required this.taskTitle,
    required this.agentName,
    required this.reviewerName,
    required this.score,
    required this.feedback,
    required this.reviewType,
    required this.createdAt,
  });

  bool get passing => score >= 70;

  Color get scoreColor {
    if (score >= 80) return AppColors.success;
    if (score >= 70) return AppColors.primarySoft;
    if (score >= 50) return AppColors.warn;
    return AppColors.danger;
  }

  factory _Review.fromJson(Map<String, dynamic> j) {
    int i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    String name(dynamic v) {
      if (v is Map) {
        final first = v['firstName']?.toString() ?? '';
        final last = v['lastName']?.toString() ?? '';
        return '$first $last'.trim();
      }
      return v?.toString() ?? '';
    }

    final task = j['task'];
    String taskTitle = j['taskTitle']?.toString() ?? '';
    if (task is Map) taskTitle = task['title']?.toString() ?? taskTitle;

    DateTime created = DateTime.now();
    final raw = j['createdAt'] ?? j['reviewedAt'];
    if (raw != null) created = DateTime.tryParse(raw.toString()) ?? created;

    return _Review(
      id: j['id']?.toString() ?? '',
      taskTitle: taskTitle.isNotEmpty ? taskTitle : 'Unknown task',
      agentName: name(j['agent'] ?? j['agentName']),
      reviewerName: name(j['reviewer'] ?? j['reviewerName']),
      score: i(j['score'] ?? j['overallScore']),
      feedback: j['feedback']?.toString() ?? '',
      reviewType: j['reviewType']?.toString() ?? 'STANDARD',
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

class QaScreen extends StatefulWidget {
  const QaScreen({super.key});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  List<_Review> _reviews = [];
  bool _loading = true;
  String? _error;
  bool _formExpanded = false;

  // New review form state
  List<_TaskOption> _completedTasks = [];
  String? _selectedTaskId;
  String _reviewType = 'STANDARD';
  double _overallScore = 70;
  double _accuracy = 70;
  double _communication = 70;
  double _speed = 70;
  double _professionalism = 70;
  double _adherence = 70;
  final _feedbackCtrl = TextEditingController();
  bool _flagTraining = false;
  bool _recommendPromotion = false;
  bool _submitting = false;

  static const _reviewTypes = ['STANDARD', 'CALIBRATION', 'DISPUTE'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.instance.get('/qa/reviews');
      final raw = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['items'] is List) {
        list = raw['items'] as List;
      } else if (raw is Map && raw['reviews'] is List) {
        list = raw['reviews'] as List;
      } else {
        list = [];
      }
      _reviews = list
          .whereType<Map<String, dynamic>>()
          .map(_Review.fromJson)
          .toList();
    } catch (e) {
      _error = cleanError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadCompletedTasks() async {
    if (_completedTasks.isNotEmpty) return;
    try {
      final resp = await ApiService.instance
          .get('/tasks', query: {'status': 'COMPLETED'});
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
      _completedTasks = list
          .whereType<Map<String, dynamic>>()
          .map((j) => _TaskOption(
                id: j['id']?.toString() ?? '',
                title: j['title']?.toString() ?? 'Untitled',
              ))
          .toList();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _submitReview() async {
    if (_selectedTaskId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a task'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.instance.post('/qa/reviews', body: {
        'taskId': _selectedTaskId,
        'reviewType': _reviewType,
        'score': _overallScore.round(),
        'dimensions': {
          'accuracy': _accuracy.round(),
          'communication': _communication.round(),
          'speed': _speed.round(),
          'professionalism': _professionalism.round(),
          'adherence': _adherence.round(),
        },
        if (_feedbackCtrl.text.trim().isNotEmpty)
          'feedback': _feedbackCtrl.text.trim(),
        'flagForTraining': _flagTraining,
        'recommendPromotion': _recommendPromotion,
      });
      if (!mounted) return;
      // Reset form
      setState(() {
        _formExpanded = false;
        _selectedTaskId = null;
        _reviewType = 'STANDARD';
        _overallScore = 70;
        _accuracy = 70;
        _communication = 70;
        _speed = 70;
        _professionalism = 70;
        _adherence = 70;
        _feedbackCtrl.clear();
        _flagTraining = false;
        _recommendPromotion = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Review submitted'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Stats
  double get _avgScore {
    if (_reviews.isEmpty) return 0;
    return _reviews.map((r) => r.score).reduce((a, b) => a + b) /
        _reviews.length;
  }

  int get _passingCount => _reviews.where((r) => r.passing).length;
  int get _failingCount => _reviews.where((r) => !r.passing).length;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final df = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('QA Reviews'),
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
              child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subtext)),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // ── Stats row ──
                      GridView.count(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.85,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          StatTile(
                            icon: Icons.speed_rounded,
                            label: 'Avg Score',
                            value: '${_avgScore.toStringAsFixed(0)}%',
                            color: AppColors.primary,
                          ),
                          StatTile(
                            icon: Icons.rate_review_rounded,
                            label: 'Total',
                            value: '${_reviews.length}',
                            color: AppColors.primarySoft,
                          ),
                          StatTile(
                            icon: Icons.check_circle_rounded,
                            label: 'Passing',
                            value: '$_passingCount',
                            color: AppColors.success,
                          ),
                          StatTile(
                            icon: Icons.cancel_rounded,
                            label: 'Failing',
                            value: '$_failingCount',
                            color: AppColors.danger,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── New Review (expandable card) ──
                      GestureDetector(
                        onTap: () {
                          setState(
                              () => _formExpanded = !_formExpanded);
                          if (_formExpanded) _loadCompletedTasks();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: t.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: t.dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: AppColors.primary,
                                        size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'New review',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                    ),
                                  ),
                                  Icon(
                                    _formExpanded
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    color: subtext,
                                  ),
                                ],
                              ),
                              if (_formExpanded) ...[
                                const SizedBox(height: 16),
                                _buildReviewForm(t, subtext),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Reviews list ──
                      if (_reviews.isEmpty)
                        const EmptyState(
                          icon: Icons.rate_review_outlined,
                          title: 'No reviews yet',
                          message:
                              'QA reviews will appear here once submitted.',
                        )
                      else
                        ..._reviews.map((r) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 10),
                              child: _ReviewCard(
                                  review: r,
                                  subtext: subtext,
                                  df: df),
                            )),
                    ],
                  ),
                ),
    );
  }

  Widget _buildReviewForm(ThemeData t, Color subtext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Task dropdown
        const Text('Task *',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedTaskId,
          isExpanded: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.task_alt_rounded, size: 20),
            hintText: 'Select a completed task',
          ),
          items: _completedTasks
              .map((t) => DropdownMenuItem(
                  value: t.id,
                  child:
                      Text(t.title, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => setState(() => _selectedTaskId = v),
        ),
        const SizedBox(height: 14),

        // Review type
        const Text('Review type',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _reviewType,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.category_rounded, size: 20),
          ),
          items: _reviewTypes
              .map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r[0] + r.substring(1).toLowerCase())))
              .toList(),
          onChanged: (v) =>
              setState(() => _reviewType = v ?? 'STANDARD'),
        ),
        const SizedBox(height: 14),

        // Overall score slider
        _scoreSlider('Overall score', _overallScore,
            (v) => setState(() => _overallScore = v)),
        const SizedBox(height: 10),

        // Dimension scores
        const Text('Dimension scores',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        _scoreSlider(
            'Accuracy', _accuracy, (v) => setState(() => _accuracy = v)),
        _scoreSlider('Communication', _communication,
            (v) => setState(() => _communication = v)),
        _scoreSlider(
            'Speed', _speed, (v) => setState(() => _speed = v)),
        _scoreSlider('Professionalism', _professionalism,
            (v) => setState(() => _professionalism = v)),
        _scoreSlider('Adherence', _adherence,
            (v) => setState(() => _adherence = v)),
        const SizedBox(height: 14),

        // Feedback
        const Text('Feedback',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: _feedbackCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Detailed feedback for the agent...',
          ),
        ),
        const SizedBox(height: 14),

        // Checkboxes
        CheckboxListTile(
          value: _flagTraining,
          onChanged: (v) => setState(() => _flagTraining = v ?? false),
          title: const Text('Flag for training',
              style: TextStyle(fontSize: 13)),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
        ),
        CheckboxListTile(
          value: _recommendPromotion,
          onChanged: (v) =>
              setState(() => _recommendPromotion = v ?? false),
          title: const Text('Recommend promotion',
              style: TextStyle(fontSize: 13)),
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.primary,
        ),
        const SizedBox(height: 16),

        // Submit
        FilledButton(
          onPressed: _submitting ? null : _submitReview,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Submit review'),
        ),
      ],
    );
  }

  Widget _scoreSlider(
      String label, double value, ValueChanged<double> onChanged) {
    final color = value >= 80
        ? AppColors.success
        : value >= 70
            ? AppColors.primarySoft
            : value >= 50
                ? AppColors.warn
                : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.15),
                thumbColor: color,
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '${value.round()}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Review Card ─────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final _Review review;
  final Color subtext;
  final DateFormat df;

  const _ReviewCard({
    required this.review,
    required this.subtext,
    required this.df,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

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
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  review.taskTitle,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: review.scoreColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color:
                          review.scoreColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${review.score}%',
                  style: TextStyle(
                    color: review.scoreColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: review.score / 100,
              minHeight: 6,
              backgroundColor:
                  review.scoreColor.withValues(alpha: 0.12),
              valueColor:
                  AlwaysStoppedAnimation(review.scoreColor),
            ),
          ),
          const SizedBox(height: 10),

          // Agent / reviewer / date
          Row(
            children: [
              Icon(Icons.person_rounded, size: 13, color: subtext),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  review.agentName.isNotEmpty
                      ? review.agentName
                      : 'Agent',
                  style: TextStyle(fontSize: 12, color: subtext),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.rate_review_rounded,
                  size: 13, color: subtext),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  review.reviewerName.isNotEmpty
                      ? review.reviewerName
                      : 'Reviewer',
                  style: TextStyle(fontSize: 12, color: subtext),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.schedule_rounded,
                  size: 13, color: subtext),
              const SizedBox(width: 4),
              Text(
                df.format(review.createdAt),
                style: TextStyle(fontSize: 12, color: subtext),
              ),
            ],
          ),

          // Feedback
          if (review.feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.feedback,
              style: TextStyle(fontSize: 12, color: subtext),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
