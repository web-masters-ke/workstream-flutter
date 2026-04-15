import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'admin_task_detail_screen.dart';

// ─── Simple agent model for the dropdown ────────────────────────────────────

class _Agent {
  final String id;
  final String name;
  final String email;
  _Agent({required this.id, required this.name, required this.email});

  factory _Agent.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map<String, dynamic> : j;
    final fn = (user['firstName'] ?? j['firstName'])?.toString() ?? '';
    final ln = (user['lastName'] ?? j['lastName'])?.toString() ?? '';
    final email = (user['email'] ?? j['email'])?.toString() ?? '';
    var name = '$fn $ln'.trim();
    if (name.isEmpty) name = j['name']?.toString() ?? email;
    if (name.isEmpty) name = 'Agent';
    return _Agent(id: j['id']?.toString() ?? '', name: name, email: email);
  }
}

class _Task {
  final String id;
  final String title;
  final String status;
  final String? agentName;
  final String? priority;
  final DateTime? createdAt;
  final DateTime? deadline;

  _Task({
    required this.id,
    required this.title,
    required this.status,
    this.agentName,
    this.priority,
    this.createdAt,
    this.deadline,
  });

  factory _Task.fromJson(Map<String, dynamic> j) {
    DateTime? dt(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    String? agentName;
    if (j['agent'] is Map) {
      final a = j['agent'] as Map;
      final fn = a['firstName']?.toString() ?? '';
      final ln = a['lastName']?.toString() ?? '';
      agentName = '$fn $ln'.trim();
      if (agentName.isEmpty) agentName = null;
    } else if (j['agentName'] != null) {
      agentName = j['agentName'].toString();
    }

    return _Task(
      id: j['id']?.toString() ?? '',
      title: j['title']?.toString() ?? 'Untitled',
      status: j['status']?.toString() ?? 'PENDING',
      agentName: agentName,
      priority: j['priority']?.toString(),
      createdAt: dt(j['createdAt']),
      deadline: dt(j['deadline'] ?? j['dueDate']),
    );
  }
}

const _statuses = ['ALL', 'PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  List<_Task> _tasks = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'ALL';

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
      final query = <String, dynamic>{'limit': '100'};
      if (_statusFilter != 'ALL') query['status'] = _statusFilter;
      final resp = await ApiService.instance.get('/tasks', query: query);
      final data = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else if (data is Map && data['tasks'] is List) {
        list = data['tasks'] as List;
      } else {
        list = [];
      }
      setState(() {
        _tasks = list
            .whereType<Map<String, dynamic>>()
            .map(_Task.fromJson)
            .toList();
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
      appBar: AppBar(
        title: const Text('All Tasks'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text('${_tasks.length}'),
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              labelStyle: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status filter chips ─────────────────────────────
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final active = _statusFilter == s;
                return FilterChip(
                  label: Text(s),
                  selected: active,
                  onSelected: (_) {
                    setState(() => _statusFilter = s);
                    _load();
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                    color: active ? AppColors.primary : subtext,
                  ),
                );
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5))
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
                                style: const TextStyle(
                                    color: AppColors.danger)),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _tasks.isEmpty
                        ? const EmptyState(
                            icon: Icons.assignment_outlined,
                            title: 'No tasks',
                            message: 'Tasks will appear here.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.only(bottom: 80),
                              itemCount: _tasks.length,
                              itemBuilder: (_, i) =>
                                  _TaskTile(
                                    task: _tasks[i],
                                    onDelete: () => _confirmDelete(_tasks[i]),
                                    onTap: () => _openTask(_tasks[i]),
                                  ),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New task',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _confirmDelete(_Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Are you sure you want to delete "${task.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.instance.delete('/tasks/${task.id}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanError(e)),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openTask(_Task task) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminTaskDetailScreen(taskId: task.id),
      ),
    );
  }

  void _showCreateSheet() {
    showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AdminCreateTaskSheet(),
    ).then((created) {
      if (created == true && mounted) _load();
    });
  }
}

