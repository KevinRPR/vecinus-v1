import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'theme_controller.dart';
import 'preferences_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.loadThemeMode();
  await NotificationService.init();
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  const sentryEnabled =
      bool.fromEnvironment('SENTRY_ENABLED', defaultValue: true);
  final enableSentry = sentryEnabled && sentryDsn.isNotEmpty && !kDebugMode;

  if (enableSentry) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.environment =
            const String.fromEnvironment('APP_ENV', defaultValue: 'local');
      },
      appRunner: () => runApp(const MyApp()),
    );
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder(
          valueListenable: preferencesController.preferences,
          builder: (context, prefs, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Vecinus App',
              theme: AppTheme.light(highContrast: prefs.highContrast),
              darkTheme: AppTheme.dark(highContrast: prefs.highContrast),
              themeMode: mode,
              builder: (context, child) {
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(
                    textScaler: TextScaler.linear(prefs.textScale),
                    highContrast: prefs.highContrast,
                    accessibleNavigation: prefs.reduceMotion,
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
