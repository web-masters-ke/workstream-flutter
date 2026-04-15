import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../controllers/auth_controller.dart';
import '../services/push_service.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import 'admin_shell.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboarded = prefs.getBool(PrefsKeys.onboarded) ?? false;

      if (!mounted) return;
      final auth = context.read<AuthController>();
      // Timeout bootstrap so the splash never hangs forever
      await auth.bootstrap().timeout(
        const Duration(seconds: 8),
        onTimeout: () {/* proceed with whatever state we have */},
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      if (!onboarded) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
        );
        return;
      }
      if (auth.status == AuthStatus.authenticated) {
        // fire-and-forget realtime + push registration
        unawaited(RealtimeService.instance.connect());
        unawaited(PushService.instance.init());
        final isAdmin = auth.user?.isAdmin ?? false;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                isAdmin ? const AdminShell() : const MainShell(),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        );
      }
    } catch (_) {
      // If anything goes wrong, go to login
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDeep, AppColors.primary],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'WorkStream',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppMeta.tagline,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

