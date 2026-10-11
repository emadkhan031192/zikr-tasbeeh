import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/strings.dart';
import '../models/dhikr.dart';
import '../models/reminder.dart';
import '../models/settings.dart';
import 'storage.dart';
import 'system_bridge.dart';

/// Dhikr reminders built on flutter_local_notifications.
///
/// - Fixed-time reminders repeat weekly (per selected weekday).
/// - Prayer-based reminders are computed offline with the adhan package
///   (Karachi method, Hanafi Asr) for the next 7 days.
/// - Everything is re-scheduled on BOOT_COMPLETED through the headless
///   [bootRescheduleCallback] in background.dart, because Android clears
///   scheduled alarms on reboot.
/// - Notification actions: Done (dismiss) and Snooze (re-fire after the
///   configured minutes), both work even when the app was killed.
class ReminderService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Set by the app: handles a tap on a notification body.
  static void Function(Map<String, dynamic> payload)? onPayloadTap;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundResponse,
    );
    const channel = AndroidNotificationChannel(
      'zikr_reminders',
      'Dhikr reminders',
      description: 'Dhikr reminders from Noor Tasbeeh',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _ready = true;
  }

  // ------------------------------------------------------------ scheduling

  /// Re-reads settings + reminders from storage and re-schedules everything.
  static Future<void> refreshFromStorage() async {
    final settings =
        AppSettings.fromJson(Storage.getJson(Storage.keySettings) ?? {});
    final reminders = Storage.getJsonList(Storage.keyReminders)
        .whereType<Map<String, dynamic>>()
        .map(Reminder.fromJson)
        .toList();
    await rescheduleAll(settings: settings, reminders: reminders);
  }

  static Future<void> rescheduleAll({
    required AppSettings settings,
    required List<Reminder> reminders,
  }) async {
    await init();
    await _plugin.cancelAll();
    final s = S(settings.language);
    final exactOk = await _exactAlarmAllowed();
    final mode = exactOk
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final r in reminders) {
      if (!r.enabled) continue;
      try {
        await _schedule(s, settings, r, mode);
      } catch (_) {
        // one bad reminder must not break the rest
      }
    }
  }

  static Future<bool> _exactAlarmAllowed() async {
    final st = await SystemBridge.getPermissionStatus();
    return st['exactAlarm'] ?? false;
  }

  static Future<void> _schedule(
    S s,
    AppSettings settings,
    Reminder r,
    AndroidScheduleMode mode,
  ) async {
    final base = r.id.hashCode & 0x0fffffff;
    final dhikr = dhikrById(r.dhikrId);
    final title = r.message.isNotEmpty ? r.message : s.t('condTitle');
    final body = '${dhikr.transliteration} · ${s.t('tapOpenDhikr')}';
    final payload = jsonEncode({
      'kind': 'reminder',
      'id': r.id,
      'base': base,
      'dhikrId': r.dhikrId,
      'tap': settings.reminderTapAction,
      'title': title,
      'body': body,
      'snoozeMin': settings.snoozeMinutes,
    });
    final details = _details(s, settings);
    if (r.prayer != null) {
      final now = tz.TZDateTime.now(tz.local);
      for (var d = 0; d < 7; d++) {
        final day = DateTime.now().add(Duration(days: d));
        final t = prayerTime(day, settings, r.prayer!);
        if (t == null) continue;
        final when = tz.TZDateTime.from(t, tz.local);
        if (when.isBefore(now.add(const Duration(minutes: 1)))) continue;
        await _zoned(
          id: base + 100 + d,
          title: title,
          body: body,
          when: when,
          details: details,
          mode: mode,
          payload: payload,
        );
      }
    } else {
      final days = r.days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : r.days;
      for (final wd in days) {
        final when = _nextWeekday(wd, r.hour, r.minute);
        await _zoned(
          id: base + wd,
          title: title,
          body: body,
          when: when,
          details: details,
          mode: mode,
          payload: payload,
          match: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  static Future<void> _zoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    required AndroidScheduleMode mode,
    required String payload,
    DateTimeComponents? match,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: mode,
        title: title,
        body: body,
        payload: payload,
        matchDateTimeComponents: match,
      );
    } catch (_) {
      // exact alarms can throw when the permission was revoked; retry inexact
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        try {
          await _plugin.zonedSchedule(
            id: id,
            scheduledDate: when,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: title,
            body: body,
            payload: payload,
            matchDateTimeComponents: match,
          );
        } catch (_) {
          // best effort
        }
      }
    }
  }

  static tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (when.weekday != weekday || !when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    return when;
  }

  static NotificationDetails _details(S s, AppSettings settings) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'zikr_reminders',
        'Dhikr reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: settings.reminderSound,
        enableVibration: settings.reminderVibration,
        actions: [
          AndroidNotificationAction('done', s.t('actionDone')),
          AndroidNotificationAction('snooze', s.t('actionSnooze')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- responses

  static void _onResponse(NotificationResponse r) {
    if (r.actionId == 'snooze' || r.actionId == 'done') {
      _handleAction(r);
      return;
    }
    final payload = r.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) {
        onPayloadTap?.call(data);
      }
    } catch (_) {
      // ignore malformed payloads
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onBackgroundResponse(NotificationResponse r) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Storage.init();
    await init();
    await _handleAction(r);
  }

  static Future<void> _handleAction(NotificationResponse r) async {
    if (r.actionId == 'done') {
      await _plugin.cancel(r.id ?? 0);
      return;
    }
    if (r.actionId != 'snooze') return;
    final payload = r.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final settings =
          AppSettings.fromJson(Storage.getJson(Storage.keySettings) ?? {});
      final s = S(settings.language);
      final snoozeMin =
          (data['snoozeMin'] as num?)?.toInt() ?? settings.snoozeMinutes;
      final base = (data['base'] as num?)?.toInt() ?? 0;
      final when =
          tz.TZDateTime.now(tz.local).add(Duration(minutes: snoozeMin));
      await _zoned(
        id: base + 500,
        title: (data['title'] as String?) ?? s.t('condTitle'),
        body: (data['body'] as String?) ?? '',
        when: when,
        details: _details(s, settings),
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {
      // best effort
    }
  }

  // ----------------------------------------------------------- prayer times

  /// Offline prayer time for [day] using the Karachi method and Hanafi Asr.
  /// Returns null when [prayerKey] is unknown or the calculation fails.
  static DateTime? prayerTime(
    DateTime day,
    AppSettings settings,
    String prayerKey,
  ) {
    try {
      final params = CalculationMethod.karachi.getParameters();
      params.madhab = Madhab.hanafi;
      final pt = PrayerTimes(
        Coordinates(settings.prayerLat, settings.prayerLng),
        DateComponents(day.year, day.month, day.day),
        params,
      );
      switch (prayerKey) {
        case 'fajr':
          return pt.fajr;
        case 'dhuhr':
          return pt.dhuhr;
        case 'asr':
          return pt.asr;
        case 'maghrib':
          return pt.maghrib;
        case 'isha':
          return pt.isha;
      }
    } catch (_) {
      // fall through
    }
    return null;
  }

  /// Today's prayer times for the settings preview. Keys: fajr, dhuhr, asr,
  /// maghrib, isha.
  static Map<String, DateTime> prayerTimesToday(AppSettings settings) {
    final out = <String, DateTime>{};
    final now = DateTime.now();
    for (final k in prayerKeys) {
      final t = prayerTime(now, settings, k);
      if (t != null) out[k] = t;
    }
    return out;
  }
}
