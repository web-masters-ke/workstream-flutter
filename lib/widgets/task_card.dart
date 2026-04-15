import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../theme/app_theme.dart';
import 'primitives.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  const TaskCard({super.key, required this.task, this.onTap, this.onAccept});

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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryBadge(category: task.category),
                const SizedBox(width: 8),
                StatusPill(
                  label: task.status.label,
                  color: _statusColor(task.status),
                ),
                const Spacer(),
                Text(
                  money.format(task.reward),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(color: subtext),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.business_rounded, size: 14, color: subtext),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.business?.name ?? 'WorkStream',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subtext, fontSize: 12),
                  ),
                ),
                if (task.deadline != null) ...[
                  Icon(Icons.schedule_rounded, size: 14, color: subtext),
                  const SizedBox(width: 4),
                  Text(
                    _formatDeadline(task.deadline!),
                    style: TextStyle(color: subtext, fontSize: 12),
                  ),
                ],
              ],
            ),
            if (onAccept != null && task.status == TaskStatus.available) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(38),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  child: const Text('Accept task'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDeadline(DateTime d) {
    final diff = d.difference(DateTime.now());
    if (diff.isNegative) return 'Overdue';
    if (diff.inHours < 1) return '${diff.inMinutes}m left';
    if (diff.inHours < 24) return '${diff.inHours}h left';
    return '${diff.inDays}d left';
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.available:
        return AppColors.primary;
      case TaskStatus.assigned:
        return AppColors.warn;
      case TaskStatus.inProgress:
        return AppColors.primary;
      case TaskStatus.submitted:
        return AppColors.warn;
      case TaskStatus.completed:
        return AppColors.success;
      case TaskStatus.rejected:
      case TaskStatus.cancelled:
        return AppColors.danger;
    }
  }
}

class _CategoryBadge extends StatelessWidget {
  final TaskCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (category) {
      case TaskCategory.customerSupport:
        icon = Icons.support_agent_rounded;
        break;
      case TaskCategory.sales:
        icon = Icons.trending_up_rounded;
        break;
      case TaskCategory.orderProcessing:
        icon = Icons.inventory_2_rounded;
        break;
      case TaskCategory.dataEntry:
        icon = Icons.edit_note_rounded;
        break;
      case TaskCategory.callCenter:
        icon = Icons.call_rounded;
        break;
      case TaskCategory.other:
        icon = Icons.assignment_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
