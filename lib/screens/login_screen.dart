import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'forgot_password_screen.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _usePhone = false;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = await auth.login(
      identifier: _id.text.trim(),
      password: _pw.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainShell()),
        (_) => false,
      );
    } else {
      final rawError = auth.error ?? '';
      final String message;
      if (rawError.contains('401') ||
          rawError.toLowerCase().contains('unauthorized') ||
          rawError.toLowerCase().contains('invalid credentials')) {
        message = 'Incorrect email or password.';
      } else if (rawError.contains('403') ||
          rawError.toLowerCase().contains('suspended') ||
          rawError.toLowerCase().contains('forbidden')) {
        message = 'Your account has been suspended. Contact support.';
      } else if (rawError.contains('404') ||
          rawError.toLowerCase().contains('not found')) {
        message =
            'No account found with this email. Register instead?';
      } else if (rawError.isNotEmpty) {
        message = rawError;
      } else {
        message = 'Login failed. Please try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final t = Theme.of(context);
    final subtext = t.brightness == Brightness.dark
        ? AppColors.darkSubtext
        : AppColors.lightSubtext;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 32),
                const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 40),
                const SizedBox(height: 16),
                Text(
                  'Welcome back',
                  style: t.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to pick up tasks and check your wallet.',
                  style: t.textTheme.bodyMedium?.copyWith(color: subtext),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: t.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.dividerColor),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _segment('Email', !_usePhone,
                          () => setState(() => _usePhone = false)),
                      _segment('Phone', _usePhone,
                          () => setState(() => _usePhone = true)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                WsTextField(
                  controller: _id,
                  label: _usePhone ? 'Phone number' : 'Email address',
                  hint: _usePhone ? '+254 700 000 000' : 'agent@workstream.app',
                  icon: _usePhone
                      ? Icons.phone_outlined
                      : Icons.alternate_email_outlined,
                  keyboardType: _usePhone
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Required';
                    if (!_usePhone && !s.contains('@')) return 'Enter a valid email';
                    if (_usePhone && s.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
                      return 'Enter a valid phone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 6),
                      child: Text('Password',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    TextFormField(
                      controller: _pw,
                      obscureText: _obscure,
                      validator: (v) => (v == null || v.length < 4)
                          ? 'At least 4 characters'
                          : null,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: auth.busy ? null : _submit,
                  child: auth.busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Sign in'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New to WorkStream?',
                        style: TextStyle(color: subtext)),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: active ? AppColors.accent : null,
            ),
          ),
        ),
      ),
    );
  }
}
