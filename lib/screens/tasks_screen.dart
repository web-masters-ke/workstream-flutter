import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/tasks_controller.dart';
import '../models/task.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _kanbanView = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TasksController>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showFilter() {
    final ctrl = context.read<TasksController>();
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        filter: ctrl.filter,
        sort: ctrl.sort,
        onApply: (f, s) {
          ctrl.setFilter(f);
          ctrl.setSort(s);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<TasksController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          // View toggle button
          IconButton(
            icon: Icon(
              _kanbanView
                  ? Icons.view_list_rounded
                  : Icons.view_kanban_rounded,
            ),
            onPressed: () => setState(() => _kanbanView = !_kanbanView),
            tooltip: _kanbanView ? 'List view' : 'Kanban view',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilter,
            tooltip: 'Filter & sort',
          ),
        ],
        bottom: _kanbanView
            ? null
            : TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Available (${ctrl.available.length})'),
                  Tab(text: 'Assigned (${ctrl.assigned.length})'),
                  Tab(text: 'In progress (${ctrl.inProgress.length})'),
                  Tab(text: 'Completed (${ctrl.completed.length})'),
                ],
              ),
      ),
      body: _kanbanView
          ? _KanbanBoard(ctrl: ctrl)
          : RefreshIndicator(
              onRefresh: () => context.read<TasksController>().loadAll(),
              child: TabBarView(
                controller: _tabs,
                children: [
                  _TaskList(
                    tasks: ctrl.available,
                    loading: ctrl.loading,
                    error: ctrl.error,
                    onRetry: () => context.read<TasksController>().loadAll(),
                    emptyTitle: 'No tasks available',
                    emptyMessage:
                        'Pull to refresh. New tasks post throughout the day.',
                    emptyIcon: Icons.inbox_outlined,
                  ),
                  _TaskList(
                    tasks: ctrl.assigned,
                    loading: ctrl.loading,
                    emptyTitle: 'Nothing assigned',
                    emptyMessage:
                        'Pick a task from Available and we\'ll assign it to you.',
                    emptyIcon: Icons.assignment_outlined,
                  ),
                  _TaskList(
                    tasks: ctrl.inProgress,
                    loading: ctrl.loading,
                    emptyTitle: 'Nothing in progress',
                    emptyMessage: 'Start an assigned task to see it here.',
                    emptyIcon: Icons.play_circle_outline,
                  ),
                  _TaskList(
                    tasks: ctrl.completed,
                    loading: ctrl.loading,
                    emptyTitle: 'No completed tasks yet',
                    emptyMessage: 'Completed work will show up here.',
                    emptyIcon: Icons.check_circle_outline,
                  ),
                ],
              ),
            ),
      floatingActionButton: _buildFab(context),
    );
  }

  Widget? _buildFab(BuildContext context) {
    final user = context.watch<AuthController>().user;
    if (user == null || !user.isAdmin) return null;
    return FloatingActionButton.extended(
      onPressed: () => _showCreateTaskSheet(context),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New task',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  void _showCreateTaskSheet(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateTaskSheet(),
    ).then((created) {
      if (created == true && mounted) {
        context.read<TasksController>().loadAll();
      }
    });
  }
}

// ─── Kanban Board ───────────────────────────────────────────────────────────

class _KanbanBoard extends StatelessWidget {
  final TasksController ctrl;
  const _KanbanBoard({required this.ctrl});

  static const _columns = [
    ('PENDING', 'Pending', TaskStatus.available),
    ('ASSIGNED', 'Assigned', TaskStatus.assigned),
    ('IN_PROGRESS', 'In Progress', TaskStatus.inProgress),
    ('UNDER_REVIEW', 'Under Review', TaskStatus.submitted),
    ('ON_HOLD', 'On Hold', null),
    ('COMPLETED', 'Completed', TaskStatus.completed),
  ];

