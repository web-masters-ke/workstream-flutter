import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'chat_screen.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class _Agent {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String status; // ONLINE, BUSY, OFFLINE
  final double rating;
  final List<String> skills;
  final int completedTasks;
  final int activeTasks;
  final String? avatarUrl;
  bool starred;
  bool blocked;

  _Agent({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.status,
    required this.rating,
    required this.skills,
    required this.completedTasks,
    required this.activeTasks,
    this.avatarUrl,
    this.starred = false,
    this.blocked = false,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    return (a + b).toUpperCase();
  }

  factory _Agent.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int i(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    List<String> parseSkills(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) return v.split(',').map((e) => e.trim()).toList();
      return [];
    }

    final user = j['user'] is Map ? j['user'] as Map<String, dynamic> : j;

    return _Agent(
      id: j['id']?.toString() ?? '',
      firstName: (user['firstName'] ?? j['firstName'])?.toString() ?? '',
      lastName: (user['lastName'] ?? j['lastName'])?.toString() ?? '',
      email: (user['email'] ?? j['email'])?.toString() ?? '',
      phone: (user['phone'] ?? j['phone'])?.toString() ?? '',
      status: j['status']?.toString() ?? (j['available'] == true ? 'ONLINE' : 'OFFLINE'),
      rating: d(j['rating'] ?? j['currentRating']),
      skills: parseSkills(j['skills']),
      completedTasks: i(j['tasksCompleted'] ?? j['completedTasks']),
      activeTasks: i(j['activeTasks'] ?? j['activeTaskCount']),
      avatarUrl: (user['avatarUrl'] ?? j['avatarUrl'])?.toString(),
      starred: j['starred'] == true || j['favorited'] == true,
      blocked: j['blocked'] == true,
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class AgentsManageScreen extends StatefulWidget {
  const AgentsManageScreen({super.key});

  @override
  State<AgentsManageScreen> createState() => _AgentsManageScreenState();
}

class _AgentsManageScreenState extends State<AgentsManageScreen> {
  List<_Agent> _agents = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _statusFilter = 'All';

  static const _statusFilters = ['All', 'Online', 'Busy', 'Offline'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.instance.get('/agents');
      final data = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List;
      } else if (data is Map && data['agents'] is List) {
        list = data['agents'] as List;
      } else {
        list = [];
      }
      _agents = list
          .whereType<Map<String, dynamic>>()
          .map(_Agent.fromJson)
          .toList();
    } catch (e) {
      _error = cleanError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<_Agent> get _filtered {
    var result = _agents;

    // Status filter
    if (_statusFilter != 'All') {
      result = result
          .where((a) =>
              a.status.toUpperCase() == _statusFilter.toUpperCase())
          .toList();
    }

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result
          .where((a) =>
              a.fullName.toLowerCase().contains(q) ||
              a.email.toLowerCase().contains(q) ||
              a.skills.any((s) => s.toLowerCase().contains(q)))
          .toList();
    }

    return result;
  }

  Future<void> _toggleStar(_Agent agent) async {
    final prev = agent.starred;
    setState(() => agent.starred = !prev);
    try {
      if (!prev) {
        await ApiService.instance.post('/agents/${agent.id}/star');
      } else {
        await ApiService.instance.delete('/agents/${agent.id}/star');
      }
    } catch (_) {
      if (mounted) setState(() => agent.starred = prev);
    }
  }

  Future<void> _toggleBlock(_Agent agent) async {
    final prev = agent.blocked;
    final action = prev ? 'unblock' : 'block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${prev ? 'Unblock' : 'Block'} agent?'),
        content: Text('${prev ? 'Unblock' : 'Block'} ${agent.fullName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(prev ? 'Unblock' : 'Block',
                  style: TextStyle(
                      color: prev ? AppColors.success : AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => agent.blocked = !prev);
    try {
      await ApiService.instance
          .patch('/agents/${agent.id}', body: {'action': action});
    } catch (_) {
      if (mounted) setState(() => agent.blocked = prev);
    }
  }

  void _showInviteAgent() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _InviteAgentSheet(onInvited: _load),
    );
  }

  Future<void> _removeAgent(_Agent agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove agent?'),
        content: Text(
            'Are you sure you want to remove ${agent.fullName}? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.delete('/agents/${agent.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${agent.fullName} removed'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${cleanError(e)}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAgentDetail(_Agent agent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AgentDetailSheet(
        agent: agent,
        statusDotColor: _statusDotColor,
        onMessage: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ChatScreen(
                threadId: agent.id,
                title: agent.fullName,
              ),
            ),
          );
        },
        onToggleBlock: () {
          Navigator.pop(context);
          _toggleBlock(agent);
        },
        onRemove: () {
          Navigator.pop(context);
          _removeAgent(agent);
        },
      ),
    );
  }

  Color _statusDotColor(String status) {
    switch (status.toUpperCase()) {
      case 'ONLINE':
        return AppColors.success;
      case 'BUSY':
        return AppColors.warn;
      default:
        return AppColors.lightSubtext;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Invite agent',
            onPressed: _showInviteAgent,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text('${_agents.length}'),
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              labelStyle: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name or skill...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),

          // ── Status filter chips ──
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _statusFilters[i];
                final active = f == _statusFilter;
                return GestureDetector(
                  onTap: () => setState(() => _statusFilter = f),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : t.cardColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: active
                                ? AppColors.primary
                                : t.dividerColor),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? Colors.white : subtext,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // ── Grid ──
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 40),
                            const SizedBox(height: 12),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: subtext)),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.groups_outlined,
                            title: _search.isEmpty && _statusFilter == 'All'
                                ? 'No agents yet'
                                : 'No results',
                            message: _search.isEmpty && _statusFilter == 'All'
                                ? 'Agents will appear here once added.'
                                : 'Try different filters.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 4, 16, 24),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.72,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _AgentCard(
                                agent: filtered[i],
                                subtext: subtext,
                                statusDotColor: _statusDotColor,
                                onToggleStar: _toggleStar,
                                onToggleBlock: _toggleBlock,
                                onTap: _showAgentDetail,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Agent Card ──────────────────────────────────────────────────────────────

