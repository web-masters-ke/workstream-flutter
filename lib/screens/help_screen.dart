import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'chat_list_screen.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();
  int? _expandedIndex;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _faqs = [
    _FaqCategory(
      title: 'Getting Started',
      icon: Icons.rocket_launch_outlined,
      items: [
        _Faq(
          q: 'How do I accept a task?',
          a: 'Go to the Tasks tab → Available → tap a task card → tap Accept. Once accepted it moves to your Assigned tab and the timer starts.',
        ),
        _Faq(
          q: 'How do I complete a task?',
          a: 'Open the assigned task, do the work, then tap "Submit" and fill in your submission details. The business\'s QA team will review it.',
        ),
        _Faq(
          q: 'How do I set myself as available?',
          a: 'Tap the availability dot at the top of the Home screen and select ONLINE. You must be ONLINE to receive task assignments.',
        ),
        _Faq(
          q: 'What does the QA score mean?',
          a: 'Each submitted task is reviewed by a QA analyst. Your average score across all tasks forms your overall agent rating (shown on your profile).',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Tasks & Jobs',
      icon: Icons.assignment_outlined,
      items: [
        _Faq(
          q: 'My task was rejected — what happens?',
          a: 'If a business rejects your submission, the task moves to Failed status. Contact the business via chat to clarify what was missing; you may be able to resubmit depending on the task settings.',
        ),
        _Faq(
          q: 'Can I unassign a task I have accepted?',
          a: 'Yes, but it will count against your completion rate. Open the task, tap the menu (⋮), and select Unassign. Frequent unassignments reduce your priority for future tasks.',
        ),
        _Faq(
          q: 'What is the task deadline?',
          a: 'Each task shows a countdown timer once you accept it. You must submit before the deadline or the task auto-fails.',
        ),
        _Faq(
          q: 'How do I dispute a task outcome?',
          a: 'Open the task → tap the menu (⋮) → Report issue. Describe the problem. Our team reviews all disputes within 24 hours.',
        ),
        _Faq(
          q: 'Why can\'t I see any available tasks?',
          a: 'Tasks are matched to your skills and availability. Make sure your profile skills are up to date and that your availability is set to ONLINE.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Payments & Earnings',
      icon: Icons.payments_outlined,
      items: [
        _Faq(
          q: 'When do I get paid?',
          a: 'Earnings are credited to your WorkStream wallet immediately after a task is marked complete and approved by the business. You can withdraw once your balance meets the minimum payout threshold (KES 1,000).',
        ),
        _Faq(
          q: 'What payout methods are supported?',
          a: 'M-Pesa, Airtel Money, and bank transfer (Kenya). More providers are being added. Go to Wallet → Withdraw to request a payout.',
        ),
        _Faq(
          q: 'How long does a withdrawal take?',
          a: 'M-Pesa withdrawals are typically instant. Bank transfers take 1–2 business days depending on your bank.',
        ),
        _Faq(
          q: 'Why is my balance showing as Pending?',
          a: 'Earnings sit in Pending status until the business approves the task. Once approved the amount moves to your Available balance.',
        ),
        _Faq(
          q: 'Can I see my earnings history?',
          a: 'Yes. Go to Wallet → Statement to download a PDF of all your earnings and payouts for any period.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Account & Profile',
      icon: Icons.person_outline,
      items: [
        _Faq(
          q: 'How do I update my profile?',
          a: 'Go to Profile → tap the edit icon (top right). You can update your name, phone, bio, headline, skills, and availability schedule.',
        ),
        _Faq(
          q: 'How do I complete KYC?',
          a: 'Go to Profile → Complete KYC. You will need to upload a government-issued ID (front and back) and a selfie. KYC is required to enable payouts.',
        ),
        _Faq(
          q: 'How do I change my password?',
          a: 'Go to Profile → Settings → Change password. You will need to enter your current password first.',
        ),
        _Faq(
          q: 'Can I use WorkStream on multiple devices?',
          a: 'Yes. Log in with your email or phone on any device. Your tasks, wallet, and chat are synced in real time.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Technical Issues',
      icon: Icons.build_outlined,
      items: [
        _Faq(
          q: 'The app is not loading tasks. What should I do?',
          a: 'Check your internet connection first. Then pull down to refresh. If the problem persists, log out and log back in. If still failing, report a bug below.',
        ),
        _Faq(
          q: 'I\'m not receiving push notifications.',
          a: 'Check that notifications are enabled for WorkStream in your device settings. Also make sure Do Not Disturb mode is off during your shift.',
        ),
        _Faq(
          q: 'My chat messages are not sending.',
          a: 'Chat requires a live internet connection. Try switching between Wi-Fi and mobile data. If the issue continues, restart the app.',
        ),
        _Faq(
          q: 'How do I report a bug?',
          a: 'Tap "Report a bug" below and describe what happened. Include the screen you were on and what you expected vs what occurred.',
        ),
      ],
    ),
  ];

  List<_Faq> get _allFaqs =>
      _faqs.expand((c) => c.items).toList();

  List<_Faq> _filtered(String q) {
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    return _allFaqs
        .where((f) =>
            f.q.toLowerCase().contains(lower) ||
            f.a.toLowerCase().contains(lower))
        .toList();
  }

  void _launchEmail() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Email us at ${AppMeta.supportEmail}'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
    );
  }

  void _showBugReport() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool busy = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Report a bug',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Brief description of the problem',
                  prefixIcon: Icon(Icons.title_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText:
                      'What screen were you on? What happened? What did you expect?',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty) return;
                        setLocal(() => busy = true);
                        try {
                          await ApiService.instance.post(
                            '/admin/disputes',
                            body: {
                              'category': 'TECHNICAL',
                              'title': titleCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                            },
                          );
                        } catch (_) {
                          // best-effort
                        }
                        titleCtrl.dispose();
                        descCtrl.dispose();
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Bug report submitted. Thank you!')),
                          );
                        }
                      },
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final query = _search.text.trim();
    final searchResults = _filtered(query);

    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Search bar ──────────────────────────────────────
          TextField(
            controller: _search,
            onChanged: (_) => setState(() => _expandedIndex = null),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              hintText: 'Search FAQs...',
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () =>
                          setState(() => _search.clear()),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // ── Search results (flat list) ──────────────────────
          if (query.isNotEmpty) ...[
            if (searchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No FAQs match "$query"',
                      style: TextStyle(color: subtext)),
                ),
              )
            else
              ...searchResults.asMap().entries.map((e) {
                final idx = e.key;
                final faq = e.value;
                return _FaqTile(
                  faq: faq,
                  expanded: _expandedIndex == idx,
                  onToggle: () => setState(() =>
                      _expandedIndex =
                          _expandedIndex == idx ? null : idx),
                  subtext: subtext,
                );
              }),
          ] else ...[
            // ── Category FAQs ────────────────────────────────
            ..._faqs.asMap().entries.expand((catEntry) {
              final cat = catEntry.value;
              final baseIdx = _faqs
                  .take(catEntry.key)
                  .fold(0, (sum, c) => sum + c.items.length);
              return [
                _CategoryHeader(cat: cat, subtext: subtext),
                ...cat.items.asMap().entries.map((e) {
                  final absIdx = baseIdx + e.key;
                  return _FaqTile(
                    faq: e.value,
                    expanded: _expandedIndex == absIdx,
                    onToggle: () => setState(() =>
                        _expandedIndex =
                            _expandedIndex == absIdx ? null : absIdx),
                    subtext: subtext,
                  );
                }),
                const SizedBox(height: 8),
              ];
            }),
          ],

          const SizedBox(height: 8),
          // ── Contact support ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.dividerColor),
            ),
            child: Column(
              children: [
                _SupportTile(
                  icon: Icons.email_outlined,
                  iconColor: AppColors.accent,
                  title: 'Email support',
                  subtitle: AppMeta.supportEmail,
                  onTap: _launchEmail,
                  divider: true,
                ),
                _SupportTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: AppColors.primary,
                  title: 'Live chat',
                  subtitle: 'Chat with our support agents',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const ChatListScreen()),
                  ),
                  divider: true,
                ),
                _SupportTile(
                  icon: Icons.bug_report_outlined,
                  iconColor: AppColors.warn,
                  title: 'Report a bug',
                  subtitle: 'Something broken? Let us know',
                  onTap: _showBugReport,
                  divider: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // ── Version info ────────────────────────────────────
          Center(
            child: Text(
              '${AppMeta.name} v${AppMeta.version} · ${AppMeta.supportEmail}',
              style: TextStyle(color: subtext, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Supporting widgets ──────────────────────────────────────────────────────

class _FaqCategory {
  final String title;
  final IconData icon;
  final List<_Faq> items;
  const _FaqCategory(
      {required this.title, required this.icon, required this.items});
}

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
}

class _CategoryHeader extends StatelessWidget {
  final _FaqCategory cat;
  final Color subtext;
  const _CategoryHeader({required this.cat, required this.subtext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Row(
        children: [
          Icon(cat.icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            cat.title.toUpperCase(),
            style: TextStyle(
              color: subtext,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _Faq faq;
  final bool expanded;
  final VoidCallback onToggle;
  final Color subtext;
  const _FaqTile({
    required this.faq,
    required this.expanded,
    required this.onToggle,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: expanded
              ? AppColors.accent.withValues(alpha: 0.35)
              : t.dividerColor,
          width: expanded ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      faq.q,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: subtext,
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                Text(faq.a, style: TextStyle(color: subtext, height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool divider;
  const _SupportTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle,
              style: TextStyle(color: subtext, fontSize: 12)),
          trailing:
              Icon(Icons.chevron_right_rounded, color: subtext),
        ),
        if (divider) Divider(height: 1, color: t.dividerColor),
      ],
    );
  }
}
