import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.bolt_rounded,
                  color: AppColors.primary, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(AppMeta.name,
                style: t.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(AppMeta.tagline,
                style: TextStyle(color: subtext)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('Version ${AppMeta.version}',
                style: TextStyle(color: subtext, fontSize: 12)),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Text(
              'WorkStream connects remote agents with businesses that need task execution at scale. '
              'Agents pick up tasks, get paid via mobile money, and grow their rating to unlock '
              'higher-paying opportunities.\n\n'
              'Built for Africa\'s growing remote workforce.',
              style: t.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          _InfoRow(label: 'Support', value: AppMeta.supportEmail),
          _InfoRow(label: 'Website', value: 'workstream.app'),
          _InfoRow(label: 'Version', value: AppMeta.version),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: subtext)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
