import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notifications_controller.dart';
import '../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
import 'admin_tasks_screen.dart';
import 'admin_team_screen.dart';
import 'billing_screen.dart';
import 'call_screen.dart';
import 'chat_list_screen.dart';
import 'disputes_list_screen.dart';
import 'jobs_screen.dart';
import 'marketplace_screen.dart';
import 'my_listings_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'shifts_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  bool _offline = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<List<ConnectivityResult>>? _connectSub;

  static const _pages = [
    AdminDashboardScreen(),
    AdminTasksScreen(),
    ChatListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _connectSub =
        Connectivity().onConnectivityChanged.listen(_onConnectivity);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    final user = context.watch<AuthController>().user;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _AdminDrawer(
        user: user,
        subtext: subtext,
        onPush: _pushScreen,
      ),
      body: Column(
        children: [
          // ── Offline banner ────────────────────────────────────
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

          // ── Top bar ───────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
              child: Row(
                children: [
                  // Hamburger — opens admin drawer
                  IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: _openDrawer,
                    tooltip: 'Menu',
                  ),
                  const Icon(Icons.bolt_rounded,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    AppMeta.name,
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'ADMIN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: t.brightness == Brightness.dark
                            ? AppColors.darkText
                            : AppColors.primary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Notification bell
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        onPressed: () => _pushScreen(
                            const NotificationsScreen()),
                      ),
                      if (notif.unread > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Avatar
                  GestureDetector(
                    onTap: () => setState(() => _index = 3),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.18),
                      child: Text(
                        user?.initials ?? 'AD',
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

          // ── Page ─────────────────────────────────────────────
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),

      // ── Bottom nav ─────────────────────────────────────────
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
                              color:
                                  active ? AppColors.accent : subtext,
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
    _Tab('Dashboard', Icons.dashboard_outlined,  Icons.dashboard_rounded),
    _Tab('Tasks',     Icons.assignment_outlined, Icons.assignment_rounded),
    _Tab('Chat',      Icons.chat_bubble_outline, Icons.chat_bubble_rounded),
    _Tab('Profile',   Icons.person_outline,      Icons.person_rounded),
  ];
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _Tab(this.label, this.icon, this.activeIcon);
}

// ─── Admin Drawer ─────────────────────────────────────────────────────────────

class _AdminDrawer extends StatelessWidget {
  final dynamic user;
  final Color subtext;
  final void Function(Widget) onPush;

  const _AdminDrawer({
    required this.user,
    required this.subtext,
    required this.onPush,
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                        AppColors.primary.withValues(alpha: 0.3),
                    child: Text(
                      user?.initials ?? 'AD',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.name ?? 'Admin',
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

            _sectionLabel('Jobs & Work', subtext),
            _item(context, Icons.work_outline_rounded, 'Jobs',
                () => onPush(const JobsScreen())),
            _item(context, Icons.schedule_rounded, 'Shifts',
                () => onPush(const ShiftsScreen())),

            _sectionLabel('Marketplace', subtext),
            _item(context, Icons.storefront_outlined, 'Free Agents',
                () => onPush(const MarketplaceScreen())),
            _item(context, Icons.list_alt_rounded, 'My Listings',
                () => onPush(const MyListingsScreen())),

            _sectionLabel('Team', subtext),
            _item(context, Icons.groups_outlined, 'Team Members',
                () => onPush(const AdminTeamScreen())),

            _sectionLabel('Communication', subtext),
            _item(context, Icons.video_call_rounded, 'Calls', () {
              onPush(const CallScreen(contactName: 'New call'));
            }),
            _item(context, Icons.notifications_outlined, 'Notifications',
                () => onPush(const NotificationsScreen())),

            _sectionLabel('Escalations & Reports', subtext),
            _item(context, Icons.report_outlined, 'Disputes / Escalations',
                () => onPush(const DisputesListScreen())),
            _item(context, Icons.bar_chart_rounded, 'Reports',
                () => onPush(const ReportsScreen())),

            _sectionLabel('Account', subtext),
            _item(context, Icons.credit_card_rounded, 'Billing',
                () => onPush(const BillingScreen())),

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
      leading: Icon(icon, size: 20, color: AppColors.accent),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      horizontalTitleGap: 8,
    );
  }
}
