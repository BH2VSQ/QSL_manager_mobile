import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'core/app_theme.dart';
import 'screens/app_shell.dart';
import 'services/github_update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clear any downloaded APK left behind by a previous update install.
  unawaited(GithubUpdateService.clearUpdateCache());
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
