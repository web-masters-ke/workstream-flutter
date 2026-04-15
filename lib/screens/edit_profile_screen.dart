import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'skills_picker_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  late final TextEditingController _headline;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _rate;

  String _currency = 'KES';
  static const _currencies = ['KES', 'USD', 'GBP'];

  XFile? _pickedAvatar;
  bool _busy = false;
  bool _dirty = false;

  // Availability per day: Mon=0 … Sun=6
  late List<bool> _availDays;
  late List<TimeOfDay> _availStart;
  late List<TimeOfDay> _availEnd;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthController>().user;
    _first = TextEditingController(text: user?.firstName ?? '');
    _last = TextEditingController(text: user?.lastName ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _bio = TextEditingController();
    _headline = TextEditingController();
    _city = TextEditingController();
    _country = TextEditingController();
    _rate = TextEditingController();

    _availDays = List.filled(7, false);
    _availStart =
        List.generate(7, (_) => const TimeOfDay(hour: 9, minute: 0));
    _availEnd =
        List.generate(7, (_) => const TimeOfDay(hour: 17, minute: 0));

    for (final c in [_first, _last, _phone, _bio, _headline, _city, _country, _rate]) {
      c.addListener(() => setState(() => _dirty = true));
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _bio.dispose();
    _headline.dispose();
    _city.dispose();
    _country.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_dirty && _pickedAvatar == null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Leave anyway?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (file != null) setState(() => _pickedAvatar = file);
  }

  Future<String?> _uploadAvatar(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      // Stub — real upload would use multipart
      final _ = await ApiService.instance.post('/media/upload', body: {
        'filename': file.name,
        'size': bytes.length,
      });
      return null; // return URL from response in real impl
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    String? avatarUrl;
    if (_pickedAvatar != null) {
      avatarUrl = await _uploadAvatar(_pickedAvatar!);
    }

    if (!mounted) return;
    final auth = context.read<AuthController>();
    final ok = await auth.updateProfile(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      phone: _phone.text.trim(),
      address: _city.text.trim().isNotEmpty
          ? '${_city.text.trim()}, ${_country.text.trim()}'.trim()
          : null,
      avatarUrl: avatarUrl,
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Profile updated' : 'Failed to save'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
          actions: [
            TextButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // ── Avatar ──────────────────────────────────────
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.18),
                          backgroundImage: _pickedAvatar != null
                              ? FileImage(File(_pickedAvatar!.path))
                              : null,
                          child: _pickedAvatar == null
                              ? Text(
                                  user?.initials ?? 'WS',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Name ─────────────────────────────────────────
                const _SectionLabel('Personal info'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: WsTextField(
                        controller: _first,
                        label: 'First name',
                        icon: Icons.person_outline,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WsTextField(
                        controller: _last,
                        label: 'Last name',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                WsTextField(
                  controller: _phone,
                  label: 'Phone',
                  hint: '+254 700 000 000',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                WsTextField(
                  controller: _headline,
                  label: 'Headline',
                  hint: 'e.g. Customer Support Specialist',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 14),
                // Bio
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 6),
                  child: Text('Bio',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                TextFormField(
                  controller: _bio,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Tell businesses a bit about yourself...',
                    prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: WsTextField(
                        controller: _city,
                        label: 'City',
                        hint: 'Nairobi',
                        icon: Icons.location_city_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WsTextField(
                        controller: _country,
                        label: 'Country',
                        hint: 'Kenya',
                        icon: Icons.flag_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Rate & Currency ───────────────────────────────
                const _SectionLabel('Rate'),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: WsTextField(
                        controller: _rate,
                        label: 'Hourly rate',
                        hint: '500',
                        icon: Icons.payments_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 6),
                            child: Text('Currency',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                  Icons.currency_exchange_rounded,
                                  size: 20),
                            ),
                            items: _currencies
                                .map((c) => DropdownMenuItem(
                                    value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _currency = v ?? 'KES';
                              _dirty = true;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Skills ───────────────────────────────────────
                const _SectionLabel('Skills'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (user?.skills ?? [])
                      .map((s) => _SkillChip(s))
                      .toList(),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const SkillsPickerScreen()),
                    );
                    setState(() => _dirty = true);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit Skills'),
                ),
                const SizedBox(height: 24),

                // ── Availability schedule ────────────────────────
                const _SectionLabel('Availability'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: t.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.dividerColor),
                  ),
                  child: Column(
                    children: List.generate(7, (i) {
                      return Column(
                        children: [
                          if (i > 0)
                            Divider(
                                height: 1, color: t.dividerColor),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 34,
                                  child: Text(_dayLabels[i],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ),
                                const SizedBox(width: 8),
                                Switch.adaptive(
                                  value: _availDays[i],
                                  activeThumbColor: AppColors.primary,
                                  activeTrackColor: AppColors.primary
                                      .withValues(alpha: 0.4),
                                  onChanged: (v) => setState(() {
                                    _availDays[i] = v;
                                    _dirty = true;
                                  }),
                                ),
                                if (_availDays[i]) ...[
                                  const Spacer(),
                                  _TimeChip(
                                    time: _availStart[i],
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _availStart[i],
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _availStart[i] = picked;
                                          _dirty = true;
                                        });
                                      }
                                    },
                                    subtext: subtext,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Text('–',
                                        style:
                                            TextStyle(color: subtext)),
                                  ),
                                  _TimeChip(
                                    time: _availEnd[i],
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _availEnd[i],
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _availEnd[i] = picked;
                                          _dirty = true;
                                        });
                                      }
                                    },
                                    subtext: subtext,
                                  ),
                                ] else
                                  Expanded(
                                    child: Text('Unavailable',
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            color: subtext,
                                            fontSize: 12)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
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
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Text(
      text.toUpperCase(),
      style: t.textTheme.labelSmall?.copyWith(
        color: t.brightness == Brightness.dark
            ? AppColors.darkSubtext
            : AppColors.lightSubtext,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12)),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;
  final Color subtext;
  const _TimeChip(
      {required this.time, required this.onTap, required this.subtext});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time.format(context),
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12),
        ),
      ),
    );
  }
}
