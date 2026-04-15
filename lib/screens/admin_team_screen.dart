import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';

class _Agent {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String role;
  final bool available;
  final double rating;
  final int tasksCompleted;
  final String? avatarUrl;

  _Agent({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    required this.available,
    required this.rating,
    required this.tasksCompleted,
    this.avatarUrl,
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

    return _Agent(
      id: j['id']?.toString() ?? '',
      firstName: j['firstName']?.toString() ?? '',
      lastName: j['lastName']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      role: j['role']?.toString() ?? 'AGENT',
      available: j['available'] == true,
      rating: d(j['rating']),
      tasksCompleted: i(j['tasksCompleted']),
      avatarUrl: j['avatarUrl']?.toString(),
    );
  }
}

class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({super.key});

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  List<_Agent> _agents = [];
  bool _loading = true;
  String? _error;
  String _search = '';

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
      setState(() {
        _agents = list
            .whereType<Map<String, dynamic>>()
            .map(_Agent.fromJson)
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Agent> get _filtered {
    if (_search.isEmpty) return _agents;
    final q = _search.toLowerCase();
    return _agents
        .where((a) =>
            a.fullName.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q) ||
            a.role.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text('${_agents.length}'),
              backgroundColor: AppColors.accent.withValues(alpha: 0.12),
              labelStyle: const TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search agents...',
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
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 40),
                            const SizedBox(height: 12),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.danger)),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? EmptyState(
                            icon: Icons.groups_outlined,
                            title: _search.isEmpty
                                ? 'No agents yet'
                                : 'No results',
                            message: _search.isEmpty
                                ? 'Agents will appear here once added.'
                                : 'Try a different search term.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) =>
                                  _AgentTile(agent: _filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  final _Agent agent;
  const _AgentTile({required this.agent});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.accent.withValues(alpha: 0.18),
            backgroundImage: agent.avatarUrl != null
                ? NetworkImage(agent.avatarUrl!)
                : null,
            child: agent.avatarUrl == null
                ? Text(
                    agent.initials,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
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
              decoration: BoxDecoration(
                color: agent.available
                    ? AppColors.success
                    : AppColors.lightSubtext,
                shape: BoxShape.circle,
                border: Border.all(
                    color: t.scaffoldBackgroundColor, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        agent.fullName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(agent.email, style: TextStyle(color: subtext, fontSize: 12)),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  agent.role,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.star_rounded,
                  size: 13, color: AppColors.warn),
              const SizedBox(width: 2),
              Text(
                NumberFormat('0.0').format(agent.rating),
                style: TextStyle(fontSize: 12, color: subtext),
              ),
              const SizedBox(width: 8),
              Icon(Icons.check_circle_outline_rounded,
                  size: 13, color: subtext),
              const SizedBox(width: 2),
              Text(
                '${agent.tasksCompleted}',
                style: TextStyle(fontSize: 12, color: subtext),
              ),
            ],
          ),
        ],
      ),
      trailing: Icon(
        agent.available
            ? Icons.circle_rounded
            : Icons.remove_circle_outline_rounded,
        size: 14,
        color: agent.available ? AppColors.success : subtext,
      ),
    );
  }
}
