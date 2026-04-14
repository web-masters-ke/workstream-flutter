import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushTasks = true;
  bool _pushChat = true;
  bool _pushPayout = true;
  bool _smsTasks = false;
  bool _emailDigest = true;
  bool _mfa = false;

  void _showChangePassword() {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change password',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              TextFormField(
                controller: currentPw,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPw,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.lock_reset, size: 20),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final auth = context.read<AuthController>();
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  final ok = await auth.changePassword(
                    current: currentPw.text,
                    next: newPw.text,
                  );
                  if (!ctx.mounted) return;
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Password changed'
                          : (auth.error ?? 'Failed')),
                    ),
                  );
                },
                child: const Text('Update password'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionTitle('Appearance'),
          SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Use dark colors throughout the app'),
            value: themeCtrl.isDark,
            onChanged: (_) => themeCtrl.toggle(),
            activeThumbColor: AppColors.accent,
          ),
          ListTile(
            title: const Text('Follow system theme'),
            trailing: Switch(
              value: themeCtrl.mode == ThemeMode.system,
              activeThumbColor: AppColors.accent,
              onChanged: (v) => themeCtrl.setMode(
                v
                    ? ThemeMode.system
                    : (themeCtrl.isDark ? ThemeMode.dark : ThemeMode.light),
              ),
            ),
          ),
          const _SectionTitle('Push notifications'),
          SwitchListTile(
            title: const Text('Task offers'),
            subtitle: const Text('New task push notifications'),
            value: _pushTasks,
            onChanged: (v) => setState(() => _pushTasks = v),
            activeThumbColor: AppColors.accent,
          ),
          SwitchListTile(
            title: const Text('Chat messages'),
            value: _pushChat,
            onChanged: (v) => setState(() => _pushChat = v),
            activeThumbColor: AppColors.accent,
          ),
          SwitchListTile(
            title: const Text('Payout updates'),
            value: _pushPayout,
            onChanged: (v) => setState(() => _pushPayout = v),
            activeThumbColor: AppColors.accent,
          ),
          const _SectionTitle('SMS & Email'),
          SwitchListTile(
            title: const Text('SMS task alerts'),
            value: _smsTasks,
            onChanged: (v) => setState(() => _smsTasks = v),
            activeThumbColor: AppColors.accent,
          ),
          SwitchListTile(
            title: const Text('Email weekly digest'),
            value: _emailDigest,
            onChanged: (v) => setState(() => _emailDigest = v),
            activeThumbColor: AppColors.accent,
          ),
          const _SectionTitle('Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _showChangePassword,
          ),
          SwitchListTile(
            title: const Text('Multi-factor authentication'),
            subtitle: const Text('Require OTP on login'),
            value: _mfa,
            onChanged: (v) {
              setState(() => _mfa = v);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        v ? 'MFA enabled (stub)' : 'MFA disabled (stub)')),
              );
            },
            activeThumbColor: AppColors.accent,
          ),
          const _SectionTitle('Language'),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Language'),
            subtitle: const Text('English'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Language selection coming soon')),
            ),
          ),
          const _SectionTitle('About'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About WorkStream'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const AboutScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Help & FAQ'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const HelpScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Contact support'),
            subtitle: const Text(AppMeta.supportEmail),
            onTap: () {},
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              onPressed: () async {
                await context.read<AuthController>().logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Version ${AppMeta.version}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSubtext
                    : AppColors.lightSubtext,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
