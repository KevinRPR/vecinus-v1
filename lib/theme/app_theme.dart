import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color _primary = Color(0xff1d9bf0);
  static const Color _secondary = Color(0xff7dd3fc);
  static const Color _tertiary = Color(0xfff472b6);
  static const Color _surfaceDark = Color(0xff111827); // azul grisáceo, no negro
  static const Color _surfaceDarkMuted = Color(0xff1f2937);
  static const Color _surfaceLight = Color(0xfff7f9fc);
  static const Color _cardDark = Color(0xff1b2433);
  static const Color _cardLight = Colors.white;

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final colorScheme = _scheme(brightness);
    final textTheme = _textTheme(brightness);
    final cardColor = isDark ? _cardDark : _cardLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      fontFamily: 'Roboto',
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        foregroundColor: textTheme.titleLarge?.color,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        shadowColor: Colors.black.withOpacity(0.12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          shadowColor: Colors.black.withOpacity(0.12),
          elevation: 10,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: BorderSide(color: _primary.withOpacity(0.8)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _surfaceDarkMuted : const Color(0xfff4f6fb),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: _primary.withOpacity(0.8),
            width: 1.4,
          ),
        ),
        labelStyle: TextStyle(
          color: textTheme.bodyMedium?.color?.withOpacity(0.8),
        ),
      ),
      iconTheme: IconThemeData(
        color: textTheme.bodyLarge?.color?.withOpacity(0.9),
      ),
      dividerColor: colorScheme.outline.withOpacity(0.2),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        backgroundColor: cardColor,
        elevation: 0,
        selectedIconTheme: const IconThemeData(size: 26),
        unselectedIconTheme: const IconThemeData(size: 24),
        selectedItemColor: _primary,
        unselectedItemColor:
            textTheme.bodyMedium?.color?.withOpacity(0.6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? _cardDark : const Color(0xff0f172a),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      shadowColor: isDark
          ? Colors.black.withOpacity(0.45)
          : Colors.black.withOpacity(0.12),
    );
  }

  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: _primary,
      onPrimary: Colors.white,
      secondary: _secondary,
      onSecondary: Colors.black87,
      tertiary: _tertiary,
      onTertiary: Colors.white,
      error: const Color(0xfff97066),
      onError: Colors.white,
      background: isDark ? _surfaceDark : _surfaceLight,
      onBackground: isDark ? Colors.white : const Color(0xff0f172a),
      surface: isDark ? _surfaceDark : _cardLight,
      onSurface: isDark ? Colors.white : const Color(0xff0f172a),
      surfaceTint: _primary,
      outline: isDark ? Colors.white30 : Colors.black12,
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final baseColor =
        brightness == Brightness.dark ? Colors.white : const Color(0xff0f172a);
    return TextTheme(
      displayLarge: TextStyle(color: baseColor),
      displayMedium: TextStyle(color: baseColor),
      displaySmall: TextStyle(color: baseColor),
      headlineLarge: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: baseColor.withOpacity(0.9),
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: baseColor.withOpacity(0.92),
      ),
      bodyMedium: TextStyle(
        color: baseColor.withOpacity(0.78),
      ),
      bodySmall: TextStyle(
        color: baseColor.withOpacity(0.64),
      ),
      labelLarge: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
