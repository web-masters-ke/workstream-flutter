import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

// ─── Step chip (same pattern as PostTaskScreen) ─────────────────────────────

class _StepChip extends StatelessWidget {
  final int step;
  final String label;
  final bool active;
  final bool done;

  const _StepChip({
    required this.step,
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done
                ? AppColors.success
                : active
                    ? AppColors.primary
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: done
                  ? AppColors.success
                  : active
                      ? AppColors.primary
                      : subtext.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : subtext,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active
                ? (isDark ? AppColors.darkText : AppColors.lightText)
                : subtext,
          ),
        ),
      ],
    );
  }
}

// ─── Field label (reused pattern) ───────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color subtext;
  const _FieldLabel(this.text, {required this.subtext});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: subtext),
    );
  }
}

// ─── Template quick-select ──────────────────────────────────────────────────

const _kTemplates = [
  {'label': 'Customer Support', 'description': 'Handle customer inquiries and tickets'},
  {'label': 'Data Entry', 'description': 'Enter and validate data records'},
  {'label': 'Sales Outreach', 'description': 'Contact leads and follow up on prospects'},
  {'label': 'Content Review', 'description': 'Review and moderate submitted content'},
  {'label': 'Order Processing', 'description': 'Process and fulfill incoming orders'},
];

const _kPriorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];
const _kRateTypes = ['FIXED', 'HOURLY', 'PER_TASK'];
const _kAssignStrategies = ['AUTO', 'SKILL_BASED', 'MANUAL'];

// ─── New Job Screen ─────────────────────────────────────────────────────────

class NewJobScreen extends StatefulWidget {
  const NewJobScreen({super.key});

  @override
  State<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends State<NewJobScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  // Step 1 — Basics
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _priority = 'MEDIUM';
  String? _selectedTemplate;

  // Step 2 — Tasks
  final List<_TaskDef> _taskDefs = [_TaskDef()];

  // Step 3 — SLA & Rate
  final _slaCtrl = TextEditingController();
  String _rateType = 'FIXED';
  final _rateAmountCtrl = TextEditingController();

  // Step 4 — Assignment
  String _assignStrategy = 'AUTO';

  // Step 5 — QA
  bool _qaEnabled = false;
  final _qaSampleCtrl = TextEditingController(text: '20');
  final _qaMinScoreCtrl = TextEditingController(text: '80');

