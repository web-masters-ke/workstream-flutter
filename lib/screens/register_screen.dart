import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'main_shell.dart';
import 'otp_verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _terms = false;
  String _category = 'customer-support';

  static const _categories = [
    'customer-support',
    'sales',
    'data-entry',
    'social-media',
    'research',
    'moderation',
    'telemarketing',
    'other',
  ];

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_terms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms & Conditions')),
      );
      return;
    }
    final auth = context.read<AuthController>();
    final ok = await auth.register(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      password: _pw.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OtpVerifyScreen(
            identifier: _email.text.trim(),
            purpose: OtpPurpose.register,
          ),
        ),
        (_) => false,
      );
    } else {
      if (auth.status == AuthStatus.authenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const MainShell()),
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Registration failed')),
        );
      }
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
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 8),
                Text(
                  'Join WorkStream',
                  style: t.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Register as an agent and start earning.',
                  style: t.textTheme.bodyMedium?.copyWith(color: subtext),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: WsTextField(
                        controller: _first,
                        label: 'First name',
                        icon: Icons.person_outline,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WsTextField(
                        controller: _last,
                        label: 'Last name',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                WsTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'you@email.com',
                  icon: Icons.alternate_email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                WsTextField(
                  controller: _phone,
                  label: 'Phone number',
                  hint: '+254 700 000 000',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.replaceAll(RegExp(r'[^0-9]'), '').length < 9) {
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
                      child: Text('Category',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        prefixIcon:
                            Icon(Icons.category_outlined, size: 20),
                      ),
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? 'General'),
                    ),
                  ],
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
                      validator: (v) => (v == null || v.length < 6)
                          ? 'At least 6 characters'
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
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                WsTextField(
                  controller: _confirm,
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  validator: (v) {
                    if (v != _pw.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _terms,
                      onChanged: (v) => setState(() => _terms = v ?? false),
                      activeColor: AppColors.accent,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _terms = !_terms),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              style: t.textTheme.bodySmall
                                  ?.copyWith(color: subtext),
                              children: const [
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: auth.busy ? null : _submit,
                  child: auth.busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Create account'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
