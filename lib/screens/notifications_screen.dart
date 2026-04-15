import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/notifications_controller.dart';
import '../models/notification.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<NotificationsController>();
    final groups = ctrl.grouped();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (ctrl.unread > 0)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark all read',
              onPressed: () async {
                await ctrl.markAll();
                if (!context.mounted) return;
                await ctrl.load();
              },
            ),
        ],
      ),
      body: ctrl.loading && ctrl.items.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : ctrl.items.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'All caught up',
                  message: 'No new notifications right now.',
                )
              : RefreshIndicator(
                  onRefresh: () => ctrl.load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: groups.length,
                    itemBuilder: (_, gi) {
                      final key = groups.keys.elementAt(gi);
                      final list = groups[key]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text(key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                          ...list.map((n) => _NotifTile(
                                n: n,
                                onTap: () {
                                  ctrl.markOne(n.id);
                                  // Navigate based on kind — for now just pop
                                },
                              )),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification n;
  final VoidCallback? onTap;
  const _NotifTile({required this.n, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final (icon, color) = _iconFor(n.kind);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              n.title,
              style: TextStyle(
                fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
          if (!n.read)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(n.body, style: TextStyle(color: subtext)),
          const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm').format(n.createdAt),
            style: TextStyle(color: subtext, fontSize: 11),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _iconFor(NotificationKind k) {
    switch (k) {
      case NotificationKind.task:
        return (Icons.assignment_rounded, AppColors.primary);
      case NotificationKind.chat:
        return (Icons.chat_bubble_rounded, AppColors.primary);
      case NotificationKind.wallet:
        return (Icons.payments_rounded, AppColors.success);
      case NotificationKind.system:
        return (Icons.info_outline_rounded, AppColors.warn);
    }
  }
}
