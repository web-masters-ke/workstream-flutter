import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../controllers/auth_controller.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'help_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
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
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Notifications'),
            Tab(text: 'API Keys'),
            Tab(text: 'Webhooks'),
            Tab(text: 'Integrations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _GeneralTab(),
          _NotificationsTab(),
          _ApiKeysTab(),
          _WebhooksTab(),
          _IntegrationsTab(),
        ],
      ),
    );
  }
}

// ─── General Tab ──────────────────────────────────────────────────────────────

class _GeneralTab extends StatefulWidget {
  const _GeneralTab();
  @override
  State<_GeneralTab> createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab> {
  final _nameCtrl = TextEditingController();
  final _slaCtrl = TextEditingController();
  final _escalationCtrl = TextEditingController();
  String _timezone = 'UTC';
  bool _saving = false;

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slaCtrl.dispose();
    _escalationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.instance.patch('/workspaces/settings', body: {
        'name': _nameCtrl.text.trim(),
        'timezone': _timezone,
        'defaultSlaMinutes': int.tryParse(_slaCtrl.text.trim()) ?? 60,
        'escalationRules': _escalationCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Appearance ────────────────────────────────────────
        const _SectionTitle('Appearance'),
        SwitchListTile(
          title: const Text('Dark mode'),
          subtitle: const Text('Use dark colors throughout the app'),
          value: themeCtrl.isDark,
          onChanged: (_) => themeCtrl.toggle(),
          activeThumbColor: AppColors.primary,
        ),
        ListTile(
          title: const Text('Follow system theme'),
          trailing: Switch(
            value: themeCtrl.mode == ThemeMode.system,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => themeCtrl.setMode(
              v
                  ? ThemeMode.system
                  : (themeCtrl.isDark ? ThemeMode.dark : ThemeMode.light),
            ),
          ),
        ),

        const SizedBox(height: 8),
        const _SectionTitle('Workspace'),
        const SizedBox(height: 8),
        _FieldLabel('Workspace name'),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            hintText: 'My workspace',
            prefixIcon: Icon(Icons.domain_outlined, size: 20),
          ),
        ),

        const SizedBox(height: 14),
        _FieldLabel('Timezone'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _timezone,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.schedule_outlined, size: 20),
          ),
          items: _timezones
              .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _timezone = v);
          },
        ),

        const SizedBox(height: 14),
        _FieldLabel('Default SLA (minutes)'),
        const SizedBox(height: 6),
        TextField(
          controller: _slaCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '60',
            prefixIcon: Icon(Icons.timer_outlined, size: 20),
          ),
        ),

        const SizedBox(height: 14),
        _FieldLabel('Escalation rules'),
        const SizedBox(height: 6),
        TextField(
          controller: _escalationCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Describe escalation flow...',
            prefixIcon: Icon(Icons.escalator_warning_outlined, size: 20),
          ),
        ),

        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Save workspace settings'),
        ),

        // ── Security ──────────────────────────────────────────
        const SizedBox(height: 8),
        const _SectionTitle('Security'),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: const Text('Change password'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _showChangePassword(context),
        ),

        // ── About ─────────────────────────────────────────────
        const _SectionTitle('About'),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('About WorkStream'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: const Text('Help & FAQ'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
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
                MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
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
            style: TextStyle(fontSize: 12, color: sub),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Notifications Tab ────────────────────────────────────────────────────────

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab();
  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  bool _taskAssigned = true;
  bool _taskCompleted = true;
  bool _newMessage = true;
  bool _paymentReceived = true;
  bool _slaBreach = true;
  bool _systemUpdates = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ws-notification-prefs');
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        setState(() {
          _taskAssigned = map['taskAssigned'] as bool? ?? true;
          _taskCompleted = map['taskCompleted'] as bool? ?? true;
          _newMessage = map['newMessage'] as bool? ?? true;
          _paymentReceived = map['paymentReceived'] as bool? ?? true;
          _slaBreach = map['slaBreach'] as bool? ?? true;
          _systemUpdates = map['systemUpdates'] as bool? ?? false;
        });
      } catch (_) {
        // ignore parse errors
      }
    }
    setState(() => _loaded = true);
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ws-notification-prefs',
      jsonEncode({
        'taskAssigned': _taskAssigned,
        'taskCompleted': _taskCompleted,
        'newMessage': _newMessage,
        'paymentReceived': _paymentReceived,
        'slaBreach': _slaBreach,
        'systemUpdates': _systemUpdates,
      }),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification preferences saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const _SectionTitle('Notification preferences'),
        SwitchListTile(
          title: const Text('Task assigned'),
          subtitle: const Text('When a task is assigned to you'),
          value: _taskAssigned,
          onChanged: (v) => setState(() => _taskAssigned = v),
          activeThumbColor: AppColors.primary,
        ),
        SwitchListTile(
          title: const Text('Task completed'),
          subtitle: const Text('When a task you posted is completed'),
          value: _taskCompleted,
          onChanged: (v) => setState(() => _taskCompleted = v),
          activeThumbColor: AppColors.primary,
        ),
        SwitchListTile(
          title: const Text('New message'),
          subtitle: const Text('When you receive a new chat message'),
          value: _newMessage,
          onChanged: (v) => setState(() => _newMessage = v),
          activeThumbColor: AppColors.primary,
        ),
        SwitchListTile(
          title: const Text('Payment received'),
          subtitle: const Text('When a payment is credited to your wallet'),
          value: _paymentReceived,
          onChanged: (v) => setState(() => _paymentReceived = v),
          activeThumbColor: AppColors.primary,
        ),
        SwitchListTile(
          title: const Text('SLA breach'),
          subtitle: const Text('When a task breaches its SLA deadline'),
          value: _slaBreach,
          onChanged: (v) => setState(() => _slaBreach = v),
          activeThumbColor: AppColors.primary,
        ),
        SwitchListTile(
          title: const Text('System updates'),
          subtitle: const Text('App updates and maintenance notices'),
          value: _systemUpdates,
          onChanged: (v) => setState(() => _systemUpdates = v),
          activeThumbColor: AppColors.primary,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _savePrefs,
          child: const Text('Save notification preferences'),
        ),
      ],
    );
  }
}

