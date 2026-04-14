import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../controllers/tasks_controller.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';

class TaskSubmitScreen extends StatefulWidget {
  final Task task;
  const TaskSubmitScreen({super.key, required this.task});

  @override
  State<TaskSubmitScreen> createState() => _TaskSubmitScreenState();
}

class _TaskSubmitScreenState extends State<TaskSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notes = TextEditingController();
  String _outcome = 'Completed successfully';
  XFile? _attachment;
  bool _busy = false;

  static const _outcomes = [
    'Completed successfully',
    'Partially completed',
    'Could not reach customer',
    'Customer refused',
    'Technical error',
  ];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file != null) setState(() => _attachment = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final ctrl = context.read<TasksController>();
    final ok = await ctrl.submit(
      widget.task.id,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      outcome: _outcome,
      attachmentUrl: _attachment?.path,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work submitted for review')),
      );
      Navigator.of(context)
        ..pop() // back from submit
        ..pop(); // back from detail
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.error ?? 'Submission failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(title: const Text('Submit work')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined,
                        color: AppColors.accent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.task.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Outcome picker
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 6),
                    child: Text('Outcome',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _outcome,
                    decoration: const InputDecoration(
                      prefixIcon:
                          Icon(Icons.check_circle_outline, size: 20),
                    ),
                    items: _outcomes
                        .map((o) =>
                            DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _outcome = v ?? _outcomes.first),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Notes
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 6),
                    child: Text('Notes',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  TextFormField(
                    controller: _notes,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Describe what you did...',
                      hintStyle: TextStyle(color: subtext),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Photo attachment
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 6),
                    child: Text('Attachment (optional)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  InkWell(
                    onTap: _pickPhoto,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: t.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.dividerColor),
                      ),
                      child: _attachment == null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: subtext),
                                const SizedBox(width: 8),
                                Text('Add photo',
                                    style: TextStyle(color: subtext)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _attachment!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () =>
                                      setState(() => _attachment = null),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text('Submit work'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
