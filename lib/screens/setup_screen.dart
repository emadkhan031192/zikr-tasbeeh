import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/counter.dart';
import '../services/system_bridge.dart';
import '../theme.dart';

/// First-run setup: one row per permission with a green check or a red
/// "Allow" button that opens the right Android settings page. Statuses are
/// re-checked whenever the user returns to the app. Nothing here ever
/// crashes when a permission is denied - each row explains what stops
/// working without it.
class SetupScreen extends StatefulWidget {
  final CounterService counter;

  const SetupScreen({super.key, required this.counter});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with WidgetsBindingObserver {
  Map<String, bool>? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final st = await SystemBridge.getPermissionStatus();
    if (mounted) {
      setState(() {
        _status = st;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.counter.settings.language);
    final st = _status;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('setupTitle'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  s.t('setupSubtitle'),
                  style: const TextStyle(
                    color: ZikrColors.textMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _row(
                  s,
                  title: s.t('permOverlay'),
                  why: s.t('permOverlayWhy'),
                  granted: st?['overlay'] ?? false,
                  optional: false,
                  onAllow: SystemBridge.openOverlaySettings,
                ),
                _row(
                  s,
                  title: s.t('permNotif'),
                  why: s.t('permNotifWhy'),
                  granted: st?['notifications'] ?? false,
                  optional: false,
                  onAllow: SystemBridge.openNotificationSettings,
                ),
                _row(
                  s,
                  title: s.t('permAlarm'),
                  why: s.t('permAlarmWhy'),
                  granted: st?['exactAlarm'] ?? false,
                  optional: false,
                  onAllow: SystemBridge.openExactAlarmSettings,
                ),
                _row(
                  s,
                  title: s.t('permBattery'),
                  why: s.t('permBatteryWhy'),
                  granted: st?['batteryIgnored'] ?? false,
                  optional: false,
                  onAllow:
                      SystemBridge.requestIgnoreBatteryOptimizations,
                ),
                _row(
                  s,
                  title: s.t('permA11y'),
                  why: '${s.t('permA11yWhy')}\n\n${s.t('permA11yNote')}',
                  granted: st?['accessibility'] ?? false,
                  optional: true,
                  onAllow: SystemBridge.openAccessibilitySettings,
                ),
                const SizedBox(height: 8),
                Text(
                  s.t('setupRecheck'),
                  style: const TextStyle(
                    color: ZikrColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(
    S s, {
    required String title,
    required String why,
    required bool granted,
    required bool optional,
    required VoidCallback onAllow,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: ZikrColors.textPrimary,
                        ),
                      ),
                    ),
                    if (optional)
                      Container(
                        margin:
                            const EdgeInsetsDirectional.only(start: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ZikrColors.cardBorder,
                          ),
                        ),
                        child: Text(
                          s.t('optional'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: ZikrColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              granted
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: ZikrColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          s.t('grantedLabel'),
                          style: const TextStyle(
                            color: ZikrColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: onAllow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZikrColors.danger,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(s.t('allowBtn')),
                    ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            why,
            style: const TextStyle(
              color: ZikrColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
