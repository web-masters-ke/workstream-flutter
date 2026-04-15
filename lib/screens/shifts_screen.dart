import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

// ─── Models ─────────────────────────────────────────────────────────────────

class _ShiftAgent {
  final String id;
  final String name;
  final String status; // ONLINE, BUSY, OFFLINE

  const _ShiftAgent({
    required this.id,
    required this.name,
    required this.status,
  });

  factory _ShiftAgent.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map<String, dynamic> : j;
    final first = (user['firstName'] ?? j['firstName'])?.toString() ?? '';
    final last = (user['lastName'] ?? j['lastName'])?.toString() ?? '';
    final name = '$first $last'.trim();
    return _ShiftAgent(
      id: j['id']?.toString() ?? '',
      name: name.isEmpty ? 'Agent' : name,
      status: j['status']?.toString() ??
          (j['available'] == true ? 'ONLINE' : 'OFFLINE'),
    );
  }
}

class _Shift {
  final String id;
  final String agentId;
  final String agentName;
  final DateTime start;
  final DateTime end;
  final String role;
  final String status; // SCHEDULED, ACTIVE, COMPLETED, CANCELLED

  const _Shift({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.start,
    required this.end,
    required this.role,
    required this.status,
  });

  factory _Shift.fromJson(Map<String, dynamic> j) {
    String agentName = '';
    final agent = j['agent'];
    if (agent is Map) {
      final user = agent['user'] is Map ? agent['user'] as Map : agent;
      final first = (user['firstName'] ?? agent['firstName'])?.toString() ?? '';
      final last = (user['lastName'] ?? agent['lastName'])?.toString() ?? '';
      agentName = '$first $last'.trim();
    }
    return _Shift(
      id: j['id']?.toString() ?? '',
      agentId: j['agentId']?.toString() ?? '',
      agentName: agentName.isEmpty
          ? (j['agentName']?.toString() ?? 'Agent')
          : agentName,
      start: DateTime.tryParse(
              j['start']?.toString() ?? j['startAt']?.toString() ?? '') ??
          DateTime.now(),
      end: DateTime.tryParse(
              j['end']?.toString() ?? j['endAt']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 4)),
      role: j['role']?.toString() ?? j['label']?.toString() ?? j['notes']?.toString() ?? '',
      status: j['status']?.toString() ?? 'SCHEDULED',
    );
  }
}

// ─── Screen ─────────────────────────────────────────────────────────────────

class ShiftsScreen extends StatefulWidget {
  const ShiftsScreen({super.key});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  List<_Shift> _shifts = [];
  List<_ShiftAgent> _agents = [];
  bool _loading = true;
  String? _error;

  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Load shifts
    try {
      final resp = await ApiService.instance.get('/workforce/shifts');
      final data = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else {
        list = [];
      }
      _shifts = list
          .whereType<Map<String, dynamic>>()
          .map(_Shift.fromJson)
          .toList();
    } catch (e) {
      // Fallback — try agent-scoped endpoint
      try {
        final resp = await ApiService.instance.get('/agents/me/shifts');
        final data = unwrap<dynamic>(resp);
        final list = data is List ? data : const <dynamic>[];
        _shifts = list
            .whereType<Map>()
            .map((e) => _Shift.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        _error = cleanError(e);
      }
    }

    // Load agents
    try {
      final resp = await ApiService.instance.get('/agents');
      final data = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else if (data is Map && data['agents'] is List) {
        list = data['agents'] as List;
      } else {
        list = [];
      }
      _agents = list
          .whereType<Map<String, dynamic>>()
          .map(_ShiftAgent.fromJson)
          .toList();
    } catch (_) {
      // agents list optional — calendar still works
    }

    if (mounted) setState(() => _loading = false);
  }

  void _prevWeek() => setState(() {
        _weekStart = _weekStart.subtract(const Duration(days: 7));
      });

  void _nextWeek() => setState(() {
        _weekStart = _weekStart.add(const Duration(days: 7));
      });

