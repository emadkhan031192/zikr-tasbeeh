import 'dart:convert';

import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'screens/about_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/counter.dart';
import 'services/overlay_bridge.dart';
import 'services/system_bridge.dart';
import 'theme.dart';

/// App shell: bottom navigation, RTL handling, reminder-tap routing.
class ZikrApp extends StatefulWidget {
  final CounterService counter;

  const ZikrApp({super.key, required this.counter});

  /// Lets notification handlers jump to a tab from anywhere.
  static void Function(int tab)? goToTab;

  /// Routes a reminder notification tap: either starts the overlay or opens
  /// the app on the reminder's dhikr.
  static Future<void> handleReminderPayload(
    CounterService counter,
    Map<String, dynamic> payload,
  ) async {
    final tap = payload['tap'] as String? ?? 'openDhikr';
    if (tap == 'startOverlay') {
      final s = S(counter.settings.language);
      try {
        if (await OverlayBridge.hasOverlayPermission()) {
          await OverlayBridge.startOverlay(
            mode: counter.settings.overlayDefaultMode,
            s: s,
          );
          await counter.refreshOverlayRunning();
        }
      } catch (_) {
        // overlay stays best-effort
      }
    }
    final dhikrId = payload['dhikrId'] as String?;
    if (dhikrId != null && dhikrId.isNotEmpty) {
      await counter.selectDhikr(dhikrId);
    }
    goToTab?.call(0);
  }

  @override
  State<ZikrApp> createState() => _ZikrAppState();
}

class _ZikrAppState extends State<ZikrApp> {
  int _tab = 0;
  bool _awakeApplied = false;

  @override
  void initState() {
    super.initState();
    ZikrApp.goToTab = (t) {
      if (mounted) setState(() => _tab = t);
    };
    // A native (conditional-reminder) notification may have launched us.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainPayload());
  }

  Future<void> _drainPayload() async {
    try {
      final raw = await SystemBridge.takePendingPayload();
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) {
        await ZikrApp.handleReminderPayload(widget.counter, data);
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.counter,
      builder: (context, _) {
        final lang = widget.counter.settings.language;
        final s = S(lang);
        final wantAwake = widget.counter.settings.keepScreenAwake;
        if (wantAwake != _awakeApplied) {
          _awakeApplied = wantAwake;
          SystemBridge.setKeepScreenAwake(wantAwake);
        }
        return Directionality(
          textDirection:
              S.isRtl(lang) ? TextDirection.rtl : TextDirection.ltr,
          child: MaterialApp(
            title: s.t('appName'),
            theme: buildTheme(),
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: IndexedStack(
                index: _tab,
                children: [
                  HomeScreen(counter: widget.counter),
                  HistoryScreen(counter: widget.counter),
                  SettingsScreen(counter: widget.counter),
                  AboutScreen(counter: widget.counter),
                ],
              ),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _tab,
                type: BottomNavigationBarType.fixed,
                onTap: (i) => setState(() => _tab = i),
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.touch_app),
                    label: s.t('navCounter'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.bar_chart),
                    label: s.t('navHistory'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.settings),
                    label: s.t('navSettings'),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.info_outline),
                    label: s.t('navAbout'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
