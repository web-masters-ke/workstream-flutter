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

class _HelpScreenState extends State<HelpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: 'Support Tickets'),
            Tab(text: 'Contact'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _FaqTab(),
          _SupportTicketsTab(),
          _ContactTab(),
        ],
      ),
    );
  }
}

// ─── FAQ Tab ──────────────────────────────────────────────────────────────────

class _FaqTab extends StatefulWidget {
  const _FaqTab();
  @override
  State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab> {
  final _search = TextEditingController();
  int? _expandedIndex;

  static const _faqs = [
    _Faq(
      q: 'How do I post a job?',
      a: 'Navigate to the Jobs tab and tap the "+" button. Fill in the task title, '
          'description, category, deadline, and payout amount. Once submitted, '
          'the job goes live and matched agents can accept it. You can also use '
          'the API to create tasks programmatically via POST /tasks.',
    ),
    _Faq(
      q: 'How are agents paid?',
      a: 'Agents are paid via their WorkStream wallet. When a task is completed '
          'and approved by QA, the agreed payout is credited to the agent\'s '
          'wallet balance. Agents can then withdraw to M-Pesa, Airtel Money, '
          'or bank transfer. Payouts are processed within minutes for mobile '
          'money and 1-2 business days for bank transfers.',
    ),
    _Faq(
      q: 'What happens if an agent misses the SLA?',
      a: 'Each task has an SLA deadline configured by the business (default is '
          'set in workspace settings). If an agent does not submit before the '
          'SLA expires, the task is automatically marked as FAILED and may be '
          'reassigned to another agent. Repeated SLA breaches lower the agent\'s '
          'priority score and may trigger escalation rules defined in your '
          'workspace settings.',
    ),
    _Faq(
      q: 'How do QA reviews work?',
      a: 'After an agent submits a task, it enters the QA queue. A QA reviewer '
          '(assigned by the business) inspects the submission against the task '
          'requirements and scores it on accuracy, completeness, and quality. '
          'If approved, the agent gets paid. If rejected, the agent is notified '
          'with feedback and may resubmit depending on task settings. QA scores '
          'contribute to the agent\'s overall rating.',
    ),
    _Faq(
      q: 'Can I use my own payment provider?',
      a: 'Currently WorkStream supports M-Pesa, Airtel Money, and bank transfer '
          'for payouts. Custom payment provider integrations are on our roadmap. '
          'In the meantime, you can use our webhook system to trigger external '
          'payment flows when tasks are completed. Check the Webhooks tab in '
          'Settings to configure task.completed events.',
    ),
    _Faq(
      q: 'How do I manage multiple workspaces?',
      a: 'Go to the Workspaces screen from the navigation drawer. You can create '
          'new workspaces, switch between them, and configure each with its own '
          'SLA defaults, categories, and team members. The active workspace is '
          'highlighted with a "Current" badge.',
    ),
    _Faq(
      q: 'How do API keys work?',
      a: 'API keys allow external systems to interact with your WorkStream '
          'workspace programmatically. Generate keys from Settings > API Keys. '
          'Each key is shown once at creation time — copy and store it securely. '
          'You can revoke keys at any time. Use the key in the Authorization '
          'header as "Bearer ws_...".',
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Faq> _filtered(String q) {
    if (q.isEmpty) return _faqs;
    final lower = q.toLowerCase();
    return _faqs
        .where((f) =>
            f.q.toLowerCase().contains(lower) ||
            f.a.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sub = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final query = _search.text.trim();
    final results = _filtered(query);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Search bar
        TextField(
          controller: _search,
          onChanged: (_) => setState(() => _expandedIndex = null),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            hintText: 'Search FAQs...',
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => setState(() => _search.clear()),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),

        if (results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No FAQs match "$query"',
                  style: TextStyle(color: sub)),
            ),
          )
        else
          ...results.asMap().entries.map((e) {
            final idx = e.key;
            final faq = e.value;
            return _FaqTile(
              faq: faq,
              expanded: _expandedIndex == idx,
              onToggle: () => setState(
                  () => _expandedIndex = _expandedIndex == idx ? null : idx),
              subtext: sub,
            );
          }),
      ],
    );
  }
}

// ─── Support Tickets Tab ──────────────────────────────────────────────────────

class _SupportTicketsTab extends StatefulWidget {
  const _SupportTicketsTab();
  @override
  State<_SupportTicketsTab> createState() => _SupportTicketsTabState();
}

class _SupportTicketsTabState extends State<_SupportTicketsTab> {
  List<Map<String, dynamic>> _tickets = [];
  bool _showForm = false;
  bool _submitting = false;

  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _priority = 'Medium';

