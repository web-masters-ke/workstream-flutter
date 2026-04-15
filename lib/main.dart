import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/notifications_controller.dart';
import 'controllers/tasks_controller.dart';
import 'controllers/wallet_controller.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => TasksController()),
        ChangeNotifierProvider(create: (_) => WalletController()),
        ChangeNotifierProvider(create: (_) => NotificationsController()),
      ],
      child: const WorkstreamApp(),
    ),
  );
}

class WorkstreamApp extends StatelessWidget {
  const WorkstreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    // Register the auth-expired callback once the widget is wired up
    ApiService.instance.onAuthExpired = () {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    };
    return MaterialApp(
      title: 'WorkStream',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: controller.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
