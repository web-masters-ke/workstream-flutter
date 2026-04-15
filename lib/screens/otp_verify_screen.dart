import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'main_shell.dart';

enum OtpPurpose { register, resetPassword }

class OtpVerifyScreen extends StatefulWidget {
  final String identifier;
  final OtpPurpose purpose;
  const OtpVerifyScreen({
    super.key,
    required this.identifier,
    required this.purpose,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _digits = List.generate(6, (_) => TextEditingController());
  final _focuses = List.generate(6, (_) => FocusNode());
  final _pwKey = GlobalKey<FormState>();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _otpVerified = false;

  @override
  void dispose() {
    for (final c in _digits) {
      c.dispose();
    }
    for (final f in _focuses) {
      f.dispose();
    }
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  String get _otp => _digits.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (_otp.length < 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter all 6 digits')));
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthController>();

    if (widget.purpose == OtpPurpose.register) {
      final ok =
          await auth.verifyOtp(identifier: widget.identifier, otp: _otp);
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const MainShell()),
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Invalid code')),
        );
      }
    } else {
      // Password reset: verify then show new-password form
      final ok =
          await auth.verifyOtp(identifier: widget.identifier, otp: _otp);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) _otpVerified = true;
      });
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Invalid code')),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_pwKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    final ok = await auth.resetPassword(
      identifier: widget.identifier,
      otp: _otp,
      newPassword: _newPw.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Please sign in.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Reset failed')),
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
      appBar: AppBar(
        title: Text(widget.purpose == OtpPurpose.register
            ? 'Verify account'
            : 'Reset password'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _otpVerified ? _newPasswordForm(t, subtext) : _otpForm(t, subtext),
        ),
      ),
    );
  }

  Widget _otpForm(ThemeData t, Color subtext) {
    return ListView(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.sms_outlined,
              size: 32, color: AppColors.primary),
        ),
        const SizedBox(height: 20),
        Text(
          'Enter verification code',
          style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to ${widget.identifier}',
          style: t.textTheme.bodyMedium?.copyWith(color: subtext),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              child: TextField(
                controller: _digits[i],
                focusNode: _focuses[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: t.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) {
                    _focuses[i + 1].requestFocus();
                  }
                  if (v.isEmpty && i > 0) {
                    _focuses[i - 1].requestFocus();
                  }
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _busy ? null : _verifyOtp,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Verify'),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code resent')),
              );
            },
            child: Text('Resend code', style: TextStyle(color: subtext)),
          ),
        ),
      ],
    );
  }

  Widget _newPasswordForm(ThemeData t, Color subtext) {
    return Form(
      key: _pwKey,
      child: ListView(
        children: [
          const SizedBox(height: 24),
          Text(
            'Set a new password',
            style:
                t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a strong password for your account.',
            style: t.textTheme.bodyMedium?.copyWith(color: subtext),
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text('New password',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              TextFormField(
                controller: _newPw,
                obscureText: _obscure,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'At least 6 characters' : null,
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
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 6),
                child: Text('Confirm password',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              TextFormField(
                controller: _confirmPw,
                obscureText: _obscure,
                validator: (v) {
                  if (v != _newPw.text) return 'Passwords do not match';
                  return null;
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _resetPassword,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Reset password'),
          ),
        ],
      ),
    );
  }
}
