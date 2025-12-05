import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  await themeController.loadThemeMode();

  runApp(
    ChangeNotifierProvider.value(
      value: themeController,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (_, controller, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Vecinus App',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
