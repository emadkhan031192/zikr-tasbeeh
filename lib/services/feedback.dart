import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import '../models/settings.dart';

/// Haptic + click feedback for counting, honoring the user's settings.
class Feedback {
  static final AudioPlayer _player = AudioPlayer();

  static const List<int> _amplitudes = [64, 140, 255];

  static Future<void> tap(AppSettings s) async {
    if (s.vibration) {
      await _buzz(25, s.vibrationStrength);
    }
    if (s.sound) {
      await _click();
    }
  }

  static Future<void> milestone(AppSettings s) async {
    if (s.vibration) {
      await _buzz(80, s.vibrationStrength);
    }
    if (s.sound) {
      await _click();
    }
  }

  static Future<void> targetReached(AppSettings s) async {
    if (s.longVibrationAtTarget) {
      final ok = await _hasVibrator();
      if (ok) {
        try {
          await Vibration.vibrate(duration: 450);
        } catch (_) {
          // vibrator unavailable - stay silent
        }
      }
    } else {
      await tap(s);
      return;
    }
    if (s.sound) {
      await _click();
    }
  }

  static Future<void> _buzz(int durationMs, int strength) async {
    final ok = await _hasVibrator();
    if (!ok) return;
    try {
      await Vibration.vibrate(
        duration: durationMs,
        amplitude: _amplitudes[strength.clamp(0, 2)],
      );
    } catch (_) {
      // some devices reject amplitude - try without it
      try {
        await Vibration.vibrate(duration: durationMs);
      } catch (_) {
        // stay silent
      }
    }
  }

  static Future<bool> _hasVibrator() async {
    try {
      return await Vibration.hasVibrator();
    } catch (_) {
      return false;
    }
  }

  static Future<void> _click() async {
    try {
      await _player.play(AssetSource('sounds/click.wav'));
    } catch (_) {
      // audio unavailable - stay silent
    }
  }
}
