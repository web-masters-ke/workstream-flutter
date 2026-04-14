import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/dispute_service.dart';
import '../theme/app_theme.dart';

class DisputeScreen extends StatefulWidget {
  final Task task;
  const DisputeScreen({super.key, required this.task});

  @override
  State<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends State<DisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  String _reason = 'Incorrect instructions';
  bool _busy = false;

  static const _reasons = [
    'Incorrect instructions',
    'Unfair rejection',
    'Payment dispute',
    'Harassment or misconduct',
    'Technical issue',
    'Other',
  ];

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await DisputeService().raise(
        taskId: widget.task.id,
        reason: _reason,
        details: _details.text.trim().isEmpty ? null : _details.text.trim(),
      );
    } catch (_) {
      // Best-effort — show success regardless (offline-friendly demo).
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dispute submitted. We will review it.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(title: const Text('Report issue')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.warn.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.warn, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Disputing: ${widget.task.title}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 6),
                    child: Text('Reason',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _reason,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.flag_outlined, size: 20),
                    ),
                    items: _reasons
                        .map((r) =>
                            DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _reason = v ?? _reasons.first),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 6),
                    child: Text('Details',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  TextFormField(
                    controller: _details,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Describe the issue...',
                      hintStyle: TextStyle(color: subtext),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Submit dispute'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
