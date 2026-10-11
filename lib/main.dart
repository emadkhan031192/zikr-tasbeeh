import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'background.dart';
import 'services/counter.dart';
import 'services/reminders.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();

  final counter = CounterService();
  await counter.init();

  // Handle notification taps (reminder -> open dhikr or start overlay).
  ReminderService.onPayloadTap = (payload) {
    ZikrApp.handleReminderPayload(counter, payload);
  };

  // Register the headless callback used by the BOOT_COMPLETED receiver to
  // re-schedule reminders after a reboot.
  try {
    final handle = PluginUtilities.getCallbackHandle(bootRescheduleCallback);
    if (handle != null) {
      await Storage.setInt(Storage.keyBootCallback, handle.toRawHandle());
    }
  } catch (_) {
    // boot rescheduling stays best-effort
  }

  runApp(ZikrApp(counter: counter));
}
