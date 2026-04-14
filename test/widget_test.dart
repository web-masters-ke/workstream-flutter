import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:workstream/controllers/auth_controller.dart';
import 'package:workstream/controllers/tasks_controller.dart';
import 'package:workstream/controllers/wallet_controller.dart';
import 'package:workstream/main.dart';
import 'package:workstream/theme/app_theme.dart';

void main() {
  testWidgets('WorkStream app boots', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(create: (_) => TasksController()),
          ChangeNotifierProvider(create: (_) => WalletController()),
        ],
        child: const WorkstreamApp(),
      ),
    );
    await tester.pump();
    expect(find.text('WorkStream'), findsWidgets);
  });
}