// ─── API Keys Tab ─────────────────────────────────────────────────────────────

class _ApiKeysTab extends StatefulWidget {
  const _ApiKeysTab();
  @override
  State<_ApiKeysTab> createState() => _ApiKeysTabState();
}

class _ApiKeysTabState extends State<_ApiKeysTab> {
  List<Map<String, dynamic>> _keys = [];
  bool _loading = true;
  String? _error;

  // For generation
  final _labelCtrl = TextEditingController();
  bool _generating = false;
  String? _newKeyFull; // shown once after generation

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKeys() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.instance.get('/api-keys');
      final raw = unwrap<dynamic>(resp);
      final list = raw is List ? raw : <dynamic>[];
      setState(() {
        _keys = list
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

  Future<void> _generate() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    setState(() {
      _generating = true;
      _newKeyFull = null;
    });
    try {
      final resp = await ApiService.instance
          .post('/api-keys', body: {'label': label});
      final data = unwrap<Map<String, dynamic>>(resp);
      final key = data['key']?.toString() ?? data['apiKey']?.toString() ?? '';
      setState(() {
        _newKeyFull = key;
        _labelCtrl.clear();
      });
      await _loadKeys();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _revoke(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke API key'),
        content: const Text(
            'This key will stop working immediately. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.delete('/api-keys/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key revoked')),
        );
      }
      await _loadKeys();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
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
        const _SectionTitle('Generate new key'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  hintText: 'Key label (e.g. "Production")',
                  prefixIcon: Icon(Icons.label_outline, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _generating ? null : _generate,
                child: _generating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Generate'),
              ),
            ),
          ],
        ),

        // Show full key once after generation
        if (_newKeyFull != null && _newKeyFull!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy this key now. It will not be shown again.',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.success),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _newKeyFull!,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: _newKeyFull!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Key copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        const _SectionTitle('Your API keys'),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _ErrorCard(error: _error!, onRetry: _loadKeys)
        else if (_keys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No API keys yet', style: TextStyle(color: sub)),
            ),
          )
        else
          ..._keys.map((k) {
            final id = k['id']?.toString() ?? '';
            final label = k['label']?.toString() ?? 'Unnamed';
            final prefix = k['prefix']?.toString() ?? 'ws_...';
            final lastUsed = k['lastUsedAt']?.toString() ?? 'Never';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.key_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '$prefix  |  Last used: $lastUsed',
                          style: TextStyle(fontSize: 11, color: sub),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _revoke(id),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger),
                    child: const Text('Revoke'),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ─── Webhooks Tab ─────────────────────────────────────────────────────────────

class _WebhooksTab extends StatefulWidget {
  const _WebhooksTab();
  @override
  State<_WebhooksTab> createState() => _WebhooksTabState();
}

class _WebhooksTabState extends State<_WebhooksTab> {
  List<Map<String, dynamic>> _webhooks = [];
  bool _loading = true;
  String? _error;

  final _urlCtrl = TextEditingController();
  final _eventsCtrl = TextEditingController();
  bool _adding = false;
  bool _showForm = false;

  @override
  void initState() {
    super.initState();
    _loadWebhooks();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _eventsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWebhooks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiService.instance.get('/webhooks');
      final raw = unwrap<dynamic>(resp);
      final list = raw is List ? raw : <dynamic>[];
      setState(() {
        _webhooks = list
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

  Future<void> _addWebhook() async {
    final url = _urlCtrl.text.trim();
    final events = _eventsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (url.isEmpty || events.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ApiService.instance.post('/webhooks', body: {
        'url': url,
        'events': events,
      });
      _urlCtrl.clear();
      _eventsCtrl.clear();
      setState(() => _showForm = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Webhook added')),
        );
      }
      await _loadWebhooks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteWebhook(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete webhook'),
        content: const Text(
            'This webhook will stop receiving events immediately.'),
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
      await ApiService.instance.delete('/webhooks/$id');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Webhook deleted')),
        );
      }
      await _loadWebhooks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(cleanError(e))),
        );
      }
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
        // Add button / form
        if (!_showForm)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add webhook'),
            ),
          )
        else ...[
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
                Text('New webhook',
                    style: t.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://example.com/webhook',
                    prefixIcon: Icon(Icons.link_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _eventsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Events (comma-separated)',
                    hintText:
                        'task.created, task.completed, payment.received',
                    prefixIcon:
                        Icon(Icons.flash_on_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _adding ? null : _addWebhook,
                        child: _adding
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Save webhook'),
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
          const SizedBox(height: 12),
        ],

        const _SectionTitle('Active webhooks'),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _ErrorCard(error: _error!, onRetry: _loadWebhooks)
        else if (_webhooks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No webhooks configured',
                  style: TextStyle(color: sub)),
            ),
          )
        else
          ..._webhooks.map((wh) {
            final id = wh['id']?.toString() ?? '';
            final url = wh['url']?.toString() ?? '';
            final events = (wh['events'] is List)
                ? (wh['events'] as List)
                    .map((e) => e.toString())
                    .toList()
                : <String>[];
            final active = wh['active'] == true;

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
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.webhook_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(url,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.success
                                        : AppColors.darkSubtext,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(active ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                        fontSize: 11, color: sub)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20, color: AppColors.danger),
                        onPressed: () => _deleteWebhook(id),
                      ),
                    ],
                  ),
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: events
                          .map((ev) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(ev,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ─── Integrations Tab ─────────────────────────────────────────────────────────

class _IntegrationsTab extends StatelessWidget {
  const _IntegrationsTab();

  static const _integrations = [
    _Integration(
      name: 'Slack',
      description: 'Get task notifications in your Slack channels',
      icon: Icons.tag_rounded,
      color: Color(0xFF4A154B),
    ),
    _Integration(
      name: 'Jira',
      description: 'Sync tasks with Jira issues and sprints',
      icon: Icons.bug_report_outlined,
      color: Color(0xFF0052CC),
    ),
    _Integration(
      name: 'Trello',
      description: 'Map tasks to Trello boards and cards',
      icon: Icons.dashboard_outlined,
      color: Color(0xFF0079BF),
    ),
    _Integration(
      name: 'Zapier',
      description: 'Connect WorkStream to 5000+ apps via Zapier',
      icon: Icons.electric_bolt_rounded,
      color: Color(0xFFFF4F00),
    ),
    _Integration(
      name: 'Google Sheets',
      description: 'Export task data and reports to Google Sheets',
      icon: Icons.table_chart_outlined,
      color: Color(0xFF0F9D58),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final sub = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        const _SectionTitle('Available integrations'),
        const SizedBox(height: 8),
        ..._integrations.map((integ) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: t.dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: integ.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(integ.icon, color: integ.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(integ.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(integ.description,
                            style: TextStyle(fontSize: 12, color: sub)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                '${integ.name} integration coming soon')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    child: const Text('Connect'),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

class _Integration {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  const _Integration({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.danger),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

void _showChangePassword(BuildContext context) {
  final currentPw = TextEditingController();
  final newPw = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
                final auth = ctx.read<AuthController>();
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
                    content: Text(
                        ok ? 'Password changed' : (auth.error ?? 'Failed')),
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
