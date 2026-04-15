import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final isDark = t.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Subscriptions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Current plan card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDeep, AppColors.primarySoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'CURRENT PLAN',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Starter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Free',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                _planFeature(Icons.check_circle_rounded,
                    'Unlimited marketplace listings'),
                const SizedBox(height: 6),
                _planFeature(
                    Icons.check_circle_rounded, 'Up to 20 agents'),
                const SizedBox(height: 6),
                _planFeature(Icons.check_circle_rounded,
                    'Task management & scheduling'),
                const SizedBox(height: 6),
                _planFeature(Icons.check_circle_rounded, 'Basic reports'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Plan upgrades coming soon.'),
                        ),
                      );
                    },
                    child: const Text(
                      'Upgrade plan',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Pro plan comparison
          Text(
            'Pro plan includes',
            style: t.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _proFeature(context, Icons.groups_rounded,
                    'Unlimited agents', subtext),
                _divider(borderColor),
                _proFeature(context, Icons.bar_chart_rounded,
                    'Advanced analytics & exports', subtext),
                _divider(borderColor),
                _proFeature(context, Icons.support_agent_rounded,
                    'Priority support', subtext),
                _divider(borderColor),
                _proFeature(context, Icons.api_rounded,
                    'API access & webhooks', subtext),
                _divider(borderColor),
                _proFeature(context, Icons.verified_rounded,
                    'Custom branding', subtext),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Billing history section
          Text(
            'Billing history',
            style: t.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 40, color: borderColor),
                const SizedBox(height: 10),
                Text(
                  'No invoices yet',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: subtext),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your billing history will appear here once you upgrade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subtext, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _proFeature(
      BuildContext context, IconData icon, String text, Color subtext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          const Icon(Icons.lock_rounded, size: 16, color: AppColors.accent),
        ],
      ),
    );
  }

  Widget _divider(Color color) {
    return Divider(height: 1, color: color);
  }
}
