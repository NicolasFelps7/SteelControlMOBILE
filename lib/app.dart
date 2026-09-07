import 'package:flutter/material.dart';

import 'core/app_strings.dart';
import 'core/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/app_controller.dart';

class SteelControlApp extends StatelessWidget {
  const SteelControlApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        key: ValueKey<bool>(controller.isAuthenticated),
        title: 'SteelControl',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => AppStringsScope(
          language: controller.language,
          child: child ?? const SizedBox.shrink(),
        ),
        home: controller.isAuthenticated
            ? HomeShell(controller: controller)
            : LoginScreen(controller: controller),
      ),
    );
  }
}