  // Submission
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _slaCtrl.dispose();
    _rateAmountCtrl.dispose();
    _qaSampleCtrl.dispose();
    _qaMinScoreCtrl.dispose();
    for (final td in _taskDefs) {
      td.dispose();
    }
    super.dispose();
  }

  void _nextPage() {
    if (_page < 5) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() => _page++);
    }
  }

  void _prevPage() {
    if (_page > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() => _page--);
    }
  }

  bool get _step1Valid =>
      _titleCtrl.text.trim().length >= 3;

  bool get _step2Valid =>
      _taskDefs.isNotEmpty &&
      _taskDefs.every((t) => t.titleCtrl.text.trim().isNotEmpty);

  bool get _step3Valid =>
      _rateAmountCtrl.text.trim().isNotEmpty &&
      (double.tryParse(_rateAmountCtrl.text.trim()) ?? 0) > 0;

  void _applyTemplate(Map<String, String> template) {
    setState(() {
      _selectedTemplate = template['label'];
      if (_titleCtrl.text.trim().isEmpty) {
        _titleCtrl.text = template['label'] ?? '';
      }
      if (_descCtrl.text.trim().isEmpty) {
        _descCtrl.text = template['description'] ?? '';
      }
    });
  }

  void _addTask() {
    setState(() => _taskDefs.add(_TaskDef()));
  }

  void _removeTask(int index) {
    if (_taskDefs.length <= 1) return;
    setState(() {
      _taskDefs[index].dispose();
      _taskDefs.removeAt(index);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final tasks = _taskDefs.map((t) => {
            'title': t.titleCtrl.text.trim(),
            if (t.skillCtrl.text.trim().isNotEmpty)
              'skill': t.skillCtrl.text.trim(),
          }).toList();

      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'priority': _priority,
        'tasks': tasks,
        'rateType': _rateType,
        'rateAmount': double.parse(_rateAmountCtrl.text.trim()),
        'assignmentStrategy': _assignStrategy,
        'qaEnabled': _qaEnabled,
      };

      if (_slaCtrl.text.trim().isNotEmpty) {
        body['slaMinutes'] = int.tryParse(_slaCtrl.text.trim()) ?? 0;
      }

      if (_qaEnabled) {
        body['qaSamplePercent'] =
            int.tryParse(_qaSampleCtrl.text.trim()) ?? 20;
        body['qaMinScore'] =
            int.tryParse(_qaMinScoreCtrl.text.trim()) ?? 80;
      }

      if (_selectedTemplate != null) {
        body['template'] = _selectedTemplate;
      }

      await ApiService.instance.post('/jobs', body: body);

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Job created successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e
            .toString()
            .replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;

    final steps = [
      'Basics',
      'Tasks',
      'SLA & Rate',
      'Assignment',
      'QA',
      'Review',
    ];

    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New job'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(steps.length * 2 - 1, (i) {
                  if (i.isOdd) {
                    return Container(
                      width: 16,
                      height: 1,
                      color: borderColor,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }
                  final idx = i ~/ 2;
                  return _StepChip(
                    step: idx + 1,
                    label: steps[idx],
                    active: _page == idx,
                    done: _page > idx,
                  );
                }),
              ),
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1Basics(t, subtext, cardColor, borderColor),
          _buildStep2Tasks(t, subtext, cardColor, borderColor),
          _buildStep3SlaRate(t, subtext),
          _buildStep4Assignment(t, subtext, cardColor, borderColor),
          _buildStep5QA(t, subtext),
          _buildStep6Review(t, subtext, cardColor, borderColor),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (_page > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _prevPage,
                    child: const Text('Back'),
                  ),
                ),
              if (_page > 0) const SizedBox(width: 12),
              Expanded(
                flex: _page == 0 ? 1 : 2,
                child: _page < 5
                    ? FilledButton(
                        onPressed: _canAdvance() ? _nextPage : null,
                        child: const Text('Continue',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      )
                    : FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Create job',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canAdvance() {
    switch (_page) {
      case 0:
        return _step1Valid;
      case 1:
        return _step2Valid;
      case 2:
        return _step3Valid;
      default:
        return true;
    }
  }

  // ── Step 1: Basics ──────────────────────────────────────────────────────

  Widget _buildStep1Basics(
      ThemeData t, Color subtext, Color cardColor, Color borderColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job basics',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Give your job a clear title and description.',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 20),

          // Title
          _FieldLabel('Title *', subtext: subtext),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleCtrl,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'e.g. Process customer refund requests',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),

          // Description
          _FieldLabel('Description', subtext: subtext),
          const SizedBox(height: 6),
          TextFormField(
            controller: _descCtrl,
            maxLines: 4,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Describe what needs to be done...',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),

          // Priority
          _FieldLabel('Priority', subtext: subtext),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kPriorities.map((p) {
              final active = _priority == p;
              return GestureDetector(
                onTap: () => setState(() => _priority = p),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? _priorityColor(p) : cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: active ? _priorityColor(p) : borderColor),
                  ),
                  child: Text(
                    p,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Template quick-select
          _FieldLabel('Quick-start from template', subtext: subtext),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kTemplates.map((tpl) {
              final label = tpl['label']!;
              final active = _selectedTemplate == label;
              return GestureDetector(
                onTap: () => _applyTemplate(tpl.cast<String, String>()),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: active ? AppColors.primary : borderColor),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Tasks ─────────────────────────────────────────────────────────

  Widget _buildStep2Tasks(
      ThemeData t, Color subtext, Color cardColor, Color borderColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Define tasks',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
              'Add the individual tasks that make up this job. ${_taskDefs.length} task${_taskDefs.length == 1 ? '' : 's'} defined.',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 16),

          ...List.generate(_taskDefs.length, (i) {
            final td = _taskDefs[i];
            return Container(
              margin: EdgeInsets.only(top: i == 0 ? 0 : 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Task ${i + 1}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const Spacer(),
                      if (_taskDefs.length > 1)
                        GestureDetector(
                          onTap: () => _removeTask(i),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppColors.danger),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: td.titleCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Task title',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: td.skillCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Required skill (optional)',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addTask,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add task'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: SLA & Rate ────────────────────────────────────────────────────

  Widget _buildStep3SlaRate(ThemeData t, Color subtext) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SLA & Rate',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Set the service level agreement and compensation.',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 20),

          // SLA
          _FieldLabel('SLA (minutes)', subtext: subtext),
          const SizedBox(height: 6),
          TextFormField(
            controller: _slaCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'e.g. 120 (leave blank for no SLA)',
              prefixIcon:
                  Icon(Icons.timer_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 6),
          Text('How many minutes to complete the entire job.',
              style: TextStyle(fontSize: 12, color: subtext)),
          const SizedBox(height: 20),

          // Rate type
          _FieldLabel('Rate type *', subtext: subtext),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kRateTypes.map((rt) {
              final active = _rateType == rt;
              return ChoiceChip(
                label: Text(rt.replaceAll('_', ' ')),
                selected: active,
                selectedColor: AppColors.primary.withValues(alpha: 0.18),
                onSelected: (_) => setState(() => _rateType = rt),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Rate amount
          _FieldLabel('Rate amount (KES) *', subtext: subtext),
          const SizedBox(height: 6),
          TextFormField(
            controller: _rateAmountCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            decoration: const InputDecoration(
              prefixText: 'KES ',
              hintText: '0',
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4: Assignment ────────────────────────────────────────────────────

  Widget _buildStep4Assignment(
      ThemeData t, Color subtext, Color cardColor, Color borderColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assignment strategy',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('How should agents be assigned to tasks?',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 20),

          ...List.generate(_kAssignStrategies.length, (i) {
            final s = _kAssignStrategies[i];
            final active = _assignStrategy == s;
            final desc = _strategyDesc(s);
            final icon = _strategyIcon(s);

            return GestureDetector(
              onTap: () => setState(() => _assignStrategy = s),
              child: Container(
                margin: EdgeInsets.only(top: i == 0 ? 0 : 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active ? AppColors.primary : borderColor,
                    width: active ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : subtext.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon,
                          size: 20,
                          color: active ? AppColors.primary : subtext),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.replaceAll('_', ' '),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: active ? AppColors.primary : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(desc,
                              style: TextStyle(
                                  fontSize: 12, color: subtext)),
                        ],
                      ),
                    ),
                    if (active)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 22),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _strategyDesc(String s) {
    switch (s) {
      case 'AUTO':
        return 'System assigns agents automatically based on availability.';
      case 'SKILL_BASED':
        return 'Agents are matched based on skills defined per task.';
      case 'MANUAL':
        return 'You will manually assign agents to each task.';
      default:
        return '';
    }
  }

  IconData _strategyIcon(String s) {
    switch (s) {
      case 'AUTO':
        return Icons.auto_fix_high_rounded;
      case 'SKILL_BASED':
        return Icons.psychology_rounded;
      case 'MANUAL':
        return Icons.person_search_rounded;
      default:
        return Icons.settings_rounded;
    }
  }

  // ── Step 5: QA ────────────────────────────────────────────────────────────

  Widget _buildStep5QA(ThemeData t, Color subtext) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quality assurance',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Configure QA checks for completed tasks.',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 20),

          // QA enabled toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Enable QA',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Review a sample of completed tasks',
                          style: TextStyle(fontSize: 12, color: subtext)),
                    ],
                  ),
                ),
                Switch(
                  value: _qaEnabled,
                  onChanged: (v) => setState(() => _qaEnabled = v),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),

          if (_qaEnabled) ...[
            const SizedBox(height: 16),
            _FieldLabel('Sample percentage (%)', subtext: subtext),
            const SizedBox(height: 6),
            TextFormField(
              controller: _qaSampleCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'e.g. 20',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 6),
            Text('Percentage of completed tasks to review.',
                style: TextStyle(fontSize: 12, color: subtext)),
            const SizedBox(height: 16),
            _FieldLabel('Minimum passing score (%)', subtext: subtext),
            const SizedBox(height: 6),
            TextFormField(
              controller: _qaMinScoreCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'e.g. 80',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 6),
            Text('Tasks below this score will be flagged for rework.',
                style: TextStyle(fontSize: 12, color: subtext)),
          ],
        ],
      ),
    );
  }

  // ── Step 6: Review ────────────────────────────────────────────────────────

  Widget _buildStep6Review(
      ThemeData t, Color subtext, Color cardColor, Color borderColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & create',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Confirm the details below before creating the job.',
              style: TextStyle(fontSize: 13, color: subtext)),
          const SizedBox(height: 20),

          _reviewSection(
            t: t,
            subtext: subtext,
            cardColor: cardColor,
            borderColor: borderColor,
            title: 'Basics',
            rows: [
              _ReviewRow('Title', _titleCtrl.text.trim()),
              if (_descCtrl.text.trim().isNotEmpty)
                _ReviewRow('Description', _descCtrl.text.trim()),
              _ReviewRow('Priority', _priority),
              if (_selectedTemplate != null)
                _ReviewRow('Template', _selectedTemplate!),
            ],
          ),
          const SizedBox(height: 12),

          _reviewSection(
            t: t,
            subtext: subtext,
            cardColor: cardColor,
            borderColor: borderColor,
            title: 'Tasks (${_taskDefs.length})',
            rows: _taskDefs.asMap().entries.map((e) {
              final skill = e.value.skillCtrl.text.trim();
              return _ReviewRow(
                'Task ${e.key + 1}',
                e.value.titleCtrl.text.trim() +
                    (skill.isNotEmpty ? ' [$skill]' : ''),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          _reviewSection(
            t: t,
            subtext: subtext,
            cardColor: cardColor,
            borderColor: borderColor,
            title: 'SLA & Rate',
            rows: [
              if (_slaCtrl.text.trim().isNotEmpty)
                _ReviewRow('SLA', '${_slaCtrl.text.trim()} minutes'),
              _ReviewRow('Rate type', _rateType.replaceAll('_', ' ')),
              _ReviewRow('Rate amount', 'KES ${_rateAmountCtrl.text.trim()}'),
            ],
          ),
          const SizedBox(height: 12),

          _reviewSection(
            t: t,
            subtext: subtext,
            cardColor: cardColor,
            borderColor: borderColor,
            title: 'Assignment',
            rows: [
              _ReviewRow(
                  'Strategy', _assignStrategy.replaceAll('_', ' ')),
            ],
          ),
          const SizedBox(height: 12),

          _reviewSection(
            t: t,
            subtext: subtext,
            cardColor: cardColor,
            borderColor: borderColor,
            title: 'QA',
            rows: [
              _ReviewRow('Enabled', _qaEnabled ? 'Yes' : 'No'),
              if (_qaEnabled) ...[
                _ReviewRow('Sample', '${_qaSampleCtrl.text.trim()}%'),
                _ReviewRow('Min score', '${_qaMinScoreCtrl.text.trim()}%'),
              ],
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 13))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reviewSection({
    required ThemeData t,
    required Color subtext,
    required Color cardColor,
    required Color borderColor,
    required String title,
    required List<_ReviewRow> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(r.label,
                          style: TextStyle(color: subtext, fontSize: 13)),
                    ),
                    Expanded(
                      child: Text(
                        r.value.isEmpty ? '--' : r.value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p.toUpperCase()) {
      case 'URGENT':
        return AppColors.danger;
      case 'HIGH':
        return const Color(0xFFEA580C); // orange-600
      case 'MEDIUM':
        return AppColors.warn;
      default:
        return AppColors.lightSubtext;
    }
  }
}

// ─── Helper classes ─────────────────────────────────────────────────────────

class _TaskDef {
  final titleCtrl = TextEditingController();
  final skillCtrl = TextEditingController();

  void dispose() {
    titleCtrl.dispose();
    skillCtrl.dispose();
  }
}

class _ReviewRow {
  final String label;
  final String value;
  const _ReviewRow(this.label, this.value);
}
