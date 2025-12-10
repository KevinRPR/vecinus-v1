import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerSkeleton extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;
  const ShimmerSkeleton({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white24 : Colors.black12;
    final highlight = isDark ? Colors.white38 : Colors.black26;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1200),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: base,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
