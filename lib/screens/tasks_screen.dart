import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/tasks_controller.dart';
import '../models/task.dart';
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
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilter,
            tooltip: 'Filter & sort',
          ),
        ],
        bottom: TabBar(
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
      body: RefreshIndicator(
        onRefresh: () => context.read<TasksController>().loadAll(),
        child: TabBarView(
          controller: _tabs,
          children: [
            _TaskList(
              tasks: ctrl.available,
              loading: ctrl.loading,
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
    );
  }
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final bool loading;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  const _TaskList({
    required this.tasks,
    required this.loading,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                selectedColor: AppColors.accent.withValues(alpha: 0.18),
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
    );
  }

  Widget _chip(TaskCategory? c, String label) {
    final active = _f.category == c;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: AppColors.accent.withValues(alpha: 0.18),
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
