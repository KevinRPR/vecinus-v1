import 'package:flutter/material.dart';

/// Centralized animation tokens to keep timing/curves consistent.
class AppAnimations {
  static const durationScreen = Duration(milliseconds: 450);
  static const durationButton = Duration(milliseconds: 120);
  static const durationStagger = Duration(milliseconds: 80);

  static const curveScreen = Curves.easeOutCubic;
  static const curveList = Curves.easeOutQuart;
  static const curveTap = Curves.fastOutSlowIn;

  static const double tapScale = 0.97;
}