  List<Task> _tasksForColumn(int index) {
    switch (index) {
      case 0:
        return ctrl.available;
      case 1:
        return ctrl.assigned;
      case 2:
        return ctrl.inProgress;
      case 3:
        // "Under Review" maps to submitted tasks
        return [...ctrl.completed.where((t) => t.status == TaskStatus.submitted)];
      case 4:
        // "On Hold" — no direct mapping in existing controller, show empty
        return [];
      case 5:
        return ctrl.completed.where((t) => t.status == TaskStatus.completed).toList();
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    if (ctrl.loading &&
        ctrl.available.isEmpty &&
        ctrl.assigned.isEmpty &&
        ctrl.inProgress.isEmpty &&
        ctrl.completed.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (ctrl.error != null &&
        ctrl.available.isEmpty &&
        ctrl.assigned.isEmpty &&
        ctrl.inProgress.isEmpty &&
        ctrl.completed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(
                ctrl.error!
                    .replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), ''),
                textAlign: TextAlign.center,
                style: TextStyle(color: subtext),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ctrl.loadAll(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ctrl.loadAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_columns.length, (i) {
              final col = _columns[i];
              final tasks = _tasksForColumn(i);
              return _KanbanColumn(
                title: col.$2,
                statusKey: col.$1,
                tasks: tasks,
                subtext: subtext,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final String statusKey;
  final List<Task> tasks;
  final Color subtext;
  const _KanbanColumn({
    required this.title,
    required this.statusKey,
    required this.tasks,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final colBg = isDark
        ? AppColors.darkSurface
        : const Color(0xFFF4F4F5); // zinc-100

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: colBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _columnColor(statusKey),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _columnColor(statusKey).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _columnColor(statusKey),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Task cards
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Text(
                'No tasks',
                style: TextStyle(color: subtext, fontSize: 12),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Column(
                children: tasks.map((task) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _KanbanCard(task: task, subtext: subtext),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Color _columnColor(String s) {
    switch (s) {
      case 'PENDING':
        return AppColors.lightSubtext;
      case 'ASSIGNED':
        return AppColors.warn;
      case 'IN_PROGRESS':
        return AppColors.primary;
      case 'UNDER_REVIEW':
        return AppColors.primarySoft;
      case 'ON_HOLD':
        return AppColors.darkSubtext;
      case 'COMPLETED':
        return AppColors.success;
      default:
        return AppColors.lightSubtext;
    }
  }
}

class _KanbanCard extends StatelessWidget {
  final Task task;
  final Color subtext;
  const _KanbanCard({required this.task, required this.subtext});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(task: task),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              task.title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Assignee + priority + SLA
            Row(
              children: [
                // Assignee
                Icon(Icons.person_outline_rounded, size: 13, color: subtext),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    task.assignedAgentId ?? 'Unassigned',
                    style: TextStyle(color: subtext, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Priority badge
                _PriorityDot(task: task),
                // SLA
                if (task.slaMinutes != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.timer_outlined, size: 12, color: subtext),
                  const SizedBox(width: 2),
                  Text(
                    '${task.slaMinutes}m',
                    style: TextStyle(color: subtext, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  final Task task;
  const _PriorityDot({required this.task});

  @override
  Widget build(BuildContext context) {
    // Derive priority from tags or default
    String priority = 'LOW';
    for (final tag in task.tags) {
      final upper = tag.toUpperCase();
      if (upper == 'URGENT' || upper == 'HIGH' || upper == 'MEDIUM' || upper == 'LOW') {
        priority = upper;
        break;
      }
    }

    Color color;
    switch (priority) {
      case 'URGENT':
        color = AppColors.danger;
        break;
      case 'HIGH':
        color = const Color(0xFFEA580C);
        break;
      case 'MEDIUM':
        color = AppColors.warn;
        break;
      default:
        color = AppColors.lightSubtext;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─── Existing list view ─────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  const _TaskList({
    required this.tasks,
    required this.loading,
    this.error,
    this.onRetry,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && tasks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (error != null && tasks.isEmpty) {
      final subtext = Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSubtext
          : AppColors.lightSubtext;
      return ListView(
        padding: const EdgeInsets.only(top: 80),
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    error!.replaceFirst(RegExp(r'^ApiException\(\d+\):\s*'), ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subtext),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (tasks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: 80),
        children: [
          EmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => TaskCard(
        task: tasks[i],
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TaskDetailScreen(task: tasks[i]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Filter sheet ───────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final TaskFilter filter;
  final TaskSort sort;
  final void Function(TaskFilter, TaskSort) onApply;
  const _FilterSheet({
    required this.filter,
    required this.sort,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TaskFilter _f;
  late TaskSort _s;

  @override
  void initState() {
    super.initState();
    _f = widget.filter;
    _s = widget.sort;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.paddingOf(context).bottom),
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
          Text('Filter',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(null, 'All categories'),
              ...TaskCategory.values.map((c) => _chip(c, c.label)),
            ],
          ),
          const SizedBox(height: 20),
          Text('Sort by',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: TaskSort.values.map((s) {
              final active = _s == s;
              return ChoiceChip(
                label: Text(_sortLabel(s)),
                selected: active,
                selectedColor: AppColors.primary.withValues(alpha: 0.18),
                onSelected: (_) => setState(() => _s = s),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              widget.onApply(_f, _s);
              Navigator.of(context).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
      ),
    );
  }

  Widget _chip(TaskCategory? c, String label) {
    final active = _f.category == c;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: AppColors.primary.withValues(alpha: 0.18),
      onSelected: (_) => setState(
        () => _f = _f.copyWith(category: c, clearCategory: c == null),
      ),
    );
  }

  String _sortLabel(TaskSort s) => switch (s) {
        TaskSort.deadline => 'Deadline',
        TaskSort.rate => 'Highest pay',
        TaskSort.newest => 'Newest',
      };
}

// ─── Create Task Sheet ─────────────────────────────────────────────────────

const _kPriorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

class _CreateTaskSheet extends StatefulWidget {
  const _CreateTaskSheet();

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _slaCtrl = TextEditingController(text: '60');
  String _priority = 'MEDIUM';
  DateTime? _dueAt;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _slaCtrl.dispose();
    super.dispose();
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
      if (_dueAt != null) {
        body['dueAt'] = _dueAt!.toIso8601String();
      }
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
              WsTextField(
                controller: _titleCtrl,
                label: 'Title *',
                hint: 'e.g. Process customer refund requests',
                icon: Icons.title_rounded,
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Title required (3+ chars)' : null,
              ),
              const SizedBox(height: 14),

              // Description
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text('Description',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? AppColors.darkText : AppColors.lightText)),
              ),
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
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text('Priority',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? AppColors.darkText : AppColors.lightText)),
              ),
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
              WsTextField(
                controller: _slaCtrl,
                label: 'SLA (minutes)',
                hint: '60',
                icon: Icons.timer_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),

              // Due date
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text('Due date',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? AppColors.darkText : AppColors.lightText)),
              ),
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
