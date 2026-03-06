import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class AppHaptics {
  static bool _checked = false;
  static bool _hasVibrator = false;
  static bool _hasAmplitude = false;

  static Future<void> selection() => _vibrate(
        durationMs: 60,
        amplitude: 200,
        pattern: const [0, 20, 30, 20],
        intensities: const [0, 160, 0, 200],
      );

  static Future<void> impact() => _vibrate(
        durationMs: 100,
        amplitude: 255,
        pattern: const [0, 35, 40, 45],
        intensities: const [0, 180, 0, 255],
      );

  static Future<void> confirm() => _vibrate(
        durationMs: 40,
        amplitude: 140,
        pattern: const [0, 20],
        intensities: const [0, 140],
      );

  static Future<void> _ensureSupport() async {
    if (_checked) return;
    _hasVibrator = await Vibration.hasVibrator();
    _hasAmplitude = await Vibration.hasAmplitudeControl();
    _checked = true;
  }

  static Future<void> _vibrate({
    required int durationMs,
    int? amplitude,
    List<int>? pattern,
    List<int>? intensities,
  }) async {
    try {
      await _ensureSupport();
      if (_hasVibrator && pattern != null) {
        if (_hasAmplitude && intensities != null) {
          await Vibration.vibrate(
            pattern: pattern,
            intensities: intensities,
          );
          return;
        }
        await Vibration.vibrate(pattern: pattern);
        return;
      }
      if (_hasVibrator) {
        if (_hasAmplitude && amplitude != null) {
          await Vibration.vibrate(duration: durationMs, amplitude: amplitude);
          return;
        }
        await Vibration.vibrate(duration: durationMs);
        return;
      }
      if (pattern != null) {
        await Vibration.vibrate(pattern: pattern);
        return;
      }
      await Vibration.vibrate(duration: durationMs);
    } catch (_) {}
    HapticFeedback.vibrate();
  }
}