class _TaskTile extends StatelessWidget {
  final _Task task;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  const _TaskTile({required this.task, this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    final (statusColor, statusBg) = _statusColors(task.status);

    return ListTile(
      onTap: onTap,
      onLongPress: onDelete,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      trailing: onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger, size: 20),
              onPressed: onDelete,
              tooltip: 'Delete task',
            )
          : null,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: statusBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_statusIcon(task.status), color: statusColor, size: 20),
      ),
      title: Text(
        task.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  task.status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              if (task.priority != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _priorityColor(task.priority!)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priority!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _priorityColor(task.priority!),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (task.agentName != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  task.agentName!,
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ],
            ),
          ],
          if (task.deadline != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 12, color: subtext),
                const SizedBox(width: 3),
                Text(
                  DateFormat('MMM d, y').format(task.deadline!),
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color) _statusColors(String s) {
    switch (s) {
      case 'COMPLETED':
        return (AppColors.success,
            AppColors.success.withValues(alpha: 0.12));
      case 'IN_PROGRESS':
        return (AppColors.primary, AppColors.primary.withValues(alpha: 0.12));
      case 'CANCELLED':
        return (AppColors.danger, AppColors.danger.withValues(alpha: 0.12));
      default:
        return (AppColors.warn, AppColors.warn.withValues(alpha: 0.12));
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'IN_PROGRESS':
        return Icons.autorenew_rounded;
      case 'CANCELLED':
        return Icons.cancel_rounded;
      default:
        return Icons.pending_rounded;
    }
  }

  Color _priorityColor(String p) {
    switch (p.toUpperCase()) {
      case 'HIGH':
      case 'URGENT':
        return AppColors.danger;
      case 'MEDIUM':
        return AppColors.warn;
      default:
        return AppColors.lightSubtext;
    }
  }
}

// ─── Admin Create Task Sheet ───────────────────────────────────────────────

const _kPriorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

class _AdminCreateTaskSheet extends StatefulWidget {
  const _AdminCreateTaskSheet();

  @override
  State<_AdminCreateTaskSheet> createState() => _AdminCreateTaskSheetState();
}

