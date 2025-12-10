import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'app_animations.dart';

/// Helper to wrap list children with staggered slide+fade.
class StaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration duration;
  final Curve curve;
  final double verticalOffset;

  const StaggeredList({
    super.key,
    required this.children,
    this.duration = AppAnimations.durationScreen,
    this.curve = AppAnimations.curveList,
    this.verticalOffset = 24,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: Column(
        children: AnimationConfiguration.toStaggeredList(
          duration: duration,
          delay: AppAnimations.durationStagger,
          childAnimationBuilder: (widget) => SlideAnimation(
            verticalOffset: verticalOffset,
            curve: curve,
            child: FadeInAnimation(
              duration: duration,
              curve: curve,
              child: widget,
            ),
          ),
          children: children,
        ),
      ),
    );
  }
}
