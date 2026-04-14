import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'otp_verify_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    final ok = await auth.requestPasswordReset(_id.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OtpVerifyScreen(
            identifier: _id.text.trim(),
            purpose: OtpPurpose.resetPassword,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Failed to send code')),
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
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock_reset_rounded,
                      size: 32, color: AppColors.accent),
                ),
                const SizedBox(height: 20),
                Text(
                  'Forgot your password?',
                  style: t.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email or phone and we\'ll send a verification code.',
                  style: t.textTheme.bodyMedium?.copyWith(color: subtext),
                ),
                const SizedBox(height: 24),
                WsTextField(
                  controller: _id,
                  label: 'Email or phone',
                  hint: 'agent@workstream.app',
                  icon: Icons.alternate_email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                      : const Text('Send reset code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
