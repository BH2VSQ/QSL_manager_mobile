import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'core/app_theme.dart';
import 'screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await AppController.create();
  runApp(QslManagerApp(controller: controller));
}

class QslManagerApp extends StatelessWidget {
  const QslManagerApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'QSL Manager Mobile',
          theme: buildConsoleLightTheme(),
          darkTheme: buildConsoleTheme(),
          themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: AppShell(controller: controller),
        );
      },
    );
  }
}
