import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_animations.dart';

/// Tap scale effect with optional haptic feedback.
class TapEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  const TapEffect({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<TapEffect> createState() => _TapEffectState();
}

class _TapEffectState extends State<TapEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppAnimations.durationButton,
    lowerBound: AppAnimations.tapScale,
    upperBound: 1,
    value: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _animateTap() async {
    if (!widget.enabled) return;
    await _controller.reverse();
    await _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _animateTap();
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Transform.scale(
          scale: _controller.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
