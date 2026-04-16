import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CallsScreen — the main "Calls" page with Upcoming / History tabs + FAB
// ═══════════════════════════════════════════════════════════════════════════════

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _scheduleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ScheduleMeetingSheet(
        onScheduled: () {
          Navigator.pop(ctx);
          setState(() {}); // force children to re-fetch
        },
      ),
    );
  }

  Future<void> _startInstant() async {
    try {
      final resp = await ApiService.instance.post(
        '/communication/calls',
        body: {'type': 'VIDEO'},
      );
      final data = unwrap<Map<String, dynamic>>(resp);
      final url = data['meetingUrl']?.toString() ??
          data['jitsiUrl']?.toString() ??
          data['url']?.toString();
      if (url != null && url.isNotEmpty && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CallScreen(
              contactName: 'Instant Meeting',
              meetingUrl: url,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scheduleSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.event_rounded, color: Colors.white),
        label: const Text('Schedule',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // ── Instant meeting button ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _startInstant,
                icon: const Icon(Icons.video_call_rounded),
                label: const Text('Start instant meeting'),
              ),
            ),
          ),

          // ── Tab content ─────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _UpcomingTab(key: ValueKey('upcoming_${DateTime.now().millisecondsSinceEpoch}')),
                _HistoryTab(key: ValueKey('history_${DateTime.now().millisecondsSinceEpoch}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data model for a call record ─────────────────────────────────────────────

class _CallRecord {
  final String id;
  final String title;
  final DateTime scheduledAt;
  final DateTime? endedAt;
  final String status; // SCHEDULED, IN_PROGRESS, COMPLETED, MISSED, FAILED, CANCELLED
  final int participantCount;
  final String? meetingUrl;
  final String? recurrence;
  final int? durationMinutes;

  _CallRecord({
    required this.id,
    required this.title,
    required this.scheduledAt,
    this.endedAt,
    required this.status,
    required this.participantCount,
    this.meetingUrl,
    this.recurrence,
    this.durationMinutes,
  });

  factory _CallRecord.fromJson(Map<String, dynamic> j) {
    int pCount = 0;
    if (j['participantCount'] is num) {
      pCount = (j['participantCount'] as num).toInt();
    } else if (j['participants'] is List) {
      pCount = (j['participants'] as List).length;
    }

    int? dur;
    if (j['durationMinutes'] is num) {
      dur = (j['durationMinutes'] as num).toInt();
    } else if (j['duration'] is num) {
      dur = (j['duration'] as num).toInt();
    }

    return _CallRecord(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Untitled call',
      scheduledAt: DateTime.tryParse(j['scheduledAt']?.toString() ?? '') ??
          DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      endedAt: DateTime.tryParse(j['endedAt']?.toString() ?? ''),
      status: j['status']?.toString() ?? 'SCHEDULED',
      participantCount: pCount,
      meetingUrl: j['meetingUrl']?.toString() ??
          j['jitsiUrl']?.toString() ??
          j['url']?.toString(),
      recurrence: j['recurrence']?.toString(),
      durationMinutes: dur,
    );
  }
}

// ─── Upcoming Tab ─────────────────────────────────────────────────────────────

class _UpcomingTab extends StatefulWidget {
  const _UpcomingTab({super.key});

  @override
  State<_UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends State<_UpcomingTab> {
  List<_CallRecord> _calls = [];
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
      final resp = await ApiService.instance.get('/communication/calls/scheduled');
      final data = unwrap<dynamic>(resp);
      final list = _extractList(data);
      _calls = list
          .whereType<Map<String, dynamic>>()
          .map(_CallRecord.fromJson)
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    } catch (e) {
      _calls = [];
      _error = cleanError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancelCall(String id) async {
    try {
      await ApiService.instance.patch(
        '/communication/calls/$id',
        body: {'status': 'CANCELLED'},
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_calls.isEmpty) {
      return const EmptyState(
        icon: Icons.event_available_rounded,
        title: 'No upcoming calls',
        message: 'Schedule a meeting to get started.',
      );
    }

    // Group calls by date bucket
    final grouped = _groupByDate(_calls);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: grouped.length,
        itemBuilder: (_, i) {
          final group = grouped[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dateGroupLabel(group.label),
              ...group.calls.map((c) => _UpcomingCallCard(
                    call: c,
                    onStart: () => _startCall(c),
                    onCopyLink: () => _copyLink(c),
                    onCancel: () => _cancelCall(c.id),
                  )),
            ],
          );
        },
      ),
    );
  }

  void _startCall(_CallRecord call) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CallScreen(
          contactName: call.title,
          meetingUrl: call.meetingUrl,
        ),
      ),
    );
  }

  void _copyLink(_CallRecord call) {
    final url = call.meetingUrl;
    if (url != null && url.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting link copied')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No meeting link available')),
      );
    }
  }

  Widget _dateGroupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─── Upcoming Call Card ───────────────────────────────────────────────────────

