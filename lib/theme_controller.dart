import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._internal();
  static final ThemeController _instance = ThemeController._internal();
  factory ThemeController() => _instance;

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  void setThemeMode(ThemeMode mode) => themeMode.value = mode;

  void toggleDark(bool isDark) =>
      themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
}

final themeController = ThemeController();
