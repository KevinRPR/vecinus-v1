import 'package:flutter/material.dart';

class AppColors {
  static const brandBlue600 = Color(0xff539091);
  static const brandBlue700 = Color(0xff477C7B);
  static const brandTeal500 = Color(0xff0A5D9B);
  static const brandTeal600 = Color(0xff084B7A);
  static const sunOrange500 = Color(0xffF3B176);
  static const sunOrange600 = Color(0xffE59B5E);

  static const bg = Color(0xffF7F6F2);
  static const surface = Color(0xffFFFFFF);
  static const surfaceAlt = Color(0xffF1F2F4);
  static const border = Color(0xffE3E6EA);
  static const textStrong = Color(0xff1F2937);
  static const textBody = Color(0xff334155);
  static const textMuted = Color(0xff667085);

  static const success = Color(0xff2F8F5B);
  static const warning = Color(0xffB7791F);
  static const error = Color(0xffC53030);
  static const info = brandTeal500;

  static const darkBg = Color(0xff0E141B);
  static const darkSurface = Color(0xff141B24);
  static const darkSurfaceAlt = Color(0xff182132);
  static const darkBorder = Color(0xff2A3441);
  static const darkTextStrong = Color(0xffE6E8EB);
  static const darkTextBody = Color(0xffCBD5E1);
  static const darkTextMuted = Color(0xff94A3B8);
}

class AppTheme {
  static const String fontFamily = 'TT Hoves Pro Trial';

  static ThemeData light({bool highContrast = false}) =>
      _buildTheme(brightness: Brightness.light, highContrast: highContrast);
  static ThemeData dark({bool highContrast = false}) =>
      _buildTheme(brightness: Brightness.dark, highContrast: highContrast);

  static ThemeData _buildTheme({
    required Brightness brightness,
    required bool highContrast,
  }) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.darkBg : AppColors.bg;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    var border = isDark ? AppColors.darkBorder : AppColors.border;
    var textStrong = isDark ? AppColors.darkTextStrong : AppColors.textStrong;
    var textBody = isDark ? AppColors.darkTextBody : AppColors.textBody;
    var textMuted = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

    if (highContrast) {
      textStrong = isDark ? Colors.white : Colors.black;
      textBody = isDark ? Colors.white : const Color(0xff0F172A);
      textMuted = isDark ? Colors.white70 : const Color(0xff1F2937);
      border = isDark ? Colors.white54 : const Color(0xff334155);
    }

    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue600,
      brightness: brightness,
      primary: AppColors.brandBlue600,
      secondary: AppColors.brandTeal500,
      tertiary: AppColors.sunOrange500,
      surface: surface,
      error: AppColors.error,
    );

    final colorScheme = baseScheme.copyWith(
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onTertiary: Colors.white,
      onSurface: textStrong,
      surfaceContainerHighest: surfaceAlt,
      onSurfaceVariant: textBody,
      outline: border,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      textTheme: _buildTextTheme(isDark: isDark, highContrast: highContrast),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textStrong,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textStrong,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 24,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandBlue600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandTeal600,
          side: const BorderSide(color: AppColors.brandTeal600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandTeal500,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        labelStyle: TextStyle(color: textMuted),
        hintStyle: TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.brandBlue600,
            width: 1.4,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: AppColors.brandBlue600.withValues(alpha: 0.12),
        labelStyle: TextStyle(
          color: textBody,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(color: textBody),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: StadiumBorder(side: BorderSide(color: border)),
      ),
      iconTheme: IconThemeData(color: textBody),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: textBody,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brandBlue600,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkSurfaceAlt : textStrong,
        contentTextStyle: TextStyle(
          color: isDark ? AppColors.darkTextStrong : Colors.white,
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required bool isDark,
    required bool highContrast,
  }) {
    final base = ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).textTheme.apply(fontFamily: fontFamily);
    var textStrong = isDark ? AppColors.darkTextStrong : AppColors.textStrong;
    var textBody = isDark ? AppColors.darkTextBody : AppColors.textBody;

    if (highContrast) {
      textStrong = isDark ? Colors.white : Colors.black;
      textBody = isDark ? Colors.white : const Color(0xff0F172A);
    }

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 15, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(fontSize: 13, height: 1.45),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    ).apply(
      bodyColor: textBody,
      displayColor: textStrong,
    );
  }
}