  static const _priorities = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    try {
      final resp = await ApiService.instance.get('/support/tickets');
      final raw = unwrap<dynamic>(resp);
      final list = raw is List ? raw : <dynamic>[];
      if (mounted) {
        setState(() {
          _tickets = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {
      // If endpoint doesn't exist, just use local state
    }
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (subject.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and description are required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.instance.post('/support/tickets', body: {
        'subject': subject,
        'priority': _priority.toUpperCase(),
        'description': desc,
      });
    } catch (_) {
      // best-effort — add to local list anyway
    }

    // Add to local state
    setState(() {
      _tickets.insert(0, {
        'subject': subject,
        'priority': _priority.toUpperCase(),
        'description': desc,
        'status': 'OPEN',
        'createdAt': DateTime.now().toIso8601String(),
      });
      _subjectCtrl.clear();
      _descCtrl.clear();
      _priority = 'Medium';
      _showForm = false;
      _submitting = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support ticket submitted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Raise a ticket button / form
        if (!_showForm)
          OutlinedButton.icon(
            onPressed: () => setState(() => _showForm = true),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Raise a ticket'),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New support ticket',
                    style: t.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(
                  controller: _subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Brief summary of your issue',
                    prefixIcon: Icon(Icons.title_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    prefixIcon:
                        Icon(Icons.flag_outlined, size: 20),
                  ),
                  items: _priorities
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _priority = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe your issue in detail...',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Submit ticket'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => setState(() => _showForm = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),
        _SectionHeader('Your tickets'),
        const SizedBox(height: 8),

        if (_tickets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.confirmation_number_outlined,
                      size: 40, color: t.dividerColor),
                  const SizedBox(height: 8),
                  Text('No support tickets yet',
                      style: TextStyle(color: sub)),
                ],
              ),
            ),
          )
        else
          ..._tickets.map((ticket) {
            final subject = ticket['subject']?.toString() ?? '';
            final status = ticket['status']?.toString() ?? 'OPEN';
            final priority = ticket['priority']?.toString() ?? 'MEDIUM';
            final created = ticket['createdAt']?.toString() ?? '';

            final statusColor = switch (status.toUpperCase()) {
              'OPEN' => AppColors.primary,
              'IN_PROGRESS' => AppColors.warn,
              'RESOLVED' || 'CLOSED' => AppColors.success,
              _ => AppColors.darkSubtext,
            };

            final priorityColor = switch (priority.toUpperCase()) {
              'HIGH' => AppColors.danger,
              'MEDIUM' => AppColors.warn,
              'LOW' => AppColors.success,
              _ => AppColors.darkSubtext,
            };

            String formattedDate = '';
            try {
              final dt = DateTime.parse(created);
              formattedDate =
                  '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } catch (_) {
              formattedDate = created;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Badge(label: status, color: statusColor),
                      const SizedBox(width: 8),
                      _Badge(label: priority, color: priorityColor),
                      const Spacer(),
                      Text(formattedDate,
                          style: TextStyle(fontSize: 11, color: sub)),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ─── Contact Tab ──────────────────────────────────────────────────────────────

class _ContactTab extends StatelessWidget {
  const _ContactTab();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            color: t.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.dividerColor),
          ),
          child: Column(
            children: [
              _ContactTile(
                icon: Icons.email_outlined,
                iconColor: AppColors.primary,
                title: 'Email support',
                subtitle: AppMeta.supportEmail,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Email us at ${AppMeta.supportEmail}'),
                      action: SnackBarAction(label: 'OK', onPressed: () {}),
                    ),
                  );
                },
                divider: true,
              ),
              _ContactTile(
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
              _ContactTile(
                icon: Icons.menu_book_outlined,
                iconColor: AppColors.primarySoft,
                title: 'Visit our docs',
                subtitle: 'docs.workstream.app',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Documentation site coming soon')),
                  );
                },
                divider: true,
              ),
              _ContactTile(
                icon: Icons.bug_report_outlined,
                iconColor: AppColors.warn,
                title: 'Report a bug',
                subtitle: 'Something broken? Let us know',
                onTap: () => _showBugReport(context),
                divider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Text(
            '${AppMeta.name} v${AppMeta.version}',
            style: TextStyle(color: sub, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ─── Bug report bottom sheet ──────────────────────────────────────────────────

void _showBugReport(BuildContext context) {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  bool busy = false;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
                      if (context.mounted) {
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

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
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
              ? AppColors.primary.withValues(alpha: 0.35)
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool divider;
  const _ContactTile({
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
    final sub = t.brightness == Brightness.dark
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
          subtitle:
              Text(subtitle, style: TextStyle(color: sub, fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded, color: sub),
        ),
        if (divider) Divider(height: 1, color: t.dividerColor),
      ],
    );
  }
}
