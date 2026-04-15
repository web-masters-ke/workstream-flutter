import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notifications_controller.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'call_screen.dart';
import 'chat_list_screen.dart';
import 'disputes_list_screen.dart';
import 'earnings_statement_screen.dart';
import 'home_screen.dart';
import 'marketplace_screen.dart';
import 'my_bids_screen.dart';
import 'notifications_screen.dart';
import 'performance_screen.dart';
import 'profile_screen.dart';
import 'shifts_screen.dart';
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

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  StreamSubscription<List<ConnectivityResult>>? _connectSub;

  static const _pages = [
    HomeScreen(),
    TasksScreen(),
    MarketplaceScreen(),
    ChatListScreen(),
    WalletScreen(),
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

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _pushScreen(Widget screen) {
    _scaffoldKey.currentState?.closeDrawer();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
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
      key: _scaffoldKey,
      drawer: _AgentDrawer(
        user: user,
        subtext: subtext,
        onPush: _pushScreen,
        onClose: () => _scaffoldKey.currentState?.closeDrawer(),
      ),
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

          // ── Top bar (hamburger + workspace + availability + avatar) ─
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
              child: Row(
                children: [
                  // Hamburger — opens agent drawer
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: _openDrawer,
                    tooltip: 'Menu',
                  ),
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.primary, size: 20),
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
                  // Avatar — taps to profile
                  GestureDetector(
                    onTap: () => _pushScreen(const ProfileScreen()),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.18),
                      child: Text(
                        user?.initials ?? 'WS',
                        style: const TextStyle(
                          color: AppColors.primary,
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

      // ── Bottom navigation ───────────────────────────────────────
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
              children: List.generate(_pages.length, (i) {
                final data = _tabs[i];
                final active = _index == i;
                final isChat = i == 3;
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
                                    ? AppColors.primary
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
                              color: active ? AppColors.primary : subtext,
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
    _Tab('Home',   Icons.home_outlined,                   Icons.home_rounded),
    _Tab('Tasks',  Icons.assignment_outlined,             Icons.assignment_rounded),
    _Tab('Market', Icons.storefront_outlined,             Icons.storefront_rounded),
    _Tab('Chat',   Icons.chat_bubble_outline,             Icons.chat_bubble_rounded),
    _Tab('Wallet', Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded),
  ];
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _Tab(this.label, this.icon, this.activeIcon);
}

// ─── Agent Drawer ─────────────────────────────────────────────────────────────

class _AgentDrawer extends StatelessWidget {
  final dynamic user;
  final Color subtext;
  final void Function(Widget) onPush;
  final VoidCallback onClose;

  const _AgentDrawer({
    required this.user,
    required this.subtext,
    required this.onPush,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    return Drawer(
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDeep, AppColors.primarySoft],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      user?.initials ?? 'WS',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.name ?? 'Agent',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            _sectionLabel('Marketplace', subtext),
            _item(context, Icons.storefront_outlined, 'Browse listings',
                () => onPush(const MarketplaceScreen())),
            _item(context, Icons.gavel_rounded, 'My Bids',
                () => onPush(const MyBidsScreen())),

            _sectionLabel('Work', subtext),
            _item(context, Icons.schedule_rounded, 'My Shifts',
                () => onPush(const ShiftsScreen())),
            _item(context, Icons.task_alt_rounded, 'Earnings & Statement',
                () => onPush(const EarningsStatementScreen())),
            _item(context, Icons.trending_up_rounded, 'Performance',
                () => onPush(const PerformanceScreen())),

            _sectionLabel('Communication', subtext),
            _item(context, Icons.video_call_rounded, 'Calls', () {
              onPush(const CallScreen(contactName: 'New call'));
            }),
            _item(context, Icons.notifications_outlined, 'Notifications',
                () => onPush(const NotificationsScreen())),

            _sectionLabel('Support', subtext),
            _item(context, Icons.report_outlined, 'Disputes / Escalations',
                () => onPush(const DisputesListScreen())),

            const Divider(height: 24),

            _item(context, Icons.person_outline, 'Profile',
                () => onPush(const ProfileScreen())),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color subtext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: subtext,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _item(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppColors.primary),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      horizontalTitleGap: 8,
    );
  }
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
                      color: AppColors.primary)
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
