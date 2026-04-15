import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/primitives.dart';
import 'admin_shell.dart';
import 'main_shell.dart';
import 'otp_verify_screen.dart';

/// Account type toggle — shown at the top of the register form.
enum _AccountType { agent, business }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Shared fields
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();

  // Business-only
  final _bizName = TextEditingController();

  bool _obscure = true;
  bool _terms = false;
  _AccountType _type = _AccountType.agent;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _pw.dispose();
    _confirm.dispose();
    _bizName.dispose();
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
    final isBusiness = _type == _AccountType.business;
    final ok = await auth.register(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      password: _pw.text,
      role: isBusiness ? 'BUSINESS' : 'AGENT',
      businessName: isBusiness ? _bizName.text.trim() : null,
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
        final isAdmin = auth.user?.isAdmin ?? false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => isAdmin ? const AdminShell() : const MainShell(),
          ),
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
    final isDark = t.brightness == Brightness.dark;
    final subtext =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;
    final isBusiness = _type == _AccountType.business;

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
                  isBusiness
                      ? 'Create a business account to post tasks and hire agents.'
                      : 'Register as a freelance agent and start earning.',
                  style:
                      t.textTheme.bodyMedium?.copyWith(color: subtext),
                ),
                const SizedBox(height: 20),

                // ── Account type selector ──────────────────────────
                _AccountTypeSelector(
                  value: _type,
                  onChanged: (v) => setState(() => _type = v),
                ),
                const SizedBox(height: 20),

                // ── Business name (business only) ──────────────────
                if (isBusiness) ...[
                  WsTextField(
                    controller: _bizName,
                    label: 'Business / Organisation name',
                    icon: Icons.business_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Business name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Name row ───────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: WsTextField(
                        controller: _first,
                        label: isBusiness ? 'Contact first name' : 'First name',
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

                // ── Password ───────────────────────────────────────
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
                        prefixIcon:
                            const Icon(Icons.lock_outline, size: 20),
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

                // ── Terms ──────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _terms,
                      onChanged: (v) =>
                          setState(() => _terms = v ?? false),
                      activeColor: AppColors.accent,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _terms = !_terms),
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
                              strokeWidth: 2.5,
                              color: Colors.white),
                        )
                      : Text(isBusiness
                          ? 'Create business account'
                          : 'Create agent account'),
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

// ─── Account type selector widget ────────────────────────────────────────────

class _AccountTypeSelector extends StatelessWidget {
  final _AccountType value;
  final ValueChanged<_AccountType> onChanged;

  const _AccountTypeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'I am joining as…',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TypeCard(
                icon: Icons.person_rounded,
                title: 'Agent',
                subtitle: 'Find work & earn',
                selected: value == _AccountType.agent,
                isDark: isDark,
                onTap: () => onChanged(_AccountType.agent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TypeCard(
                icon: Icons.business_rounded,
                title: 'Business',
                subtitle: 'Post tasks & hire',
                selected: value == _AccountType.business,
                isDark: isDark,
                onTap: () => onChanged(_AccountType.business),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.accent
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);
    final bgColor = selected
        ? AppColors.accent.withValues(alpha: 0.08)
        : (isDark ? AppColors.darkCard : AppColors.lightCard);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: borderColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.accent : (isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                ),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.accent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected
                    ? AppColors.accent
                    : (isDark ? AppColors.darkText : AppColors.lightText),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
