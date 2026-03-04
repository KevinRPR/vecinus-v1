import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppPerf {
  const AppPerf._();

  static bool reduceEffects(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media?.disableAnimations ?? false) return true;
    if (media?.accessibleNavigation ?? false) return true;
    final shortestSide = media?.size.shortestSide ?? 0;
    if (shortestSide > 0 && shortestSide < 360) return true;
    final features =
        SchedulerBinding.instance.platformDispatcher.accessibilityFeatures;
    if (features.disableAnimations) return true;
    return false;
  }

  static double blurSigma(BuildContext context, double normal) {
    return reduceEffects(context) ? 0 : normal;
  }
}