class _AgentCard extends StatelessWidget {
  final _Agent agent;
  final Color subtext;
  final Color Function(String) statusDotColor;
  final Future<void> Function(_Agent) onToggleStar;
  final Future<void> Function(_Agent) onToggleBlock;
  final void Function(_Agent) onTap;

  const _AgentCard({
    required this.agent,
    required this.subtext,
    required this.statusDotColor,
    required this.onToggleStar,
    required this.onToggleBlock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dotColor = statusDotColor(agent.status);

    return GestureDetector(
      onTap: () => onTap(agent),
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Actions row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => onToggleStar(agent),
                child: Icon(
                  agent.starred
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: agent.starred ? AppColors.danger : subtext,
                ),
              ),
              GestureDetector(
                onTap: () => onToggleBlock(agent),
                child: Icon(
                  agent.blocked
                      ? Icons.block_rounded
                      : Icons.block_outlined,
                  size: 18,
                  color: agent.blocked ? AppColors.danger : subtext,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Avatar + status dot ──
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.18),
                backgroundImage: agent.avatarUrl != null
                    ? NetworkImage(agent.avatarUrl!)
                    : null,
                child: agent.avatarUrl == null
                    ? Text(
                        agent.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: t.scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Name ──
          Text(
            agent.fullName,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),

          // ── Rating stars ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < agent.rating.round();
              return Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14,
                color: filled ? AppColors.warn : subtext.withValues(alpha: 0.4),
              );
            }),
          ),
          const SizedBox(height: 4),

          // ── Skills ──
          if (agent.skills.isNotEmpty)
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 3,
                children: agent.skills.take(3).map((s) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    )).toList(),
              ),
            )
          else
            const Spacer(),

          // ── Task counts ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 12, color: AppColors.success),
              const SizedBox(width: 3),
              Text('${agent.completedTasks}',
                  style: TextStyle(fontSize: 11, color: subtext)),
              const SizedBox(width: 8),
              Icon(Icons.pending_actions_rounded,
                  size: 12, color: AppColors.warn),
              const SizedBox(width: 3),
              Text('${agent.activeTasks}',
                  style: TextStyle(fontSize: 11, color: subtext)),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

