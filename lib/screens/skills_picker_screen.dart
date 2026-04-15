import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';

class SkillsPickerScreen extends StatefulWidget {
  const SkillsPickerScreen({super.key});

  @override
  State<SkillsPickerScreen> createState() => _SkillsPickerScreenState();
}

class _SkillsPickerScreenState extends State<SkillsPickerScreen> {
  final _search = TextEditingController();
  late List<String> _selected;
  bool _busy = false;

  static const _allSkills = [
    'Customer Support',
    'Sales',
    'Data Entry',
    'Call Center',
    'Order Processing',
    'Lead Generation',
    'Telemarketing',
    'Appointment Setting',
    'Survey Research',
    'Quality Assurance',
    'KYC Review',
    'Social Media',
    'Content Moderation',
    'Technical Support',
    'Billing & Collections',
    'Translation',
    'Transcription',
    'Chat Support',
    'Email Support',
  ];

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(
      context.read<AuthController>().user?.skills ?? <String>[],
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final q = _search.text.toLowerCase();
    if (q.isEmpty) return _allSkills;
    return _allSkills
        .where((s) => s.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await context.read<AuthController>().updateSkills(_selected);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Skills updated')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select skills'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search skills...',
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selected
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () =>
                              setState(() => _selected.remove(s)),
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final skill = _filtered[i];
                final active = _selected.contains(skill);
                return CheckboxListTile(
                  value: active,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(skill);
                      } else {
                        _selected.remove(skill);
                      }
                    });
                  },
                  title: Text(skill),
                  activeColor: AppColors.primary,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: Icon(
                    active
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    size: 20,
                    color: active ? AppColors.primary : t.dividerColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
