import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'controllers/notifications_controller.dart';
import 'controllers/tasks_controller.dart';
import 'controllers/wallet_controller.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

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
    return MaterialApp(
      title: 'WorkStream',
      debugShowCheckedModeBanner: false,
      themeMode: controller.mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const SplashScreen(),
    );
  }
}
