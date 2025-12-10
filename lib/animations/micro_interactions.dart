import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'app_animations.dart';

/// Subtle horizontal shake for error states.
class ShakeOnError extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const ShakeOnError({super.key, required this.child, required this.trigger});

  @override
  State<ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<ShakeOnError>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  late final Animation<double> _offset = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant ShakeOnError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offset,
      builder: (_, child) =>
          Transform.translate(offset: Offset(_offset.value, 0), child: child),
      child: widget.child,
    );
  }
}

/// Lightweight success check using lottie (cached).
class SuccessCheck extends StatelessWidget {
  final double size;
  const SuccessCheck({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: RepaintBoundary(
        child: Lottie.asset(
          'assets/animations/success_check_soft.json',
          repeat: false,
          frameRate: FrameRate.max,
        ),
      ),
    );
  }
}

/// Soft floating empty-state icon using Lottie (expects asset to be present).
class EmptyFloat extends StatelessWidget {
  final double size;
  const EmptyFloat({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/animations/empty_box_float.json',
      height: size,
      repeat: true,
      frameRate: FrameRate.max,
    );
  }
}
