import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// SharedPreferences key for active workspace ID.
const _kActiveWorkspaceKey = 'ws_active_workspace_id';

class WorkspacesScreen extends StatefulWidget {
  const WorkspacesScreen({super.key});
  @override
  State<WorkspacesScreen> createState() => _WorkspacesScreenState();
}

class _WorkspacesScreenState extends State<WorkspacesScreen> {
  List<Map<String, dynamic>> _workspaces = [];
  bool _loading = true;
  String? _error;
  String? _activeId;
  bool _showCreateForm = false;

  // Create form controllers
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoriesCtrl = TextEditingController();
  final _slaLowCtrl = TextEditingController(text: '120');
  final _slaMedCtrl = TextEditingController(text: '60');
  final _slaHighCtrl = TextEditingController(text: '30');
  final _slaUrgentCtrl = TextEditingController(text: '15');
  String _timezone = 'UTC';
  String _currency = 'KES';
  bool _creating = false;

  static const _timezones = [
    'UTC',
    'Africa/Nairobi',
    'Europe/London',
    'America/New_York',
    'Asia/Dubai',
    'Asia/Kolkata',
    'America/Los_Angeles',
    'Asia/Tokyo',
  ];

  static const _currencies = ['KES', 'USD', 'GBP', 'EUR', 'UGX', 'TZS'];

