import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'main_shell.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idNumber = TextEditingController();
  final _address = TextEditingController();
  String _idType = 'National ID';
  XFile? _frontImage;
  XFile? _backImage;
  XFile? _selfie;
  bool _busy = false;

  static const _idTypes = [
    'National ID',
    'Passport',
    'Driver License',
    'Military ID',
  ];

  bool get _complete =>
      _frontImage != null && _backImage != null && _selfie != null;

  @override
  void dispose() {
    _idNumber.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pick(String which) async {
    final picker = ImagePicker();
    final source =
        which == 'selfie' ? ImageSource.camera : ImageSource.gallery;
    final file = await picker.pickImage(source: source, maxWidth: 1200);
    if (file == null) return;
    setState(() {
      switch (which) {
        case 'front':
          _frontImage = file;
          break;
        case 'back':
          _backImage = file;
          break;
        case 'selfie':
          _selfie = file;
          break;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_complete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload all required documents')),
      );
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    await auth.submitKyc(
      idType: _idType,
      idNumber: _idNumber.text.trim(),
      frontImageUrl: _frontImage?.path,
      backImageUrl: _backImage?.path,
      selfieUrl: _selfie?.path,
      address: _address.text.trim().isEmpty ? null : _address.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('KYC submitted for review')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your identity'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(builder: (_) => const MainShell()),
                (_) => false,
              );
            },
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: AppColors.primary, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We use your ID to pay out safely. This takes ~2 minutes.',
                        style: t.textTheme.bodyMedium?.copyWith(color: subtext),
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
                    child: Text('ID Type',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _idType,
                    decoration: const InputDecoration(
                      prefixIcon:
                          Icon(Icons.badge_outlined, size: 20),
                    ),
                    items: _idTypes
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _idType = v ?? 'National ID'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              WsTextField(
                controller: _idNumber,
                label: 'ID number',
                hint: 'e.g. 12345678',
                icon: Icons.numbers_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              WsTextField(
                controller: _address,
                label: 'Address (optional)',
                hint: 'Nairobi, Kenya',
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 20),
              _KycTile(
                title: '$_idType — front',
                subtitle: 'Clear photo. All corners visible.',
                done: _frontImage != null,
                fileName: _frontImage?.name,
                onTap: () => _pick('front'),
              ),
              const SizedBox(height: 12),
              _KycTile(
                title: '$_idType — back',
                subtitle: 'Back of your ID or passport photo page.',
                done: _backImage != null,
                fileName: _backImage?.name,
                onTap: () => _pick('back'),
              ),
              const SizedBox(height: 12),
              _KycTile(
                title: 'Selfie check',
                subtitle: 'Live selfie for biometric match.',
                done: _selfie != null,
                fileName: _selfie?.name,
                onTap: () => _pick('selfie'),
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
                    : const Text('Submit for review'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool done;
  final String? fileName;
  final VoidCallback onTap;
  const _KycTile({
    required this.title,
    required this.subtitle,
    required this.done,
    this.fileName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done ? AppColors.success : t.dividerColor,
            width: done ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (done ? AppColors.success : AppColors.primary)
                    .withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.camera_alt_outlined,
                color: done ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    done ? (fileName ?? 'Uploaded') : subtitle,
                    style: t.textTheme.bodySmall?.copyWith(color: subtext),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              done ? Icons.check_rounded : Icons.chevron_right_rounded,
              color: done ? AppColors.success : null,
            ),
          ],
        ),
      ),
    );
  }
}
