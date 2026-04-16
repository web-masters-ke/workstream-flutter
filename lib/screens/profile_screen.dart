import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'kyc_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'performance_screen.dart';
import 'settings_screen.dart';
import 'shifts_screen.dart';
import 'skills_picker_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final themeCtrl = context.watch<ThemeController>();
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    final initials = user?.initials.isNotEmpty == true ? user!.initials : 'WS';
    final name = user?.fullName.isNotEmpty == true ? user!.fullName : 'User';
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';
    final role = user?.role ?? '';

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // ── Header row ───────────────────────────────────
          Row(
            children: [
              Text('Profile', style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Avatar + name ────────────────────────────────────
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Avatar upload coming soon')),
                    );
                  },
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.18),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                if (email.isNotEmpty)
                  Text(email, style: TextStyle(color: subtext)),
                if (phone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(phone, style: TextStyle(color: subtext, fontSize: 13)),
                  ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (role.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: StatusPill(
                          label: role,
                          color: AppColors.primary,
                          icon: Icons.badge_rounded,
                        ),
                      ),
                    if (user?.kycVerified ?? false)
                      const StatusPill(
                        label: 'KYC verified',
                        color: AppColors.success,
                        icon: Icons.verified_rounded,
                      )
                    else
                      const StatusPill(
                        label: 'KYC pending',
                        color: AppColors.warn,
                        icon: Icons.pending_actions_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // ── Stats ────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.star_rounded,
                  label: 'Rating',
                  value: (user?.rating ?? 0).toStringAsFixed(2),
                  color: AppColors.warn,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.task_alt_rounded,
                  label: 'Done',
                  value: '${user?.tasksCompleted ?? 0}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  icon: Icons.payments_rounded,
                  label: 'Earned',
                  value: '${(user?.lifetimeEarnings ?? 0).toStringAsFixed(0)} KES',
                  color: AppColors.success,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── Skills ───────────────────────────────────────────
          Row(
            children: [
              const SectionHeader(title: 'Skills'),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const SkillsPickerScreen()),
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (user?.skills ?? []).isEmpty
                ? [_SkillChip('No skills added yet')]
                : (user?.skills ?? []).map((s) => _SkillChip(s)).toList(),
          ),

          // ── KYC prompt ───────────────────────────────────────
          if (!(user?.kycVerified ?? false)) ...[
            const SizedBox(height: 18),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const KycScreen()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warn.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.warn, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Complete KYC to enable payouts',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.warn),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 22),

          // ── Dark mode toggle ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: t.dividerColor),
              color: t.cardColor,
            ),
            child: SwitchListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Dark mode',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                isDark ? 'On' : 'Off',
                style: TextStyle(color: subtext, fontSize: 12),
              ),
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppColors.primary,
              ),
              value: themeCtrl.isDark,
              activeThumbColor: AppColors.primary,
              onChanged: (_) => themeCtrl.toggle(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Menu items ───────────────────────────────────────
          _MenuTile(
            icon: Icons.insights_rounded,
            label: 'Performance',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const PerformanceScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.calendar_month_rounded,
            label: 'My shifts',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const ShiftsScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & support',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const HelpScreen()),
            ),
          ),

          const SizedBox(height: 10),

          // ── Sign out ─────────────────────────────────────────
          _MenuTile(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            danger: true,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sign out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign out',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              if (!context.mounted) return;
              await context.read<AuthController>().logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                    builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        tileColor: Theme.of(context).cardColor,
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: color),
      ),
    );
  }
}
