import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.loadThemeMode();
  await NotificationService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Vecinus App',
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

const _brand = Color(0xff1d9bf0);
const _darkBackground = Color(0xff0d111a);
const _darkSurface = Color(0xff141a26);
const _darkCard = Color(0xff161d2b);
const _darkText = Color(0xffeef2fb);
const _darkTextMuted = Color(0xff9ca3b5);

final _lightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: GoogleFonts.poppins().fontFamily,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _brand,
    brightness: Brightness.light,
    background: const Color(0xfff7f4fb),
  ),
  scaffoldBackgroundColor: const Color(0xfff7f4fb),
  textTheme: GoogleFonts.poppinsTextTheme().apply(
    bodyColor: const Color(0xff0f172a),
    displayColor: const Color(0xff0f172a),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: const Color(0xff0f172a),
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: const Color(0xff0f172a),
    ),
  ),
  cardColor: Colors.white,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _brand,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _brand,
      side: const BorderSide(color: _brand),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xfff5f6fa),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
);

final _darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: GoogleFonts.poppins().fontFamily,
  scaffoldBackgroundColor: _darkBackground,
  colorScheme: ColorScheme.dark(
    primary: _brand,
    secondary: const Color(0xff4be3d0),
    background: _darkBackground,
    surface: _darkSurface,
    onBackground: _darkText,
    onSurface: _darkText,
  ),
  textTheme: GoogleFonts.poppinsTextTheme().apply(
    bodyColor: _darkText,
    displayColor: _darkText,
  ),
  cardColor: _darkCard,
  canvasColor: _darkSurface,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _brand,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _darkText,
      side: BorderSide(color: _darkText.withOpacity(0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _darkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: TextStyle(color: _darkTextMuted),
    labelStyle: TextStyle(color: _darkTextMuted),
  ),
  dividerColor: _darkTextMuted.withOpacity(0.25),
  iconTheme: const IconThemeData(color: _darkText),
  appBarTheme: AppBarTheme(
    backgroundColor: _darkSurface,
    foregroundColor: _darkText,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: _darkText,
    ),
  ),
);
