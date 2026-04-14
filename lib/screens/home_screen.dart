import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/notifications_controller.dart';
import '../controllers/tasks_controller.dart';
import '../controllers/wallet_controller.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import '../widgets/task_card.dart';
import 'chat_list_screen.dart';
import 'notifications_screen.dart';
import 'performance_screen.dart';
import 'task_detail_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _deadlineTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tc = context.read<TasksController>();
      tc.loadCached().then((_) => tc.loadAll());
      context.read<WalletController>().load();
      context.read<NotificationsController>().load();
    });
    _deadlineTicker = Timer.periodic(
        const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _deadlineTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final tasks = context.watch<TasksController>();
    final wallet = context.watch<WalletController>();
    final notif = context.watch<NotificationsController>();

    final balance = wallet.wallet?.balance ?? 0;
    final tasksDone = tasks.completed.length;
    final rating = user?.rating ?? 4.72;

    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    final nearest = tasks.upcomingDeadline;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final tc = context.read<TasksController>();
            final wc = context.read<WalletController>();
            await tc.loadAll();
            await wc.load();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              // -- header
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                    child: Text(
                      user?.initials ?? 'DA',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(),
                            style: TextStyle(fontSize: 12, color: subtext)),
                        Text(
                          user?.firstName.isNotEmpty == true
                              ? user!.firstName
                              : 'Agent',
                          style: t.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                      if (notif.unread > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${notif.unread > 9 ? '9+' : notif.unread}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // -- availability toggle
              _AvailabilityCard(
                online: user?.available ?? false,
                onToggle: () => auth.toggleAvailability(),
              ),
              const SizedBox(height: 18),

              // -- stats
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.payments_rounded,
                      label: 'Balance',
                      value:
                          '${NumberFormat.currency(symbol: '', decimalDigits: 0).format(balance)} KES',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.task_alt_rounded,
                      label: 'Tasks done',
                      value: '$tasksDone',
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.star_rounded,
                      label: 'Rating',
                      value: rating.toStringAsFixed(2),
                      color: AppColors.warn,
                    ),
                  ),
                ],
              ),

              // -- nearest deadline
              if (nearest.isNotEmpty) ...[
                const SizedBox(height: 18),
                _DeadlineBanner(task: nearest.first),
              ],

              // -- quick links
              const SizedBox(height: 18),
              Row(
                children: [
                  _QuickLink(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Wallet',
                    color: AppColors.success,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const WalletScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QuickLink(
                    icon: Icons.insights_rounded,
                    label: 'Performance',
                    color: AppColors.accent,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const PerformanceScreen()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QuickLink(
                    icon: Icons.chat_bubble_rounded,
                    label: 'Chat',
                    color: AppColors.warn,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const ChatListScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // -- featured tasks
              SectionHeader(
                title: 'Featured tasks',
                actionLabel: 'See all',
                onAction: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Available tasks')),
                        body: const _AllAvailableList(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              if (tasks.loading && tasks.available.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else if (tasks.available.isEmpty)
                const EmptyState(
                  icon: Icons.inbox_rounded,
                  title: 'No tasks right now',
                  message:
                      'Check back in a few minutes — new tasks post throughout the day.',
                )
              else
                ...tasks.available.take(3).map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TaskCard(
                          task: task,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TaskDetailScreen(task: task),
                            ),
                          ),
                          onAccept: () =>
                              context.read<TasksController>().accept(task.id),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _AllAvailableList extends StatelessWidget {
  const _AllAvailableList();

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TasksController>().available;
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => TaskCard(
        task: tasks[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskDetailScreen(task: tasks[i]),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final bool online;
  final VoidCallback onToggle;
  const _AvailabilityCard({required this.online, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: online ? AppColors.success : AppColors.darkSubtext,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  online ? 'You are online' : 'You are offline',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  online
                      ? 'You can receive new task offers.'
                      : 'Toggle online to receive tasks.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: online,
            onChanged: (_) => onToggle(),
            activeThumbColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _DeadlineBanner extends StatelessWidget {
  final Task task;
  const _DeadlineBanner({required this.task});

  @override
  Widget build(BuildContext context) {
    final left = task.timeLeft();
    if (left == null) return const SizedBox.shrink();
    final urgent = left.inMinutes < 60;
    final label = left.isNegative
        ? 'Overdue'
        : left.inHours > 0
            ? '${left.inHours}h ${left.inMinutes.remainder(60)}m left'
            : '${left.inMinutes}m left';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (urgent ? AppColors.danger : AppColors.warn).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (urgent ? AppColors.danger : AppColors.warn).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined,
              size: 20, color: urgent ? AppColors.danger : AppColors.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${task.title} — $label',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: urgent ? AppColors.danger : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.dividerColor),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