class _AdminCreateTaskSheetState extends State<_AdminCreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _slaCtrl = TextEditingController(text: '60');
  String _priority = 'MEDIUM';
  DateTime? _dueAt;
  String? _selectedAgentId;
  String? _selectedAgentName;
  String? _businessId;
  List<_Agent> _agents = [];
  bool _loadingAgents = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgents();
    _loadBusinessId();
  }

  Future<void> _loadBusinessId() async {
    try {
      final resp = await ApiService.instance.get('/businesses');
      final data = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else {
        list = [];
      }
      if (list.isNotEmpty && list.first is Map) {
        if (mounted) setState(() => _businessId = (list.first as Map)['id']?.toString());
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _slaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    try {
      final resp = await ApiService.instance.get('/agents', query: {'limit': '100'});
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
      if (!mounted) return;
      setState(() {
        _agents = list
            .whereType<Map<String, dynamic>>()
            .map(_Agent.fromJson)
            .toList();
        _loadingAgents = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAgents = false);
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueAt ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _showAgentPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AgentPickerSheet(
        agents: _agents,
        selected: _selectedAgentId,
        onPicked: (id, name) {
          setState(() {
            _selectedAgentId = id;
            _selectedAgentName = name;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'priority': _priority,
        'slaMinutes': int.tryParse(_slaCtrl.text.trim()) ?? 60,
      };
      if (_businessId != null) body['businessId'] = _businessId;
      if (_dueAt != null) body['dueAt'] = _dueAt!.toIso8601String();
      if (_selectedAgentId != null) body['assignedAgentId'] = _selectedAgentId;
      await ApiService.instance.post('/tasks', body: body);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task created'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _error = cleanError(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomNav = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset + bottomNav),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              Text('New task',
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),

              // Title
              _label('Title *', isDark),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleCtrl,
                maxLength: 120,
                decoration: const InputDecoration(
                  hintText: 'e.g. Process customer refund requests',
                  counterText: '',
                  prefixIcon: Icon(Icons.title_rounded, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Title required (3+ chars)' : null,
              ),
              const SizedBox(height: 14),

              // Description
              _label('Description', isDark),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText: 'Describe what needs to be done...',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),

              // Priority
              _label('Priority', isDark),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kPriorities.map((p) {
                  final active = _priority == p;
                  return ChoiceChip(
                    label: Text(p),
                    selected: active,
                    selectedColor: _priorityChipColor(p).withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _priority = p),
                    labelStyle: TextStyle(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                      color: active ? _priorityChipColor(p) : subtext,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // SLA minutes
              _label('SLA (minutes)', isDark),
              const SizedBox(height: 6),
              TextFormField(
                controller: _slaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '60',
                  prefixIcon: Icon(Icons.timer_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Due date
              _label('Due date', isDark),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDueDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                    color: t.inputDecorationTheme.fillColor,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: subtext),
                      const SizedBox(width: 10),
                      Text(
                        _dueAt != null
                            ? DateFormat('MMM d, yyyy  HH:mm').format(_dueAt!)
                            : 'Select due date (optional)',
                        style: TextStyle(
                          color: _dueAt != null ? null : subtext,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      if (_dueAt != null)
                        GestureDetector(
                          onTap: () => setState(() => _dueAt = null),
                          child: Icon(Icons.close_rounded, size: 18, color: subtext),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Assign agent
              _label('Assign agent (optional)', isDark),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _loadingAgents ? null : () => _showAgentPicker(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                    color: t.inputDecorationTheme.fillColor,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18, color: subtext),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedAgentName ?? 'Unassigned',
                          style: TextStyle(
                            color: _selectedAgentName != null ? null : subtext,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_selectedAgentId != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedAgentId = null;
                            _selectedAgentName = null;
                          }),
                          child: Icon(Icons.close_rounded, size: 18, color: subtext),
                        )
                      else
                        Icon(Icons.arrow_drop_down_rounded, color: subtext),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Create button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Create',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }

  Color _priorityChipColor(String p) {
    switch (p.toUpperCase()) {
      case 'URGENT':
        return AppColors.danger;
      case 'HIGH':
        return const Color(0xFFEA580C);
      case 'MEDIUM':
        return AppColors.warn;
      default:
        return AppColors.lightSubtext;
    }
  }
}

// ─── Searchable Agent Picker Sheet ──────────────────────────────────────────

class _AgentPickerSheet extends StatefulWidget {
  final List<_Agent> agents;
  final String? selected;
  final void Function(String? id, String? name) onPicked;

  const _AgentPickerSheet({
    required this.agents,
    required this.selected,
    required this.onPicked,
  });

  @override
  State<_AgentPickerSheet> createState() => _AgentPickerSheetState();
}

class _AgentPickerSheetState extends State<_AgentPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<_Agent> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.agents;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String q) {
    final query = q.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.agents;
      } else {
        _filtered = widget.agents
            .where((a) =>
                a.name.toLowerCase().contains(query) ||
                a.email.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Select agent',
                      style: t.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => widget.onPicked(null, null),
                    child: const Text('Unassigned'),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filter('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            // Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtered.length} agent${_filtered.length == 1 ? '' : 's'}',
                  style: TextStyle(color: subtext, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Agent list
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text('No agents found',
                          style: TextStyle(color: subtext)),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (_, i) {
                        final a = _filtered[i];
                        final selected = a.id == widget.selected;
                        return ListTile(
                          selected: selected,
                          selectedTileColor:
                              AppColors.primary.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              a.name.isNotEmpty
                                  ? a.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          title: Text(a.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(a.email,
                              style: TextStyle(
                                  color: subtext, fontSize: 12)),
                          trailing: selected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 20)
                              : null,
                          onTap: () => widget.onPicked(a.id, a.name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
