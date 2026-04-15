import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../services/api_service.dart';
import '../services/shifts_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  List<Shift> _shifts = [];
  bool _loading = true;
  String? _error;

  // Week navigator
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Start of current week (Monday)
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _shifts = await ShiftsService().mine();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _prevWeek() => setState(() {
        _weekStart = _weekStart.subtract(const Duration(days: 7));
      });

  void _nextWeek() => setState(() {
        _weekStart = _weekStart.add(const Duration(days: 7));
      });

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  List<Shift> _shiftsForDay(DateTime day) {
    return _shifts.where((s) {
      return s.start.year == day.year &&
          s.start.month == day.month &&
          s.start.day == day.day;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppColors.success;
      case 'COMPLETED':
        return AppColors.lightSubtext;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.primary; // SCHEDULED
    }
  }

  List<Shift> get _upcoming {
    final now = DateTime.now();
    return _shifts
        .where((s) =>
            s.status == 'SCHEDULED' &&
            s.start.isAfter(now))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  void _showAddShift([DateTime? prefillDate]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddShiftSheet(
        prefillDate: prefillDate,
        onAdded: _load,
      ),
    );
  }

  Future<void> _cancelShift(Shift s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel shift?'),
        content: Text('Cancel "${s.label}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, cancel',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance
          .patch('/workforce/shifts/${s.id}', body: {'status': 'CANCELLED'});
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel shift')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final tf = DateFormat('HH:mm');
    final weekLabel =
        '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d').format(_weekStart.add(const Duration(days: 6)))}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shifts'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showAddShift,
        icon: const Icon(Icons.add),
        label: const Text('Add shift'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: subtext)),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      // --- Week navigator ---
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: t.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.dividerColor),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              onPressed: _prevWeek,
                              visualDensity: VisualDensity.compact,
                            ),
                            Expanded(
                              child: Text(
                                weekLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: _nextWeek,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- Weekly grid ---
                      Container(
                        decoration: BoxDecoration(
                          color: t.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: t.dividerColor),
                        ),
                        child: Column(
                          children: [
                            // Header row
                            Row(
                              children: _weekDays.map((d) {
                                final today = DateTime.now();
                                final isToday = d.year == today.year &&
                                    d.month == today.month &&
                                    d.day == today.day;
                                return Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border(
                                          bottom: BorderSide(
                                              color: t.dividerColor)),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          DateFormat('E').format(d),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: isToday
                                                  ? AppColors.primary
                                                  : subtext,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          width: 26,
                                          height: 26,
                                          decoration: isToday
                                              ? const BoxDecoration(
                                                  color: AppColors.primary,
                                                  shape: BoxShape.circle,
                                                )
                                              : null,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${d.day}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isToday
                                                  ? Colors.white
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            // Shift blocks row
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: _weekDays.map((d) {
                                  final dayShifts = _shiftsForDay(d);
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showAddShift(d),
                                      child: Container(
                                        constraints: const BoxConstraints(
                                            minHeight: 80),
                                        padding: const EdgeInsets.all(4),
                                        child: dayShifts.isEmpty
                                            ? const SizedBox()
                                            : Column(
                                                children:
                                                    dayShifts.map((s) {
                                                  final color =
                                                      _statusColor(
                                                          s.status);
                                                  return Container(
                                                    margin: const EdgeInsets
                                                        .only(bottom: 3),
                                                    padding: const EdgeInsets
                                                        .all(3),
                                                    decoration: BoxDecoration(
                                                      color: color
                                                          .withValues(
                                                              alpha: 0.14),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(4),
                                                      border: Border.all(
                                                          color: color
                                                              .withValues(
                                                                  alpha:
                                                                      0.4)),
                                                    ),
                                                    child: Text(
                                                      '${tf.format(s.start)}-${tf.format(s.end)}',
                                                      style: TextStyle(
                                                          fontSize: 9,
                                                          color: color,
                                                          fontWeight:
                                                              FontWeight
                                                                  .w700),
                                                      overflow:
                                                          TextOverflow
                                                              .ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Upcoming Shifts'),
                      const SizedBox(height: 10),

                      if (_upcoming.isEmpty)
                        const EmptyState(
                          icon: Icons.calendar_today_outlined,
                          title: 'No upcoming shifts',
                          message:
                              'Tap "Add shift" to schedule your next shift.',
                        )
                      else
                        ..._upcoming.map((s) {
                          final df = DateFormat('EEE, MMM d');
                          final color = _statusColor(s.status);
                          return Dismissible(
                            key: Key(s.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              await _cancelShift(s);
                              return false;
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: 20),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppColors.danger
                                    .withValues(alpha: 0.14),
                                borderRadius:
                                    BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.cancel_outlined,
                                  color: AppColors.danger),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: t.cardColor,
                                borderRadius:
                                    BorderRadius.circular(14),
                                border: Border.all(
                                    color: t.dividerColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color.withValues(
                                          alpha: 0.14),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.schedule_rounded,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          df.format(s.start),
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${tf.format(s.start)} – ${tf.format(s.end)}',
                                          style: TextStyle(
                                              color: subtext,
                                              fontSize: 12),
                                        ),
                                        if (s.label.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            s.label,
                                            style: TextStyle(
                                                color: subtext,
                                                fontSize: 11),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  StatusPill(
                                    label: s.status,
                                    color: color,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

// ─── Add Shift Bottom Sheet ──────────────────────────────────────────────────

class _AddShiftSheet extends StatefulWidget {
  final DateTime? prefillDate;
  final VoidCallback onAdded;
  const _AddShiftSheet({this.prefillDate, required this.onAdded});

  @override
  State<_AddShiftSheet> createState() => _AddShiftSheetState();
}

class _AddShiftSheetState extends State<_AddShiftSheet> {
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late String _selectedDay;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final _notesCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillDate != null) {
      final idx = (widget.prefillDate!.weekday - 1).clamp(0, 6);
      _selectedDay = _days[idx];
    } else {
      _selectedDay = _days[0];
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _submit() async {
    // Build DateTime from selected day
    final now = DateTime.now();
    final dayIdx = _days.indexOf(_selectedDay);
    final weekStart =
        now.subtract(Duration(days: now.weekday - 1));
    final shiftDate = DateTime(
        weekStart.year, weekStart.month, weekStart.day + dayIdx);

    final startAt = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endAt = DateTime(
      shiftDate.year,
      shiftDate.month,
      shiftDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (!endAt.isAfter(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final userId = context.read<AuthController>().user?.id ?? '';
      await ApiService.instance.post('/workforce/shifts', body: {
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'agentId': userId,
        if (_notesCtrl.text.trim().isNotEmpty)
          'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add shift: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Add Shift',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          // Day picker
          const Text('Day',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedDay,
            decoration: const InputDecoration(
              prefixIcon:
                  Icon(Icons.calendar_today_outlined, size: 20),
            ),
            items: _days
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) =>
                setState(() => _selectedDay = v ?? _days[0]),
          ),
          const SizedBox(height: 16),
          // Time pickers
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Start time',
                  time: _startTime,
                  onTap: () => _pickTime(true),
                  subtext: subtext,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePicker(
                  label: 'End time',
                  time: _endTime,
                  onTap: () => _pickTime(false),
                  subtext: subtext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Notes
          const Text('Notes (optional)',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'E.g. Overtime, cover shift...',
              prefixIcon: Icon(Icons.notes_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Add shift'),
          ),
        ],
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  final Color subtext;
  const _TimePicker({
    required this.label,
    required this.time,
    required this.onTap,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: t.inputDecorationTheme.fillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.dividerColor),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 18, color: subtext),
                const SizedBox(width: 8),
                Text(
                  time.format(context),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
