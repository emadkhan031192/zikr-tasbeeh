import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for all persisted state.
///
/// IMPORTANT CONTRACT (mirrored by the native Android code):
/// - Keys are stored exactly as written here. On Android the
///   shared_preferences plugin prefixes every key with "flutter.", so native
///   code must read "flutter.<key>".
/// - The native overlay service, accessibility service and reminder receivers
///   read and write these keys directly, so the JSON shapes below must not
///   change without updating the Kotlin side too.
class Storage {
  static const String keyCurrentDhikr = 'zikr.currentDhikr';
  static String dhikrKey(String id) => 'zikr.dhikr.$id';
  static const String keySettings = 'zikr.settings';
  static const String keyReminders = 'zikr.reminders';
  static const String keyHistory = 'zikr.history';
  static const String keyAllTime = 'zikr.allTime';
  static const String keyLastCountDate = 'zikr.lastCountDate';
  static const String keyOverlayPos = 'zikr.overlay.pos';
  static const String keyOverlayRunning = 'zikr.overlay.running';
  static const String keyOverlayMode = 'zikr.overlay.mode';
  static const String keyConditional = 'zikr.conditional';
  static const String keyBootCallback = 'zikr.bootCallback';
  static const String keySetupDone = 'zikr.setupDone';

  static SharedPreferences? _prefs;

  /// Must be called once at startup (and again inside background isolates).
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    final p = _prefs;
    if (p == null) {
      throw StateError('Storage.init() was not called');
    }
    return p;
  }

  /// Re-read from disk. Call before reading when another process (the
  /// overlay service) may have changed values.
  static Future<void> reload() => prefs.reload();

  static String? getString(String key) => prefs.getString(key);
  static Future<bool> setString(String key, String value) =>
      prefs.setString(key, value);
  static int? getInt(String key) => prefs.getInt(key);
  static Future<bool> setInt(String key, int value) =>
      prefs.setInt(key, value);
  static bool? getBool(String key) => prefs.getBool(key);
  static Future<bool> setBool(String key, bool value) =>
      prefs.setBool(key, value);

  static Map<String, dynamic>? getJson(String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setJson(String key, Map<String, dynamic> value) =>
      prefs.setString(key, jsonEncode(value));

  static List<dynamic> getJsonList(String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> setJsonList(String key, List<dynamic> value) =>
      prefs.setString(key, jsonEncode(value));

  static String todayKey([DateTime? when]) {
    final d = when ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Adds [delta] to today's total and the all-time total, and stamps the
  /// last-count date. Used by both the app and the native overlay.
  static Future<void> addToHistory(int delta) async {
    if (delta <= 0) return;
    final today = todayKey();
    final history = getJson(keyHistory) ?? <String, dynamic>{};
    history[today] = ((history[today] as num?)?.toInt() ?? 0) + delta;
    await setJson(keyHistory, history);
    final allTime = (getInt(keyAllTime) ?? 0) + delta;
    await setInt(keyAllTime, allTime);
    await setString(keyLastCountDate, today);
  }

  static int todayTotal() {
    final history = getJson(keyHistory);
    if (history == null) return 0;
    return (history[todayKey()] as num?)?.toInt() ?? 0;
  }

  static int allTimeTotal() => getInt(keyAllTime) ?? 0;

  /// Wipes everything. Used by "Reset all data".
  static Future<void> clearAll() => prefs.clear();
}
