import 'package:sentry_flutter/sentry_flutter.dart';

class ObservabilityService {
  const ObservabilityService._();

  static Future<void> logEvent(
    String name, {
    Map<String, Object?>? data,
  }) async {
    if (!Sentry.isEnabled) return;
    await Sentry.addBreadcrumb(
      Breadcrumb(
        message: name,
        category: 'event',
        data: data,
        level: SentryLevel.info,
      ),
    );
  }

  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, Object?>? data,
  }) async {
    if (!Sentry.isEnabled) return;
    await Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        if (context != null && context.trim().isNotEmpty) {
          scope.setTag('context', context);
        }
        if (data != null && data.isNotEmpty) {
          scope.setContexts('details', data);
        }
      },
    );
  }
}
