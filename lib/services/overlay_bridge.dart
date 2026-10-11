import 'package:flutter/services.dart';

import '../l10n/strings.dart';

/// Talks to the native Android overlay (foreground service + WindowManager).
///
/// The overlay itself is implemented natively (not with a plugin) so that
/// bubble dragging, edge snapping, notification actions and tap-through can
/// be controlled precisely. Counts are shared through SharedPreferences, so
/// [refreshOverlay] simply tells the service to re-read them.
class OverlayBridge {
  static const MethodChannel _ch = MethodChannel('zikr_tasbeeh/overlay');

  /// Starts the on-screen counter in [mode] ('bubble', 'panel' or
  /// 'fullscreen'). Returns false when the overlay permission is missing.
  static Future<bool> startOverlay({
    required String mode,
    required S s,
  }) async {
    try {
      final ok = await _ch.invokeMethod<bool>('startOverlay', {
        'mode': mode,
        'strings': {
          'title': s.t('notifTitle'),
          'plusOne': s.t('actionPlusOne'),
          'show': s.t('actionShow'),
          'hide': s.t('actionHide'),
          'stop': s.t('actionStop'),
          'progressOf': s.t('progressOf'),
          'toGoFmt': s.t('toGoFmt'),
          'targetReached': s.t('targetReached'),
          'roundLabel': s.t('roundLabel'),
        },
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> stopOverlay() async {
    try {
      await _ch.invokeMethod<void>('stopOverlay');
    } on PlatformException {
      // already stopped / service gone
    }
  }

  static Future<void> setOverlayMode(String mode) async {
    try {
      await _ch.invokeMethod<void>('setOverlayMode', {'mode': mode});
    } on PlatformException {
      // ignore
    }
  }

  /// Re-reads counts from storage and redraws the overlay views.
  static Future<void> refreshOverlay() async {
    try {
      await _ch.invokeMethod<void>('refreshOverlay');
    } on PlatformException {
      // overlay not running - nothing to refresh
    }
  }

  static Future<bool> isOverlayRunning() async {
    try {
      return await _ch.invokeMethod<bool>('isOverlayRunning') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> hasOverlayPermission() async {
    try {
      return await _ch.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _ch.invokeMethod<void>('requestOverlayPermission');
    } on PlatformException {
      // ignore
    }
  }
}