  void _goToday() {
    final now = DateTime.now();
    final ws = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      _weekStart = DateTime(ws.year, ws.month, ws.day);
    });
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  /// Group shifts by agentId for the current week.
  Map<String, List<_Shift>> get _weekShiftsByAgent {
    final result = <String, List<_Shift>>{};
    for (final s in _shifts) {
      if (s.start.isBefore(_weekStart) ||
          s.start.isAfter(_weekEnd.add(const Duration(days: 1)))) {
        continue;
      }
      result.putIfAbsent(s.agentId, () => []).add(s);
    }
    return result;
  }

  /// Get all unique agents that have shifts in this week, plus agents from the
  /// agents list that don't have shifts (to show empty rows).
  List<_AgentRow> get _agentRows {
    final byAgent = _weekShiftsByAgent;
    final rows = <_AgentRow>[];
    final seen = <String>{};

    // Agents with shifts first
    for (final entry in byAgent.entries) {
      seen.add(entry.key);
      final name = entry.value.isNotEmpty
          ? entry.value.first.agentName
          : 'Agent';
      final agentMatch =
          _agents.where((a) => a.id == entry.key).toList();
      final status =
          agentMatch.isNotEmpty ? agentMatch.first.status : 'OFFLINE';
      rows.add(_AgentRow(
          id: entry.key, name: name, status: status, shifts: entry.value));
    }

    // Remaining agents without shifts
    for (final a in _agents) {
      if (!seen.contains(a.id)) {
        rows.add(
            _AgentRow(id: a.id, name: a.name, status: a.status, shifts: []));
      }
    }

    return rows;
  }

  List<_Shift> _shiftsForAgentDay(List<_Shift> agentShifts, DateTime day) {
    return agentShifts.where((s) {
      return s.start.year == day.year &&
          s.start.month == day.month &&
          s.start.day == day.day;
    }).toList();
  }

  Color _statusDotColor(String status) {
    switch (status.toUpperCase()) {
      case 'ONLINE':
        return AppColors.success;
      case 'BUSY':
        return AppColors.warn;
      default:
        return AppColors.lightSubtext;
    }
  }

  Color _shiftStatusColor(String status) {
    switch (status.toUpperCase()) {
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

  void _showAddShift() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddShiftSheet(
        agents: _agents,
        onAdded: _load,
      ),
    );
  }

  void _showShiftDetail(_Shift shift) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final tf = DateFormat('HH:mm');
    final df = DateFormat('EEE, MMM d, yyyy');

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Shift details',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _detailRow('Agent', shift.agentName, subtext),
            _detailRow('Date', df.format(shift.start), subtext),
            _detailRow(
                'Time',
                '${tf.format(shift.start)} – ${tf.format(shift.end)}',
                subtext),
            if (shift.role.isNotEmpty)
              _detailRow('Role', shift.role, subtext),
            _detailRow('Status', shift.status, subtext),
            const SizedBox(height: 20),
            if (shift.status.toUpperCase() != 'CANCELLED' &&
                shift.status.toUpperCase() != 'COMPLETED')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _deleteShift(shift);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: const Text('Delete shift'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color subtext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: subtext)),
          const Spacer(),
          Flexible(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600),
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteShift(_Shift shift) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete shift?'),
        content: Text(
            'Delete shift for ${shift.agentName} on ${DateFormat('MMM d').format(shift.start)}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance
          .patch('/workforce/shifts/${shift.id}', body: {'status': 'CANCELLED'});
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete shift')),
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
        '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d, yyyy').format(_weekEnd)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shifts'),
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
          ? const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5))
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
                      // ── Week navigator ──
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
                              tooltip: 'Previous week',
                            ),
                            Expanded(
                              child: Text(
                                weekLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            TextButton(
                              onPressed: _goToday,
                              child: const Text('Today',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: _nextWeek,
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Next week',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Calendar grid ──
                      _buildCalendarGrid(t, subtext, tf),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCalendarGrid(ThemeData t, Color subtext, DateFormat tf) {
    final days = _weekDays;
    final today = DateTime.now();
    final rows = _agentRows;

    if (rows.isEmpty) {
      return const EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No shifts scheduled',
        message: 'Tap "Add shift" to schedule shifts for your team.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        children: [
          // Header row: blank agent column + 7 day columns
          Row(
            children: [
              // Agent column header
              Container(
                width: 90,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: t.dividerColor)),
                ),
                child: Text('Agent',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: subtext)),
              ),
              // Day columns
              ...days.map((d) {
                final isToday = d.year == today.year &&
                    d.month == today.month &&
                    d.day == today.day;
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: t.dividerColor)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('E').format(d),
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday ? AppColors.primary : subtext,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 24,
                          height: 24,
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
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isToday ? Colors.white : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),

          // Agent rows
          ...rows.map((agentRow) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Agent name + status dot
                  Container(
                    width: 90,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      border:
                          Border(bottom: BorderSide(color: t.dividerColor)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _statusDotColor(agentRow.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            agentRow.name,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Day cells
                  ...days.map((d) {
                    final dayShifts =
                        _shiftsForAgentDay(agentRow.shifts, d);
                    return Expanded(
                      child: GestureDetector(
                        onTap: dayShifts.isNotEmpty
                            ? () => _showShiftDetail(dayShifts.first)
                            : null,
                        onLongPress: dayShifts.isNotEmpty
                            ? () => _deleteShift(dayShifts.first)
                            : null,
                        child: Container(
                          constraints:
                              const BoxConstraints(minHeight: 50),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: t.dividerColor),
                              left: BorderSide(
                                  color: t.dividerColor,
                                  width: 0.5),
                            ),
                          ),
                          child: dayShifts.isEmpty
                              ? const SizedBox()
                              : Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: dayShifts.map((s) {
                                    final color =
                                        _shiftStatusColor(s.status);
                                    return Container(
                                      margin:
                                          const EdgeInsets.only(bottom: 2),
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color:
                                            color.withValues(alpha: 0.14),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        border: Border.all(
                                            color: color.withValues(
                                                alpha: 0.4)),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${tf.format(s.start)}-${tf.format(s.end)}',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: color,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                          if (s.role.isNotEmpty)
                                            Text(
                                              s.role,
                                              style: TextStyle(
                                                  fontSize: 7,
                                                  color: color),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Helper row model ───────────────────────────────────────────────────────

class _AgentRow {
  final String id;
  final String name;
  final String status;
  final List<_Shift> shifts;

  const _AgentRow({
    required this.id,
    required this.name,
    required this.status,
    required this.shifts,
  });
}

// ─── Add Shift Bottom Sheet ─────────────────────────────────────────────────

class _AddShiftSheet extends StatefulWidget {
  final List<_ShiftAgent> agents;
  final VoidCallback onAdded;
  const _AddShiftSheet({required this.agents, required this.onAdded});

  @override
  State<_AddShiftSheet> createState() => _AddShiftSheetState();
}

class _AddShiftSheetState extends State<_AddShiftSheet> {
  String? _selectedAgentId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  final _roleCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _roleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
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
    if (_selectedAgentId == null || _selectedAgentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an agent')),
      );
      return;
    }

    final startAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
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
      await ApiService.instance.post('/workforce/shifts', body: {
        'agentId': _selectedAgentId,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'startTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'endTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        if (_roleCtrl.text.trim().isNotEmpty) 'role': _roleCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift added'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${cleanError(e)}')),
        );
      }
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
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.paddingOf(context).bottom +
            24,
      ),
      child: SingleChildScrollView(
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add Shift',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),

            // Agent dropdown
            const Text('Agent',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedAgentId,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                hintText: 'Select agent',
              ),
              items: widget.agents
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name, style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedAgentId = v),
            ),
            const SizedBox(height: 16),

            // Date picker
            const Text('Date',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
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
                    Icon(Icons.calendar_today_outlined,
                        size: 18, color: subtext),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEE, MMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
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

            // Role
            const Text('Role (optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _roleCtrl,
              decoration: const InputDecoration(
                hintText: 'E.g. Customer Support, Sales...',
                prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
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
      ),
    );
  }
}

// ─── Shared time picker widget ──────────────────────────────────────────────

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
                Icon(Icons.access_time_rounded, size: 18, color: subtext),
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
