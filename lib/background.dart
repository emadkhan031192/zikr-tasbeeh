import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models/reminder.dart';
import 'models/settings.dart';
import 'services/reminders.dart';
import 'services/storage.dart';

/// Headless entry point run from the BOOT_COMPLETED receiver.
///
/// Android clears all scheduled alarms on reboot, so the native receiver
/// spins up a headless Flutter engine and runs this to re-schedule every
/// reminder (recomputing prayer times for the new day with the offline adhan
/// package). Must stay a top-level function and keep the vm:entry-point
/// pragma so it survives tree-shaking.
@pragma('vm:entry-point')
Future<void> bootRescheduleCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  try {
    final settings =
        AppSettings.fromJson(Storage.getJson(Storage.keySettings) ?? {});
    final reminders = Storage.getJsonList(Storage.keyReminders)
        .whereType<Map<String, dynamic>>()
        .map(Reminder.fromJson)
        .toList();
    await ReminderService.rescheduleAll(
      settings: settings,
      reminders: reminders,
    );
  } catch (_) {
    // never crash a boot receiver
  }
  try {
    await const MethodChannel('zikr_tasbeeh/boot').invokeMethod('bootDone');
  } catch (_) {
    // native side may already be gone
  }
}