class _UpcomingCallCard extends StatelessWidget {
  final _CallRecord call;
  final VoidCallback onStart;
  final VoidCallback onCopyLink;
  final VoidCallback onCancel;

  const _UpcomingCallCard({
    required this.call,
    required this.onStart,
    required this.onCopyLink,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final timeStr = DateFormat('h:mm a').format(call.scheduledAt);
    final dateStr = DateFormat('EEE, MMM d').format(call.scheduledAt);
    final countdown = _countdownLabel(call.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + status
          Row(
            children: [
              Expanded(
                child: Text(
                  call.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusPill(
                label: call.status.replaceAll('_', ' '),
                color: _statusColor(call.status),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Date, time, participants
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 14, color: subtext),
              const SizedBox(width: 4),
              Text('$dateStr at $timeStr',
                  style: TextStyle(color: subtext, fontSize: 13)),
              const Spacer(),
              Icon(Icons.people_outline_rounded,
                  size: 14, color: subtext),
              const SizedBox(width: 4),
              Text('${call.participantCount}',
                  style: TextStyle(color: subtext, fontSize: 13)),
            ],
          ),

          // Countdown
          if (countdown != null) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warn.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                countdown,
                style: const TextStyle(
                  color: AppColors.warn,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],

          if (call.recurrence != null &&
              call.recurrence != 'NONE' &&
              call.recurrence!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.repeat_rounded, size: 14, color: subtext),
                const SizedBox(width: 4),
                Text(call.recurrence!,
                    style: TextStyle(color: subtext, fontSize: 12)),
              ],
            ),
          ],

          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.video_call_rounded, size: 18),
                  label: const Text('Start'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _actionIcon(Icons.link_rounded, 'Copy link', onCopyLink, t),
              const SizedBox(width: 4),
              _actionIcon(
                  Icons.cancel_outlined, 'Cancel', onCancel, t,
                  color: AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(
      IconData icon, String tooltip, VoidCallback onTap, ThemeData t,
      {Color? color}) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 20, color: color ?? t.iconTheme.color),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: t.dividerColor),
        ),
        minimumSize: const Size(38, 38),
      ),
    );
  }

  String? _countdownLabel(DateTime when) {
    final diff = when.difference(DateTime.now());
    if (diff.isNegative) return 'Started';
    if (diff.inMinutes < 60) return 'Starts in ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Starts in ${diff.inHours}h';
    if (diff.inDays < 2) return 'Starts tomorrow';
    return null;
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({super.key});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<_CallRecord> _calls = [];
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
      final resp = await ApiService.instance.get('/communication/calls');
      final data = unwrap<dynamic>(resp);
      final list = _extractList(data);
      _calls = list
          .whereType<Map<String, dynamic>>()
          .map(_CallRecord.fromJson)
          .where((c) =>
              c.status == 'COMPLETED' ||
              c.status == 'MISSED' ||
              c.status == 'FAILED' ||
              c.status == 'CANCELLED')
          .toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
    } catch (e) {
      _calls = [];
      _error = cleanError(e);
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
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_calls.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No call history',
        message: 'Past calls will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: _calls.length,
        itemBuilder: (_, i) {
          final c = _calls[i];
          final dateStr = DateFormat('MMM d, yyyy').format(c.scheduledAt);
          final timeStr = DateFormat('h:mm a').format(c.scheduledAt);
          final duration = c.durationMinutes != null
              ? '${c.durationMinutes}min'
              : (c.endedAt != null
                  ? '${c.endedAt!.difference(c.scheduledAt).inMinutes}min'
                  : '--');

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor(c.status).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _historyIcon(c.status),
                    color: _statusColor(c.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('$dateStr at $timeStr',
                          style:
                              TextStyle(color: subtext, fontSize: 12)),
                    ],
                  ),
                ),
                // Duration + badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(duration,
                        style: TextStyle(
                            color: subtext,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    StatusPill(
                      label: c.status,
                      color: _statusColor(c.status),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _historyIcon(String status) {
    return switch (status) {
      'COMPLETED' => Icons.call_rounded,
      'MISSED' => Icons.call_missed_rounded,
      'FAILED' => Icons.call_end_rounded,
      'CANCELLED' => Icons.cancel_outlined,
      _ => Icons.call_rounded,
    };
  }
}

// ─── Schedule Meeting Sheet ───────────────────────────────────────────────────

class _ScheduleMeetingSheet extends StatefulWidget {
  final VoidCallback onScheduled;
  const _ScheduleMeetingSheet({required this.onScheduled});

  @override
  State<_ScheduleMeetingSheet> createState() => _ScheduleMeetingSheetState();
}

class _ScheduleMeetingSheetState extends State<_ScheduleMeetingSheet> {
  final _titleCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _time = TimeOfDay.fromDateTime(
      DateTime.now().add(const Duration(hours: 1)));
  String _recurrence = 'NONE';
  bool _saving = false;

  static const _recurrenceOptions = [
    'NONE',
    'DAILY',
    'WEEKLY',
    'MONTHLY',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _schedule() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a meeting title')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final scheduledAt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );
      final body = <String, dynamic>{
        'title': title,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        'type': 'VIDEO',
      };
      if (_recurrence != 'NONE') {
        body['recurrence'] = _recurrence;
      }

      await ApiService.instance.post('/communication/calls', body: body);
      widget.onScheduled();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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

            // Title
            Row(
              children: [
                Text('Schedule Meeting',
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Meeting title
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Meeting title',
                hintText: 'e.g. Team standup',
                prefixIcon:
                    const Icon(Icons.title_rounded, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Date & Time row
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    icon: Icons.calendar_today_rounded,
                    label: DateFormat('EEE, MMM d').format(_date),
                    onTap: _pickDate,
                    t: t,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pickerTile(
                    icon: Icons.access_time_rounded,
                    label: _time.format(context),
                    onTap: _pickTime,
                    t: t,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Recurrence dropdown
            DropdownButtonFormField<String>(
              initialValue: _recurrence,
              items: _recurrenceOptions.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r == 'NONE'
                      ? 'No recurrence'
                      : '${r[0]}${r.substring(1).toLowerCase()}'),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _recurrence = v);
              },
              decoration: InputDecoration(
                labelText: 'Recurrence',
                prefixIcon:
                    const Icon(Icons.repeat_rounded, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: t.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Schedule button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _schedule,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Schedule Meeting'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData t,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Color _statusColor(String status) {
  return switch (status) {
    'SCHEDULED' || 'IN_PROGRESS' => AppColors.primary,
    'COMPLETED' => AppColors.success,
    'MISSED' => AppColors.warn,
    'FAILED' => AppColors.danger,
    'CANCELLED' => AppColors.danger,
    _ => AppColors.primary,
  };
}

List<dynamic> _extractList(dynamic data) {
  if (data is List) return data;
  if (data is Map) {
    if (data['items'] is List) return data['items'] as List;
    if (data['calls'] is List) return data['calls'] as List;
    if (data['data'] is List) return data['data'] as List;
  }
  return [];
}

class _DateGroup {
  final String label;
  final List<_CallRecord> calls;
  _DateGroup(this.label, this.calls);
}

List<_DateGroup> _groupByDate(List<_CallRecord> calls) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final endOfWeek = today.add(Duration(days: 7 - now.weekday));

  final todayCalls = <_CallRecord>[];
  final tomorrowCalls = <_CallRecord>[];
  final thisWeekCalls = <_CallRecord>[];
  final laterCalls = <_CallRecord>[];

  for (final c in calls) {
    final d = DateTime(
        c.scheduledAt.year, c.scheduledAt.month, c.scheduledAt.day);
    if (d == today) {
      todayCalls.add(c);
    } else if (d == tomorrow) {
      tomorrowCalls.add(c);
    } else if (d.isAfter(today) && d.isBefore(endOfWeek)) {
      thisWeekCalls.add(c);
    } else {
      laterCalls.add(c);
    }
  }

  final groups = <_DateGroup>[];
  if (todayCalls.isNotEmpty) groups.add(_DateGroup('Today', todayCalls));
  if (tomorrowCalls.isNotEmpty) {
    groups.add(_DateGroup('Tomorrow', tomorrowCalls));
  }
  if (thisWeekCalls.isNotEmpty) {
    groups.add(_DateGroup('This Week', thisWeekCalls));
  }
  if (laterCalls.isNotEmpty) groups.add(_DateGroup('Later', laterCalls));
  return groups;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CallScreen — the active call-in-progress UI (launched when joining a call)
// ═══════════════════════════════════════════════════════════════════════════════

enum _CallState { preparing, launched, error }

/// Full-screen call UI.
///
/// If [meetingUrl] is provided the call is a real JaaS/Jitsi session:
///   - we launch the URL in the device browser immediately
///   - the screen stays open as a "return" anchor while the user is in-call
///
/// If no meetingUrl: start a backend call session for the contact (by
/// threadId/contactId), get back a JaaS token + url, then launch.
class CallScreen extends StatefulWidget {
  final String contactName;
  final String? meetingUrl;
  final String? threadId;

  const CallScreen({
    super.key,
    required this.contactName,
    this.meetingUrl,
    this.threadId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  _CallState _state = _CallState.preparing;
  String? _resolvedUrl;
  String? _errorMsg;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.meetingUrl != null && widget.meetingUrl!.isNotEmpty) {
      _resolvedUrl = widget.meetingUrl;
      await _launch();
      return;
    }

    // No URL provided — create a call session via backend
    try {
      final resp = await ApiService.instance.post('/communication/calls', body: {
        if (widget.threadId != null) 'threadId': widget.threadId,
        'type': 'VIDEO',
      });
      final data = unwrap<Map<String, dynamic>>(resp);
      final url = data['meetingUrl']?.toString() ??
          data['jitsiUrl']?.toString() ??
          data['url']?.toString();
      if (url == null || url.isEmpty) {
        throw Exception('No meeting URL returned by server');
      }
      _resolvedUrl = url;
      await _launch();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _CallState.error;
        _errorMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _launch() async {
    final url = _resolvedUrl!;
    // Open in Chrome Custom Tab (supports WebRTC, feels in-app)
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.inAppBrowserView,
    );
    if (!mounted) return;
    if (launched) {
      setState(() => _state = _CallState.launched);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
      });
    } else {
      // Fallback to external browser
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() => _state = _CallState.launched);
    }
  }

  void _endCall() {
    _timer?.cancel();
    if (mounted) Navigator.pop(context);
  }

  String get _timeLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // If call is launched, it's open in Chrome Custom Tab — show in-call UI

    return Scaffold(
      backgroundColor: AppColors.primaryDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── Back / close ───────────────────────────────────
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Spacer(flex: 2),

            // ── Avatar ─────────────────────────────────────────
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              child: Text(
                widget.contactName.isNotEmpty
                    ? widget.contactName[0].toUpperCase()
                    : 'C',
                style: const TextStyle(
                    fontSize: 36,
                    color: Colors.white,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.contactName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),

            // ── Status label ───────────────────────────────────
            if (_state == _CallState.preparing)
              Text(
                'Starting call...',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 15),
              )
            else if (_state == _CallState.launched)
              Text(
                'In call · $_timeLabel',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 15),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMsg ?? 'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.danger.withValues(alpha: 0.9),
                      fontSize: 14),
                ),
              ),

            if (_state == _CallState.preparing)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.5)),
                  ),
                ),
              ),

            const Spacer(flex: 3),

            // ── Action buttons ─────────────────────────────────
            if (_state == _CallState.launched)
              Column(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      if (_resolvedUrl != null) {
                        launchUrl(Uri.parse(_resolvedUrl!), mode: LaunchMode.inAppBrowserView);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
                    label: const Text('Re-open meeting', style: TextStyle(color: AppColors.primary)),
                  ),
                  const SizedBox(height: 16),
                  _endBtn('End call'),
                ],
              )
            else if (_state == _CallState.error)
              Column(
                children: [
                  TextButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.primary),
                    label: const Text(
                      'Retry',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _endBtn('Go back'),
                ],
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _endBtn(String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.call_end_rounded,
                color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
      ],
    );
  }
}