// ─── Invite Agent Bottom Sheet ───────────────────────────────────────────────

class _InviteAgentSheet extends StatefulWidget {
  final VoidCallback onInvited;
  const _InviteAgentSheet({required this.onInvited});

  @override
  State<_InviteAgentSheet> createState() => _InviteAgentSheetState();
}

class _InviteAgentSheetState extends State<_InviteAgentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _contractType = 'FREELANCE';
  bool _busy = false;

  static const _contractTypes = ['FREELANCE', 'PART_TIME', 'FULL_TIME'];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _rateCtrl.dispose();
    _skillsCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final skills = _skillsCtrl.text.trim().isNotEmpty
          ? _skillsCtrl.text.trim().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : <String>[];
      await ApiService.instance.post('/agents/invite', body: {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)
          'phone': _phoneCtrl.text.trim(),
        if (_rateCtrl.text.trim().isNotEmpty)
          'hourlyRate': double.tryParse(_rateCtrl.text.trim()),
        'contractType': _contractType,
        if (skills.isNotEmpty) 'skills': skills,
        if (_messageCtrl.text.trim().isNotEmpty)
          'message': _messageCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onInvited();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Agent invitation sent'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${cleanError(e)}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.paddingOf(context).bottom +
              24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: t.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Invite agent',
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _field('First name', _firstNameCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Last name', _lastNameCtrl)),
                ],
              ),
              const SizedBox(height: 14),
              _field('Email *', _emailCtrl,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              }),
              const SizedBox(height: 14),
              _field('Phone', _phoneCtrl,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _field('Hourly rate', _rateCtrl,
                        keyboard: const TextInputType.numberWithOptions(
                            decimal: true)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Contract type',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _contractType,
                          isExpanded: true,
                          items: _contractTypes
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                      c.replaceAll('_', ' '),
                                      style: const TextStyle(
                                          fontSize: 13))))
                              .toList(),
                          onChanged: (v) => setState(() =>
                              _contractType = v ?? 'FREELANCE'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field('Skills (comma-separated)', _skillsCtrl,
                  hint: 'Flutter, React, Node.js'),
              const SizedBox(height: 14),
              const Text('Message (optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _messageCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Welcome message...',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Send invitation'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard,
      String? hint,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint ?? label.replaceAll(' *', ''),
          ),
        ),
      ],
    );
  }
}

// ─── Agent Detail Bottom Sheet ───────────────────────────────────────────────

class _AgentDetailSheet extends StatelessWidget {
  final _Agent agent;
  final Color Function(String) statusDotColor;
  final VoidCallback onMessage;
  final VoidCallback onToggleBlock;
  final VoidCallback onRemove;

  const _AgentDetailSheet({
    required this.agent,
    required this.statusDotColor,
    required this.onMessage,
    required this.onToggleBlock,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    final dotColor = statusDotColor(agent.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Avatar + name
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              agent.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(agent.fullName,
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          if (agent.email.isNotEmpty)
            Text(agent.email, style: TextStyle(color: subtext, fontSize: 13)),
          if (agent.phone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child:
                  Text(agent.phone, style: TextStyle(color: subtext, fontSize: 13)),
            ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat('Rating', agent.rating.toStringAsFixed(1), Icons.star_rounded, AppColors.warn),
              const SizedBox(width: 20),
              _stat('Done', '${agent.completedTasks}', Icons.task_alt_rounded, AppColors.success),
              const SizedBox(width: 20),
              _stat('Active', '${agent.activeTasks}', Icons.assignment_rounded, AppColors.primary),
            ],
          ),
          if (agent.skills.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: agent.skills
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleBlock,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: agent.blocked ? AppColors.success : AppColors.warn,
                  ),
                  icon: Icon(
                    agent.blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    size: 18,
                  ),
                  label: Text(agent.blocked ? 'Unblock' : 'Block'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.person_remove_rounded, size: 18),
              label: const Text('Remove agent'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.darkSubtext)),
      ],
    );
  }
}
