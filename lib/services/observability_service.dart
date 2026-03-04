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
}
