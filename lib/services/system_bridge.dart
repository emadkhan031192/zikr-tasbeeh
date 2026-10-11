import 'package:flutter/services.dart';

/// System-level helpers implemented natively: permission status, settings
/// pages, the conditional daily reminder alarm, backup import/export and the
/// keep-screen-awake flag.
class SystemBridge {
  static const MethodChannel _ch = MethodChannel('zikr_tasbeeh/system');

  /// Returns a map with booleans:
  /// overlay, notifications, exactAlarm, batteryIgnored, accessibility.
  /// Never throws - returns all-false on failure so the UI never crashes.
  static Future<Map<String, bool>> getPermissionStatus() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>(
        'getPermissionStatus',
      );
      if (m == null) return _allFalse;
      return {
        'overlay': m['overlay'] == true,
        'notifications': m['notifications'] == true,
        'exactAlarm': m['exactAlarm'] == true,
        'batteryIgnored': m['batteryIgnored'] == true,
        'accessibility': m['accessibility'] == true,
      };
    } on PlatformException {
      return _allFalse;
    }
  }

  static const Map<String, bool> _allFalse = {
    'overlay': false,
    'notifications': false,
    'exactAlarm': false,
    'batteryIgnored': false,
    'accessibility': false,
  };

  static Future<void> _open(String method) async {
    try {
      await _ch.invokeMethod<void>(method);
    } on PlatformException {
      // settings page unavailable - stay silent, UI explains
    }
  }

  static Future<void> openOverlaySettings() => _open('openOverlaySettings');
  static Future<void> openNotificationSettings() =>
      _open('openNotificationSettings');
  static Future<void> openExactAlarmSettings() =>
      _open('openExactAlarmSettings');
  static Future<void> openBatterySettings() => _open('openBatterySettings');
  static Future<void> openAccessibilitySettings() =>
      _open('openAccessibilitySettings');
  static Future<void> openAppDetailsSettings() =>
      _open('openAppDetailsSettings');

  static Future<void> requestIgnoreBatteryOptimizations() =>
      _open('requestIgnoreBatteryOptimizations');

  static Future<void> setKeepScreenAwake(bool awake) async {
    try {
      await _ch.invokeMethod<void>('setKeepScreenAwake', {'awake': awake});
    } on PlatformException {
      // ignore
    }
  }

  /// Schedules the native "remind me if I have not counted today" alarm.
  static Future<void> scheduleConditional({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required int snoozeMin,
  }) async {
    try {
      await _ch.invokeMethod<void>('scheduleConditional', {
        'hour': hour,
        'minute': minute,
        'title': title,
        'body': body,
        'snoozeMin': snoozeMin,
      });
    } on PlatformException {
      // ignore - reminders stay best-effort
    }
  }

  static Future<void> cancelConditional() => _open('cancelConditional');

  /// Writes [json] to `Downloads/ZikrTasbeeh/backup-<date>.json` via MediaStore.
  /// Returns the display path, or null on failure.
  static Future<String?> exportBackup(String json) async {
    try {
      return await _ch.invokeMethod<String>('exportBackup', {'json': json});
    } on PlatformException {
      return null;
    }
  }

  /// Opens the system file picker; returns the chosen file's JSON or null.
  static Future<String?> importBackup() async {
    try {
      return await _ch.invokeMethod<String>('importBackup');
    } on PlatformException {
      return null;
    }
  }

  static Future<String> getAppVersion() async {
    try {
      return await _ch.invokeMethod<String>('getAppVersion') ?? '1.0.0';
    } on PlatformException {
      return '1.0.0';
    }
  }

  /// Payload left by a native notification tap (conditional reminder).
  /// Returns it once and clears it.
  static Future<String?> takePendingPayload() async {
    try {
      return await _ch.invokeMethod<String>('takePendingPayload');
    } on PlatformException {
      return null;
    }
  }
}