  @override
  void initState() {
    super.initState();
    _loadActiveId();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _categoriesCtrl.dispose();
    _slaLowCtrl.dispose();
    _slaMedCtrl.dispose();
    _slaHighCtrl.dispose();
    _slaUrgentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _activeId = prefs.getString(_kActiveWorkspaceKey));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.instance.get('/workspaces');
      final raw = unwrap<dynamic>(resp);
      final list = raw is List ? raw : (raw is Map ? [raw] : <dynamic>[]);
      setState(() {
        _workspaces = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      setState(() => _error = cleanError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createWorkspace() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace name is required')),
      );
      return;
    }
    setState(() => _creating = true);
    try {
      final categories = _categoriesCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await ApiService.instance.post('/workspaces', body: {
        'name': name,
        'description': _descCtrl.text.trim(),
        'timezone': _timezone,
        'currency': _currency,
        'categories': categories,
        'slaDefaults': {
          'low': int.tryParse(_slaLowCtrl.text.trim()) ?? 120,
          'medium': int.tryParse(_slaMedCtrl.text.trim()) ?? 60,
          'high': int.tryParse(_slaHighCtrl.text.trim()) ?? 30,
          'urgent': int.tryParse(_slaUrgentCtrl.text.trim()) ?? 15,
        },
      });
      // Reset form
      _nameCtrl.clear();
      _descCtrl.clear();
      _categoriesCtrl.clear();
      _slaLowCtrl.text = '120';
      _slaMedCtrl.text = '60';
      _slaHighCtrl.text = '30';
      _slaUrgentCtrl.text = '15';
      _timezone = 'UTC';
      _currency = 'KES';
      setState(() => _showCreateForm = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace created')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _switchWorkspace(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActiveWorkspaceKey, id);
    // Set header on the Dio instance for future requests
    ApiService.instance.dio.options.headers['X-Workspace-Id'] = id;
    setState(() => _activeId = id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workspace switched')),
      );
    }
  }

  Future<void> _archiveWorkspace(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete workspace'),
        content: const Text(
            'This workspace will be permanently deleted. This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.delete('/workspaces/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace deleted')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    }
  }

  void _showEditSheet(Map<String, dynamic> ws) {
    final id = ws['id']?.toString() ?? '';
    final editNameCtrl = TextEditingController(text: ws['name']?.toString() ?? '');
    final editCatsCtrl = TextEditingController(
      text: (ws['categories'] is List)
          ? (ws['categories'] as List).join(', ')
          : '',
    );
    final slaDefaults = ws['slaDefaults'] is Map
        ? ws['slaDefaults'] as Map
        : <String, dynamic>{};
    final editSlaLow =
        TextEditingController(text: slaDefaults['low']?.toString() ?? '120');
    final editSlaMed =
        TextEditingController(text: slaDefaults['medium']?.toString() ?? '60');
    final editSlaHigh =
        TextEditingController(text: slaDefaults['high']?.toString() ?? '30');
    final editSlaUrgent =
        TextEditingController(text: slaDefaults['urgent']?.toString() ?? '15');
    bool saving = false;

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
              Text('Edit workspace',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: editNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Workspace name',
                  prefixIcon: Icon(Icons.domain_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editCatsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Categories (comma-separated)',
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              Text('SLA defaults (minutes)',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: editSlaLow,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Low'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: editSlaMed,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Medium'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: editSlaHigh,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'High'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: editSlaUrgent,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Urgent'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setLocal(() => saving = true);
                        try {
                          final cats = editCatsCtrl.text
                              .split(',')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          await ApiService.instance
                              .patch('/workspaces/$id', body: {
                            'name': editNameCtrl.text.trim(),
                            'categories': cats,
                            'slaDefaults': {
                              'low':
                                  int.tryParse(editSlaLow.text.trim()) ?? 120,
                              'medium':
                                  int.tryParse(editSlaMed.text.trim()) ?? 60,
                              'high':
                                  int.tryParse(editSlaHigh.text.trim()) ?? 30,
                              'urgent':
                                  int.tryParse(editSlaUrgent.text.trim()) ??
                                      15,
                            },
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Workspace updated')),
                            );
                            _load();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(cleanError(e))),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setLocal(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Save changes'),
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
    final isDark = t.brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(title: const Text('Workspaces')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // ── Create workspace toggle ────────────────
                      if (!_showCreateForm)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _showCreateForm = true),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create workspace'),
                          ),
                        )
                      else ...[
                        _CreateFormCard(
                          nameCtrl: _nameCtrl,
                          descCtrl: _descCtrl,
                          categoriesCtrl: _categoriesCtrl,
                          slaLowCtrl: _slaLowCtrl,
                          slaMedCtrl: _slaMedCtrl,
                          slaHighCtrl: _slaHighCtrl,
                          slaUrgentCtrl: _slaUrgentCtrl,
                          timezone: _timezone,
                          currency: _currency,
                          timezones: _timezones,
                          currencies: _currencies,
                          creating: _creating,
                          onTimezoneChanged: (v) =>
                              setState(() => _timezone = v),
                          onCurrencyChanged: (v) =>
                              setState(() => _currency = v),
                          onSubmit: _createWorkspace,
                          onCancel: () =>
                              setState(() => _showCreateForm = false),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Workspace grid ─────────────────────────
                      if (_workspaces.isEmpty)
                        _EmptyState(isDark: isDark, sub: sub)
                      else
                        ..._workspaces.map((ws) {
                          final id = ws['id']?.toString() ?? '';
                          final isCurrent = id == _activeId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WorkspaceCard(
                              ws: ws,
                              isDark: isDark,
                              sub: sub,
                              isCurrent: isCurrent,
                              onSwitch: isCurrent
                                  ? null
                                  : () => _switchWorkspace(id),
                              onEdit: () => _showEditSheet(ws),
                              onArchive: () => _archiveWorkspace(id),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}

// ─── Create form card ─────────────────────────────────────────────────────────

class _CreateFormCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController categoriesCtrl;
  final TextEditingController slaLowCtrl;
  final TextEditingController slaMedCtrl;
  final TextEditingController slaHighCtrl;
  final TextEditingController slaUrgentCtrl;
  final String timezone;
  final String currency;
  final List<String> timezones;
  final List<String> currencies;
  final bool creating;
  final ValueChanged<String> onTimezoneChanged;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _CreateFormCard({
    required this.nameCtrl,
    required this.descCtrl,
    required this.categoriesCtrl,
    required this.slaLowCtrl,
    required this.slaMedCtrl,
    required this.slaHighCtrl,
    required this.slaUrgentCtrl,
    required this.timezone,
    required this.currency,
    required this.timezones,
    required this.currencies,
    required this.creating,
    required this.onTimezoneChanged,
    required this.onCurrencyChanged,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create workspace',
              style: t.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'My workspace',
              prefixIcon: Icon(Icons.domain_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What this workspace is for...',
              prefixIcon: Icon(Icons.description_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: timezone,
                  decoration: const InputDecoration(labelText: 'Timezone'),
                  items: timezones
                      .map((tz) =>
                          DropdownMenuItem(value: tz, child: Text(tz)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onTimezoneChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: currencies
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) onCurrencyChanged(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: categoriesCtrl,
            decoration: const InputDecoration(
              labelText: 'Categories (comma-separated)',
              hintText: 'Data entry, Research, QA',
              prefixIcon: Icon(Icons.category_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          Text('SLA defaults (minutes)',
              style: t.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: slaLowCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Low'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: slaMedCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Medium'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: slaHighCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'High'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: slaUrgentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Urgent'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: creating ? null : onSubmit,
                  child: creating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Create workspace'),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Workspace card ───────────────────────────────────────────────────────────

class _WorkspaceCard extends StatelessWidget {
  final Map<String, dynamic> ws;
  final bool isDark;
  final Color sub;
  final bool isCurrent;
  final VoidCallback? onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  const _WorkspaceCard({
    required this.ws,
    required this.isDark,
    required this.sub,
    required this.isCurrent,
    this.onSwitch,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final name = ws['name']?.toString() ?? 'Workspace';
    final memberCount = ws['memberCount']?.toString() ?? ws['members']?.toString() ?? '';
    final createdAt = ws['createdAt']?.toString() ?? '';
    final status = ws['status']?.toString() ?? 'ACTIVE';
    final slaDefaults =
        ws['slaDefaults'] is Map ? ws['slaDefaults'] as Map : null;

    String formattedDate = '';
    try {
      final dt = DateTime.parse(createdAt);
      formattedDate = '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      formattedDate = createdAt;
    }

    final statusColor = switch (status.toUpperCase()) {
      'ACTIVE' => AppColors.success,
      'SUSPENDED' => AppColors.danger,
      'ARCHIVED' => AppColors.darkSubtext,
      _ => AppColors.warn,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'W',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (memberCount.isNotEmpty || formattedDate.isNotEmpty)
                      Row(
                        children: [
                          if (memberCount.isNotEmpty) ...[
                            Icon(Icons.people_outline, size: 12, color: sub),
                            const SizedBox(width: 3),
                            Text('$memberCount members',
                                style: TextStyle(fontSize: 11, color: sub)),
                            const SizedBox(width: 10),
                          ],
                          if (formattedDate.isNotEmpty) ...[
                            Icon(Icons.calendar_today_outlined,
                                size: 11, color: sub),
                            const SizedBox(width: 3),
                            Text(formattedDate,
                                style: TextStyle(fontSize: 11, color: sub)),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),

          // SLA defaults row
          if (slaDefaults != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (slaDefaults['low'] != null)
                  _SlaBadge(label: 'Low', minutes: slaDefaults['low'].toString()),
                if (slaDefaults['medium'] != null)
                  _SlaBadge(
                      label: 'Med', minutes: slaDefaults['medium'].toString()),
                if (slaDefaults['high'] != null)
                  _SlaBadge(
                      label: 'High', minutes: slaDefaults['high'].toString()),
                if (slaDefaults['urgent'] != null)
                  _SlaBadge(
                      label: 'Urgent',
                      minutes: slaDefaults['urgent'].toString()),
              ],
            ),
          ],

          // Actions row
          const SizedBox(height: 12),
          Row(
            children: [
              if (onSwitch != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSwitch,
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    child: const Text('Switch'),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
                tooltip: 'Edit',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.archive_outlined, size: 18),
                onPressed: onArchive,
                tooltip: 'Archive',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlaBadge extends StatelessWidget {
  final String label;
  final String minutes;
  const _SlaBadge({required this.label, required this.minutes});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sub = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: sub.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${minutes}m',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sub),
      ),
    );
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final Color sub;
  const _EmptyState({required this.isDark, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.domain_outlined,
                size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('No workspaces',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Create a workspace to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontSize: 13)),
        ],
      ),
    );
  }
}
