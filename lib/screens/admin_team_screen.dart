import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class _Workspace {
  final String id;
  final String name;
  final String? description;
  final String? timezone;
  final String? currency;

  const _Workspace({
    required this.id,
    required this.name,
    this.description,
    this.timezone,
    this.currency,
  });

  factory _Workspace.fromJson(Map<String, dynamic> j) => _Workspace(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Workspace',
        description: j['description']?.toString(),
        timezone: j['timezone']?.toString(),
        currency: j['currency']?.toString(),
      );
}

class _Member {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final String status;
  final DateTime addedAt;
  final String? avatarUrl;

  const _Member({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    required this.addedAt,
    this.avatarUrl,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    return (a + b).toUpperCase();
  }

  bool get isOnline => status.toUpperCase() == 'ONLINE' || status.toUpperCase() == 'ACTIVE';

  factory _Member.fromJson(Map<String, dynamic> j) {
    final user = j['user'] is Map ? j['user'] as Map<String, dynamic> : j;
    DateTime added = DateTime.now();
    final raw = j['createdAt'] ?? j['addedAt'] ?? j['joinedAt'];
    if (raw != null) added = DateTime.tryParse(raw.toString()) ?? added;

    return _Member(
      id: j['id']?.toString() ?? '',
      firstName: (user['firstName'] ?? j['firstName'])?.toString() ?? '',
      lastName: (user['lastName'] ?? j['lastName'])?.toString() ?? '',
      email: (user['email'] ?? j['email'])?.toString() ?? '',
      phone: (user['phone'] ?? j['phone'])?.toString() ?? '',
      role: j['role']?.toString() ?? 'MEMBER',
      status: j['status']?.toString() ?? 'OFFLINE',
      addedAt: added,
      avatarUrl: (user['avatarUrl'] ?? j['avatarUrl'])?.toString(),
    );
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  List<_Workspace> _workspaces = [];
  List<_Member> _members = [];
  String? _selectedWorkspaceId;
  bool _loadingWorkspaces = true;
  bool _loadingMembers = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    setState(() {
      _loadingWorkspaces = true;
      _error = null;
    });
    try {
      final resp = await ApiService.instance.get('/workspaces');
      final raw = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['items'] is List) {
        list = raw['items'] as List;
      } else if (raw is Map && raw['workspaces'] is List) {
        list = raw['workspaces'] as List;
      } else {
        list = [];
      }
      _workspaces = list
          .whereType<Map<String, dynamic>>()
          .map(_Workspace.fromJson)
          .toList();
      if (_workspaces.isNotEmpty && _selectedWorkspaceId == null) {
        _selectedWorkspaceId = _workspaces.first.id;
      }
    } catch (e) {
      _error = cleanError(e);
    }
    if (mounted) {
      setState(() => _loadingWorkspaces = false);
      if (_selectedWorkspaceId != null) _loadMembers();
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loadingMembers = true;
      _error = null;
    });
    try {
      final resp = await ApiService.instance.get('/team');
      final raw = unwrap<dynamic>(resp);
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['items'] is List) {
        list = raw['items'] as List;
      } else if (raw is Map && raw['members'] is List) {
        list = raw['members'] as List;
      } else {
        list = [];
      }
      _members = list
          .whereType<Map<String, dynamic>>()
          .map(_Member.fromJson)
          .toList();
    } catch (e) {
      _error = cleanError(e);
    }
    if (mounted) setState(() => _loadingMembers = false);
  }

  Future<void> _removeMember(_Member m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${m.fullName} from the team?'),
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
      await ApiService.instance.delete('/team/${m.id}');
      await _loadMembers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${m.fullName} removed'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: ${cleanError(e)}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _changeRole(_Member m) async {
    final roles = ['SUPERVISOR', 'MEMBER', 'VIEWER'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final t = Theme.of(ctx);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              Text('Change role',
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              ...roles.map((r) => ListTile(
                    title: Text(r,
                        style: TextStyle(
                          fontWeight: r == m.role.toUpperCase()
                              ? FontWeight.w800
                              : FontWeight.w500,
                        )),
                    leading: Icon(
                      r == m.role.toUpperCase()
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: r == m.role.toUpperCase()
                          ? AppColors.primary
                          : null,
                    ),
                    onTap: () => Navigator.pop(ctx, r),
                  )),
            ],
          ),
        );
      },
    );
    if (picked == null || picked == m.role.toUpperCase()) return;
    try {
      await ApiService.instance
          .patch('/team/${m.id}', body: {'role': picked});
      await _loadMembers();
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

  void _showAddMember() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddMemberSheet(
        workspaces: _workspaces,
        onAdded: _loadMembers,
      ),
    );
  }

  void _showCreateTeam() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateTeamSheet(onCreated: _loadWorkspaces),
    );
  }

  Color _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'SUPERVISOR':
        return AppColors.primary;
      case 'VIEWER':
        return AppColors.lightSubtext;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final df = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add member',
            onPressed: _showAddMember,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text('${_members.length}'),
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              labelStyle: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _showCreateTeam,
        icon: const Icon(Icons.add),
        label: const Text('New team'),
      ),
      body: _loadingWorkspaces
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null && _workspaces.isEmpty
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
                          onPressed: _loadWorkspaces,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ── Workspace chips ──
                    if (_workspaces.isNotEmpty)
                      SizedBox(
                        height: 50,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _workspaces.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final ws = _workspaces[i];
                            final active =
                                ws.id == _selectedWorkspaceId;
                            return GestureDetector(
                              onTap: () {
                                setState(
                                    () => _selectedWorkspaceId = ws.id);
                                _loadMembers();
                              },
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.primary
                                        : t.cardColor,
                                    borderRadius:
                                        BorderRadius.circular(999),
                                    border: Border.all(
                                        color: active
                                            ? AppColors.primary
                                            : t.dividerColor),
                                  ),
                                  child: Text(
                                    ws.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: active
                                          ? Colors.white
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 4),

                    // ── Members ──
                    Expanded(
                      child: _loadingMembers
                          ? const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5))
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.error_outline_rounded,
                                          color: AppColors.danger,
                                          size: 40),
                                      const SizedBox(height: 12),
                                      Text(_error!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: subtext)),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                          onPressed: _loadMembers,
                                          child: const Text('Retry')),
                                    ],
                                  ),
                                )
                              : _members.isEmpty
                                  ? EmptyState(
                                      icon: Icons.groups_outlined,
                                      title: 'No team members',
                                      message:
                                          'Tap the + icon to add team members.',
                                    )
                                  : RefreshIndicator(
                                      onRefresh: _loadMembers,
                                      child: ListView.builder(
                                        padding:
                                            const EdgeInsets.only(bottom: 80),
                                        itemCount: _members.length,
                                        itemBuilder: (_, i) {
                                          final m = _members[i];
                                          return Dismissible(
                                            key: Key(m.id),
                                            direction:
                                                DismissDirection.endToStart,
                                            confirmDismiss: (_) async {
                                              await _removeMember(m);
                                              return false;
                                            },
                                            background: Container(
                                              alignment:
                                                  Alignment.centerRight,
                                              padding:
                                                  const EdgeInsets.only(
                                                      right: 20),
                                              color: AppColors.danger
                                                  .withValues(alpha: 0.12),
                                              child: const Icon(
                                                  Icons
                                                      .delete_outline_rounded,
                                                  color: AppColors.danger),
                                            ),
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 6),
                                              onLongPress: () =>
                                                  _removeMember(m),
                                              leading: Stack(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 24,
                                                    backgroundColor: AppColors
                                                        .primary
                                                        .withValues(
                                                            alpha: 0.18),
                                                    backgroundImage: m
                                                                .avatarUrl !=
                                                            null
                                                        ? NetworkImage(
                                                            m.avatarUrl!)
                                                        : null,
                                                    child: m.avatarUrl ==
                                                            null
                                                        ? Text(
                                                            m.initials,
                                                            style: const TextStyle(
                                                              color: AppColors
                                                                  .primary,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          )
                                                        : null,
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      width: 11,
                                                      height: 11,
                                                      decoration:
                                                          BoxDecoration(
                                                        color: m.isOnline
                                                            ? AppColors
                                                                .success
                                                            : AppColors
                                                                .lightSubtext,
                                                        shape:
                                                            BoxShape.circle,
                                                        border: Border.all(
                                                            color: t
                                                                .scaffoldBackgroundColor,
                                                            width: 2),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              title: Text(
                                                m.fullName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  const SizedBox(
                                                      height: 2),
                                                  Text(m.email,
                                                      style: TextStyle(
                                                          color: subtext,
                                                          fontSize: 12)),
                                                  const SizedBox(
                                                      height: 4),
                                                  Row(
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _changeRole(m),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      7,
                                                                  vertical:
                                                                      2),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _roleColor(
                                                                    m.role)
                                                                .withValues(
                                                                    alpha:
                                                                        0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                m.role,
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: _roleColor(
                                                                      m.role),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width:
                                                                      3),
                                                              Icon(
                                                                Icons
                                                                    .arrow_drop_down_rounded,
                                                                size: 14,
                                                                color: _roleColor(
                                                                    m.role),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          width: 8),
                                                      Icon(
                                                          Icons
                                                              .schedule_rounded,
                                                          size: 12,
                                                          color: subtext),
                                                      const SizedBox(
                                                          width: 3),
                                                      Text(
                                                        df.format(
                                                            m.addedAt),
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                subtext),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                    ),
                  ],
                ),
    );
  }
}

// ─── Add Member Bottom Sheet ─────────────────────────────────────────────────

class _AddMemberSheet extends StatefulWidget {
  final List<_Workspace> workspaces;
  final VoidCallback onAdded;
  const _AddMemberSheet({required this.workspaces, required this.onAdded});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String? _selectedTeamId;
  String _selectedRole = 'MEMBER';
  bool _busy = false;

  static const _roles = ['SUPERVISOR', 'MEMBER', 'VIEWER'];

  @override
  void initState() {
    super.initState();
    if (widget.workspaces.isNotEmpty) {
      _selectedTeamId = widget.workspaces.first.id;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ApiService.instance.post('/team/invites', body: {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty)
          'phone': _phoneCtrl.text.trim(),
        if (_selectedTeamId != null) 'teamId': _selectedTeamId,
        'role': _selectedRole,
        if (_messageCtrl.text.trim().isNotEmpty)
          'message': _messageCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Invite sent'),
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
              Text('Add member',
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _field('First name', _firstNameCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field('Last name', _lastNameCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field('Email *', _emailCtrl,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Email is required';
                }
                if (!v.contains('@')) return 'Invalid email';
                return null;
              }),
              const SizedBox(height: 14),
              _field('Phone', _phoneCtrl,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 14),
              if (widget.workspaces.isNotEmpty) ...[
                const Text('Team',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTeamId,
                  decoration: const InputDecoration(
                    prefixIcon:
                        Icon(Icons.groups_outlined, size: 20),
                  ),
                  items: widget.workspaces
                      .map((ws) => DropdownMenuItem(
                          value: ws.id, child: Text(ws.name)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedTeamId = v),
                ),
                const SizedBox(height: 14),
              ],
              const Text('Role',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  prefixIcon:
                      Icon(Icons.badge_outlined, size: 20),
                ),
                items: _roles
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedRole = v ?? 'MEMBER'),
              ),
              const SizedBox(height: 14),
              const Text('Personal message (optional)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _messageCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Welcome message for the invite...',
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
                    : const Text('Send invite'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard,
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
            hintText: label.replaceAll(' *', ''),
          ),
        ),
      ],
    );
  }
}

// ─── Create Team Bottom Sheet ────────────────────────────────────────────────

class _CreateTeamSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateTeamSheet({required this.onCreated});

  @override
  State<_CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<_CreateTeamSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _timezone = 'Africa/Nairobi';
  String _currency = 'KES';
  bool _busy = false;

  static const _timezones = [
    'Africa/Nairobi',
    'Africa/Lagos',
    'Africa/Cairo',
    'Africa/Johannesburg',
    'America/New_York',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Paris',
    'Asia/Dubai',
    'Asia/Kolkata',
    'Asia/Singapore',
    'Pacific/Auckland',
  ];

  static const _currencies = [
    'KES', 'USD', 'EUR', 'GBP', 'NGN', 'ZAR', 'UGX', 'TZS', 'INR', 'AED',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team name is required'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ApiService.instance.post('/workspaces', body: {
        'name': _nameCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        'timezone': _timezone,
        'currency': _currency,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Team created'),
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
            Text('Create team',
                style: t.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            const Text('Team name *',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Engineering',
                prefixIcon: Icon(Icons.group_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Description',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'What does this team do?',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Timezone',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _timezone,
                        isExpanded: true,
                        items: _timezones
                            .map((tz) => DropdownMenuItem(
                                value: tz,
                                child: Text(tz.split('/').last,
                                    style: const TextStyle(
                                        fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _timezone = v ?? _timezone),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Currency',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _currency,
                        items: _currencies
                            .map((c) => DropdownMenuItem(
                                value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(
                            () => _currency = v ?? _currency),
                      ),
                    ],
                  ),
                ),
              ],
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
                  : const Text('Create team'),
            ),
          ],
        ),
      ),
    );
  }
}
