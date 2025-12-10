import 'package:flutter/material.dart';

import 'app_animations.dart';

/// Fade + slide up (or custom offset) transition for screens or sections.
class FadeSlideTransition extends StatelessWidget {
  final Widget child;
  final Offset beginOffset;
  final Duration duration;
  final Curve curve;

  const FadeSlideTransition({
    super.key,
    required this.child,
    this.beginOffset = const Offset(0, 0.05),
    this.duration = AppAnimations.durationScreen,
    this.curve = AppAnimations.curveScreen,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: beginOffset * (1 - value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Scale + fade in, good for dialogs/cards/buttons.
class ScaleFadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double beginScale;

  const ScaleFadeIn({
    super.key,
    required this.child,
    this.duration = AppAnimations.durationScreen,
    this.curve = AppAnimations.curveScreen,
    this.beginScale = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        final scale = beginScale + (1 - beginScale) * value;
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}

/// Shared page route for smooth fade-slide transitions.
PageRouteBuilder<T> fadeSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppAnimations.durationScreen,
    reverseTransitionDuration: AppAnimations.durationScreen,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppAnimations.curveScreen,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
