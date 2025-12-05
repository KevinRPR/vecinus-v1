import 'package:flutter/material.dart';

class FadeSlideTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Offset beginOffset;

  const FadeSlideTransition({
    super.key,
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0, 0.1),
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: beginOffset,
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  FadeSlidePageRoute({required Widget page})
      : super(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => page,
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.fastLinearToSlowEaseIn,
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
