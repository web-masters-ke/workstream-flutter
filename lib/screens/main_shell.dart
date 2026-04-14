import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notifications_controller.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'chat_list_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';
import 'wallet_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _offline = false;
  String? _globalError;
  String? _availability; // ONLINE | OFFLINE | BUSY

  StreamSubscription<List<ConnectivityResult>>? _connectSub;

  final _pages = const [
    HomeScreen(),
    TasksScreen(),
    ChatListScreen(),
    WalletScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _connectSub = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivity);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthController>().user;
      _availability = (user?.available ?? false) ? 'ONLINE' : 'OFFLINE';
      context.read<NotificationsController>().load();
    });
  }

  @override
  void dispose() {
    _connectSub?.cancel();
    super.dispose();
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final hasNet = results.any((r) => r != ConnectivityResult.none);
    if (!mounted) return;
    setState(() => _offline = !hasNet);
    if (hasNet && _offline) {
      // Was offline, now back online — reload notifications
      context.read<NotificationsController>().load();
    }
  }

  void _showAvailabilitySheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AvailabilitySheet(
        current: _availability ?? 'OFFLINE',
        onSelected: (v) async {
          setState(() => _availability = v);
          try {
            await ApiService.instance.patch('/agents/me', body: {
              'availability': v,
            });
          } catch (_) {
            // best-effort; UI already updated
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final notif = context.watch<NotificationsController>();
    final auth = context.watch<AuthController>();
    final user = auth.user;

    final avail = _availability ?? 'OFFLINE';
    final availColor = avail == 'ONLINE'
        ? AppColors.success
        : avail == 'BUSY'
            ? AppColors.warn
            : subtext;

    return Scaffold(
      body: Column(
        children: [
          // ── Offline banner ──────────────────────────────────
          if (_offline)
            Material(
              color: AppColors.danger.withValues(alpha: 0.92),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No internet connection',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Global error banner ─────────────────────────────
          if (_globalError != null)
            Material(
              color: AppColors.warn.withValues(alpha: 0.92),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _globalError!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          setState(() => _globalError = null),
                    ),
                  ],
                ),
              ),
            ),

          // ── Top bar (workspace + availability + avatar) ─────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    AppMeta.name,
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  // Availability indicator
                  GestureDetector(
                    onTap: _showAvailabilitySheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: availColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: availColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: availColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            avail,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: availColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Avatar
                  GestureDetector(
                    onTap: () => setState(() => _index = 4),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.accent.withValues(alpha: 0.18),
                      child: Text(
                        user?.initials ?? 'WS',
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Page content ────────────────────────────────────
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),

      // ── Bottom navigation ───────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: t.scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: t.dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (i) {
                final data = _tabs[i];
                final active = _index == i;
                final isChat = i == 2;
                final badgeCount = isChat ? notif.unread : 0;

                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _index = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                active ? data.activeIcon : data.icon,
                                size: 22,
                                color: active
                                    ? AppColors.accent
                                    : subtext,
                              ),
                              if (badgeCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      badgeCount > 99
                                          ? '99+'
                                          : '$badgeCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            data.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active ? AppColors.accent : subtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  static const _tabs = [
    _Tab('Home', Icons.home_outlined, Icons.home_rounded),
    _Tab('Tasks', Icons.assignment_outlined, Icons.assignment_rounded),
    _Tab('Chat', Icons.chat_bubble_outline, Icons.chat_bubble_rounded),
    _Tab(
      'Wallet',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
    ),
    _Tab('Profile', Icons.person_outline, Icons.person_rounded),
  ];
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _Tab(this.label, this.icon, this.activeIcon);
}

// ─── Availability bottom sheet ───────────────────────────────────────────────

class _AvailabilitySheet extends StatelessWidget {
  final String current;
  final ValueChanged<String> onSelected;
  const _AvailabilitySheet(
      {required this.current, required this.onSelected});

  static const _options = [
    _AvailOption('ONLINE', Icons.circle_rounded, AppColors.success,
        'Available for tasks'),
    _AvailOption('BUSY', Icons.do_not_disturb_on_rounded, AppColors.warn,
        'Working — no new tasks'),
    _AvailOption('OFFLINE', Icons.remove_circle_outline_rounded,
        AppColors.lightSubtext, 'Not available'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
          Text('Set availability',
              style: t.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ..._options.map((opt) {
            final active = current == opt.value;
            return ListTile(
              onTap: () {
                onSelected(opt.value);
                Navigator.pop(context);
              },
              leading: Icon(opt.icon, color: opt.color),
              title: Text(opt.value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(opt.subtitle),
              trailing: active
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.accent)
                  : null,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              tileColor: active
                  ? opt.color.withValues(alpha: 0.08)
                  : null,
            );
          }),
        ],
      ),
    );
  }
}

class _AvailOption {
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  const _AvailOption(this.value, this.icon, this.color, this.subtitle);
}
