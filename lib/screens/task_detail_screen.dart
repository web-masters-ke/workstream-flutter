import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/tasks_controller.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'call_screen.dart';
import 'chat_screen.dart';
import 'dispute_screen.dart';
import 'task_submit_screen.dart';

class TaskDetailScreen extends StatelessWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final money = NumberFormat.currency(
      symbol: '${task.currency} ',
      decimalDigits: 0,
    );

    // countdown
    final left = task.timeLeft();
    String? countdown;
    if (left != null && !left.isNegative) {
      final h = left.inHours;
      final m = left.inMinutes.remainder(60);
      final s = left.inSeconds.remainder(60);
      countdown = h > 0
          ? '${h}h ${m}m remaining'
          : m > 0
              ? '${m}m ${s}s remaining'
              : '${s}s remaining';
    } else if (left != null) {
      countdown = 'Overdue';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'report') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DisputeScreen(task: task),
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Report issue'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Row(
            children: [
              StatusPill(
                label: task.category.label,
                color: AppColors.primary,
                icon: Icons.local_offer_rounded,
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: task.status.label,
                color: _statusColor(task.status),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            task.title,
            style:
                t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),

          // reward + deadline banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Reward ${money.format(task.reward)}',
                  style: const TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (countdown != null) ...[
                  const Icon(Icons.schedule_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    countdown,
                    style: TextStyle(
                      color: left!.isNegative
                          ? AppColors.danger
                          : AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // description
          const SectionHeader(title: 'Description'),
          const SizedBox(height: 8),
          Text(task.description,
              style: t.textTheme.bodyMedium?.copyWith(height: 1.5)),

          // instructions
          if (task.instructions != null) ...[
            const SizedBox(height: 18),
            const SectionHeader(title: 'Instructions'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.dividerColor),
              ),
              child: Text(task.instructions!,
                  style: t.textTheme.bodyMedium?.copyWith(height: 1.5)),
            ),
          ],
          const SizedBox(height: 18),

          // business
          const SectionHeader(title: 'Business'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.business_rounded,
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.business?.name ?? 'WorkStream',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(task.business?.industry ?? '',
                          style: TextStyle(color: subtext, fontSize: 12)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 14, color: AppColors.warn),
                    const SizedBox(width: 2),
                    Text(
                      (task.business?.rating ?? 0).toStringAsFixed(1),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // SLA
          const SectionHeader(title: 'SLA'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.schedule_rounded,
                  label: 'Deadline',
                  value: task.deadline == null
                      ? 'Flexible'
                      : DateFormat('MMM d, HH:mm').format(task.deadline!),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.timer_rounded,
                  label: 'SLA',
                  value: task.slaMinutes == null
                      ? '--'
                      : '${task.slaMinutes} min',
                  color: AppColors.warn,
                ),
              ),
            ],
          ),

          // tags
          if (task.tags.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionHeader(title: 'Tags'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: task.tags
                  .map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _ActionBar(task: task),
        ),
      ),
    );
  }

  Color _statusColor(TaskStatus s) => switch (s) {
        TaskStatus.available => AppColors.primary,
        TaskStatus.assigned => AppColors.warn,
        TaskStatus.inProgress => AppColors.primary,
        TaskStatus.submitted => AppColors.warn,
        TaskStatus.completed => AppColors.success,
        TaskStatus.rejected || TaskStatus.cancelled => AppColors.danger,
      };
}

class _ActionBar extends StatelessWidget {
  final Task task;
  const _ActionBar({required this.task});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<TasksController>();

    Future<void> wrap(Future<bool> Function() action, String ok) async {
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);
      final r = await action();
      messenger.showSnackBar(
        SnackBar(content: Text(r ? ok : ctrl.error ?? 'Failed')),
      );
      if (r) nav.maybePop();
    }

    switch (task.status) {
      case TaskStatus.available:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => wrap(
                  () => ctrl.reject(task.id, reason: 'Not interested'),
                  'Declined',
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => wrap(() => ctrl.accept(task.id), 'Accepted'),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Accept task'),
              ),
            ),
          ],
        );
      case TaskStatus.assigned:
        return Row(
          children: [
            _iconBtn(context, Icons.call_rounded, () => _openCall(context)),
            const SizedBox(width: 8),
            _iconBtn(
                context, Icons.chat_bubble_outline, () => _openChat(context)),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => wrap(() => ctrl.start(task.id), 'Started'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start work'),
              ),
            ),
          ],
        );
      case TaskStatus.inProgress:
        return Row(
          children: [
            _iconBtn(context, Icons.call_rounded, () => _openCall(context)),
            const SizedBox(width: 8),
            _iconBtn(
                context, Icons.chat_bubble_outline, () => _openChat(context)),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TaskSubmitScreen(task: task),
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Submit work'),
              ),
            ),
          ],
        );
      default:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back'),
          ),
        );
    }
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    final t = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(onPressed: onTap, icon: Icon(icon, size: 22)),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          threadId: 'task-${task.id}',
          title: task.business?.name ?? 'Business chat',
        ),
      ),
    );
  }

  void _openCall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CallScreen(
          contactName: task.business?.name ?? 'Business',
        ),
      ),
    );
  }
}
