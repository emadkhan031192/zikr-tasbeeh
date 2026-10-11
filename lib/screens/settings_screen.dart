import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/dhikr.dart';
import '../models/reminder.dart';
import '../models/settings.dart';
import '../services/counter.dart';
import '../services/reminders.dart';
import '../services/storage.dart';
import '../services/system_bridge.dart';
import '../theme.dart';

/// Everything configurable: counting, display, overlay, reminders and data.
class SettingsScreen extends StatefulWidget {
  final CounterService counter;

  const SettingsScreen({super.key, required this.counter});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  CounterService get c => widget.counter;
  Map<String, dynamic>? _conditional;

  @override
  void initState() {
    super.initState();
    _conditional = Storage.getJson(Storage.keyConditional);
  }

  Future<void> _update(AppSettings s) async {
    await c.updateSettings(s);
    await ReminderService.refreshFromStorage();
    await _applyConditional();
    if (mounted) setState(() {});
  }

  Future<void> _applyConditional() async {
    final cond = _conditional;
    if (cond != null && cond['enabled'] == true) {
      final lang = S(c.settings.language);
      await SystemBridge.scheduleConditional(
        hour: (cond['hour'] as num?)?.toInt() ?? 21,
        minute: (cond['minute'] as num?)?.toInt() ?? 0,
        title: lang.t('condTitle'),
        body: lang.t('condBody'),
        snoozeMin: c.settings.snoozeMinutes,
      );
    } else {
      await SystemBridge.cancelConditional();
    }
  }

  Future<void> _saveConditional(Map<String, dynamic>? cond) async {
    _conditional = cond;
    if (cond == null) {
      await Storage.setString(Storage.keyConditional, '');
    } else {
      await Storage.setJson(Storage.keyConditional, cond);
    }
    await _applyConditional();
    if (mounted) setState(() {});
  }

  Future<int?> _askNumber(String title, int initial,
      {int min = 1, int max = 999999}) async {
    final ctl = TextEditingController(text: '$initial');
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        final s = S(c.settings.language);
        return AlertDialog(
          backgroundColor: ZikrColors.card,
          title: Text(title),
          content: TextField(
            controller: ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.t('cancel')),
            ),
            TextButton(
              onPressed: () {
                final v = int.tryParse(ctl.text.trim());
                if (v == null || v < min || v > max) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(s.t('invalidNumber'))),
                  );
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: Text(s.t('set')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickConditionalTime() async {
    final cond = _conditional ?? {'enabled': true, 'hour': 21, 'minute': 0};
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (cond['hour'] as num?)?.toInt() ?? 21,
        minute: (cond['minute'] as num?)?.toInt() ?? 0,
      ),
    );
    if (t != null) {
      await _saveConditional({
        'enabled': cond['enabled'] == true,
        'hour': t.hour,
        'minute': t.minute,
      });
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = S(c.settings.language);
        final st = c.settings;
        return Scaffold(
          appBar: AppBar(title: Text(s.t('navSettings'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(s.t('counting')),
              _switchRow(s.t('vibration'), st.vibration,
                  (v) => _update(st..vibration = v)),
              _segmentedRow<int>(
                s.t('vibLight'),
                [s.t('vibLight'), s.t('vibMedium'), s.t('vibStrong')],
                [0, 1, 2],
                st.vibrationStrength,
                (v) => _update(st..vibrationStrength = v),
                enabled: st.vibration,
              ),
              _switchRow(s.t('soundClick'), st.sound,
                  (v) => _update(st..sound = v)),
              _switchRow(s.t('volumeButtons'), st.volumeButtons,
                  (v) => _update(st..volumeButtons = v),
                  note: s.t('volumeButtonsNote')),
              _segmentedRow<int>(
                s.t('stepSize'),
                ['+1', '+5', '+10'],
                [1, 5, 10],
                st.stepSize,
                (v) => _update(st..stepSize = v),
              ),
              _numberRow(s.t('defaultTarget'), '${st.defaultTarget}',
                  () async {
                final v = await _askNumber(
                    s.t('defaultTarget'), st.defaultTarget);
                if (v != null) {
                  await _update(st..defaultTarget = v);
                }
              }),
              _segmentedRow<String>(
                s.t('onTargetReached'),
                [s.t('otrStop'), s.t('otrNewRound'), s.t('otrNextDhikr')],
                ['stop', 'newRound', 'nextDhikr'],
                st.onTargetReached,
                (v) => _update(st..onTargetReached = v),
              ),
              _switchRow(s.t('longVibTarget'), st.longVibrationAtTarget,
                  (v) => _update(st..longVibrationAtTarget = v)),
              _segmentedRow<int>(
                s.t('milestone'),
                [s.t('milestoneOff'), s.t('every33'), s.t('every100')],
                [0, 33, 100],
                st.milestoneEvery,
                (v) => _update(st..milestoneEvery = v),
              ),
              _switchRow(s.t('lockReset'), st.lockReset,
                  (v) => _update(st..lockReset = v),
                  note: s.t('lockResetNote')),
              _switchRow(s.t('resetConfirmation'), st.resetConfirmation,
                  (v) => _update(st..resetConfirmation = v)),
              _switchRow(s.t('keepAwake'), st.keepScreenAwake,
                  (v) => _update(st..keepScreenAwake = v)),
              _section(s.t('display')),
              _themeRow(s, st),
              _segmentedRow<String>(
                s.t('digitSize'),
                [s.t('sizeSmall'), s.t('sizeNormal'), s.t('sizeLarge')],
                ['small', 'normal', 'large'],
                st.digitSize,
                (v) => _update(st..digitSize = v),
              ),
              _switchRow(s.t('showArabic'), st.showArabic,
                  (v) => _update(st..showArabic = v)),
              _switchRow(s.t('showTransliteration'),
                  st.showTransliteration,
                  (v) => _update(st..showTransliteration = v)),
              _switchRow(s.t('showMeaning'), st.showMeaning,
                  (v) => _update(st..showMeaning = v)),
              _segmentedRow<String>(
                s.t('language'),
                [s.t('langEn'), s.t('langUr'), s.t('langPs')],
                ['en', 'ur', 'ps'],
                st.language,
                (v) => _update(st..language = v),
              ),
              _section(s.t('overlay')),
              _segmentedRow<String>(
                s.t('defaultMode'),
                [
                  s.t('modeBubble'),
                  s.t('modePanel'),
                  s.t('modeFullscreen')
                ],
                ['bubble', 'panel', 'fullscreen'],
                st.overlayDefaultMode,
                (v) => _update(st..overlayDefaultMode = v),
              ),
              _sliderRow(
                s.t('bubbleSize'),
                st.bubbleSize,
                0.7,
                1.5,
                (v) => _update(st..bubbleSize = v),
              ),
              _sliderRow(
                s.t('bubbleOpacity'),
                st.bubbleOpacity,
                0.3,
                1.0,
                (v) => _update(st..bubbleOpacity = v),
              ),
              _switchRow(s.t('snapToEdge'), st.snapToEdge,
                  (v) => _update(st..snapToEdge = v)),
              _switchRow(s.t('hideInApp'), st.hideOverlayInApp,
                  (v) => _update(st..hideOverlayInApp = v)),
              _switchRow(s.t('autoStartBoot'), st.autoStartOnBoot,
                  (v) => _update(st..autoStartOnBoot = v)),
              _switchRow(s.t('tapThrough'), st.tapThroughWhenDimmed,
                  (v) => _update(st..tapThroughWhenDimmed = v)),
              _section(s.t('reminders')),
              _actionRow(
                Icons.add_alarm,
                s.t('addReminder'),
                _addReminder,
              ),
              _reminderList(s),
              _quickPresets(s),
              _prayerSettings(s, st),
              _conditionalRow(s),
              _switchRow(s.t('reminderSound'), st.reminderSound,
                  (v) => _update(st..reminderSound = v)),
              _switchRow(s.t('reminderVibration'), st.reminderVibration,
                  (v) => _update(st..reminderVibration = v)),
              _segmentedRow<int>(
                s.t('snoozeLabel'),
                ['5', '10', '15'],
                [5, 10, 15],
                st.snoozeMinutes,
                (v) => _update(st..snoozeMinutes = v),
              ),
              _segmentedRow<String>(
                s.t('tapActionLabel'),
                [s.t('tapOpenDhikr'), s.t('tapStartOverlay')],
                ['openDhikr', 'startOverlay'],
                st.reminderTapAction,
                (v) => _update(st..reminderTapAction = v),
              ),
              _section(s.t('history')),
              _numberRow(s.t('dailyGoal'), '${st.dailyGoal}', () async {
                final v = await _askNumber(s.t('dailyGoal'), st.dailyGoal,
                    min: 0);
                if (v != null) {
                  await _update(st..dailyGoal = v);
                }
              }),
              _actionRow(
                Icons.upload,
                s.t('exportBackup'),
                _exportBackup,
              ),
              _actionRow(
                Icons.download,
                s.t('importBackup'),
                _importBackup,
              ),
              _actionRow(
                Icons.delete_forever,
                s.t('resetAll'),
                _resetAll,
                danger: true,
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------- row widgets

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF22F5FF),
        ),
      ),
    );
  }

  Widget _switchRow(
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? note,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ZikrColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                note,
                style: const TextStyle(
                  color: ZikrColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _segmentedRow<T>(
    String title,
    List<String> labels,
    List<T> values,
    T current,
    ValueChanged<T> onChanged, {
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ZikrColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<T>(
                segments: [
                  for (var i = 0; i < labels.length; i++)
                    ButtonSegment<T>(
                      value: values[i],
                      label: Text(labels[i]),
                    ),
                ],
                selected: {current},
                onSelectionChanged: enabled
                    ? (set) => onChanged(set.first)
                    : null,
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF0A74FF).withValues(alpha: 0.3);
                    }
                    return ZikrColors.background;
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderRow(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: ZikrColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(color: ZikrColors.textMuted),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: 20,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _numberRow(String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: ZikrColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZikrColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: ZikrColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF22F5FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeRow(S s, AppSettings st) {
    const themes = ['cyan', 'green', 'orange', 'purple'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('colorTheme'),
            style: const TextStyle(
              color: ZikrColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: themes.map((name) {
              final accent = AccentTheme.of(name);
              final selected = st.theme == name;
              final label = {
                'cyan': s.t('themeCyan'),
                'green': s.t('themeGreen'),
                'orange': s.t('themeOrange'),
                'purple': s.t('themePurple'),
              }[name]!;
              return GestureDetector(
                onTap: () => _update(st..theme = name),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [accent.top, accent.bottom],
                        ),
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.glow.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? ZikrColors.textPrimary
                            : ZikrColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: ZikrColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZikrColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: danger
                  ? ZikrColors.danger
                  : ZikrColors.textPrimary,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color:
                    danger ? ZikrColors.danger : ZikrColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- reminders

  Widget _reminderList(S s) {
    final reminders = c.reminders;
    if (reminders.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ZikrColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ZikrColors.cardBorder),
        ),
        child: Text(
          s.t('noReminders'),
          style: const TextStyle(color: ZikrColors.textMuted),
        ),
      );
    }
    return Column(
      children: [
        for (final r in reminders)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZikrColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZikrColors.cardBorder),
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: r.enabled ? 1 : 0.4,
                  child: Text(
                    r.prayer != null ? '🕌' : r.time,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Color(0xFF22F5FF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: r.enabled ? 1 : 0.4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.prayer != null
                              ? s.t(_presetKeyFor(r.prayer!))
                              : dhikrById(r.dhikrId).transliteration,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ZikrColors.textPrimary,
                          ),
                        ),
                        Text(
                          _daysSummary(s, r),
                          style: const TextStyle(
                            fontSize: 12,
                            color: ZikrColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Switch(
                  value: r.enabled,
                  onChanged: (v) async {
                    r.enabled = v;
                    await c.saveReminders(c.reminders);
                    await ReminderService.refreshFromStorage();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.t('reminderSaved'))),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit,
                      color: ZikrColors.textMuted, size: 20),
                  onPressed: () => _editReminder(r),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: ZikrColors.danger, size: 20),
                  onPressed: () async {
                    final next = c.reminders.where((e) => e != r).toList();
                    await c.saveReminders(next);
                    await ReminderService.refreshFromStorage();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(s.t('reminderDeleted'))),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _presetKeyFor(String prayer) {
    switch (prayer) {
      case 'fajr':
        return 'afterFajr';
      case 'dhuhr':
        return 'afterZuhr';
      case 'asr':
        return 'afterAsr';
      case 'maghrib':
        return 'afterMaghrib';
      case 'isha':
        return 'afterIsha';
      default:
        return 'afterFajr';
    }
  }

  String _daysSummary(S s, Reminder r) {
    if (r.prayer != null) return s.t('prayerBased');
    if (r.days.isEmpty) return s.t('everyDay');
    final names = s.dayShort;
    final sorted = [...r.days]..sort();
    return sorted.map((d) => names[d - 1]).join(' ');
  }

  Widget _quickPresets(S s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('quickPresets'),
            style: const TextStyle(
              color: ZikrColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in reminderPresets)
                ActionChip(
                  label: Text(s.t(p.$1)),
                  onPressed: () => _addPreset(p),
                  backgroundColor: ZikrColors.background,
                  side: const BorderSide(color: ZikrColors.cardBorder),
                  labelStyle: const TextStyle(
                    color: ZikrColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addPreset(
      (String, String?, String, List<int>) preset) async {
    final s = S(c.settings.language);
    final r = Reminder(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      time: preset.$3,
      days: preset.$4,
      dhikrId: c.currentId,
      message: '',
      prayer: preset.$2,
    );
    final next = [...c.reminders, r];
    await c.saveReminders(next);
    await ReminderService.refreshFromStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('reminderSaved'))),
      );
    }
  }

  Future<void> _addReminder() async {
    final r = Reminder(
      id: 'r${DateTime.now().millisecondsSinceEpoch}',
      time: '08:00',
      days: [],
      dhikrId: c.currentId,
      message: '',
    );
    await _editReminder(r, isNew: true);
  }

  Future<void> _editReminder(Reminder r, {bool isNew = false}) async {
    final saved = await Navigator.push<Reminder>(
      context,
      MaterialPageRoute(
        builder: (_) => ReminderEditor(
          counter: c,
          reminder: Reminder(
            id: r.id,
            time: r.time,
            days: [...r.days],
            dhikrId: r.dhikrId,
            message: r.message,
            prayer: r.prayer,
            enabled: r.enabled,
          ),
          isNew: isNew,
        ),
      ),
    );
    if (saved == null) return;
    final next = [...c.reminders];
    final idx = next.indexWhere((e) => e.id == saved.id);
    if (idx >= 0) {
      next[idx] = saved;
    } else {
      next.add(saved);
    }
    await c.saveReminders(next);
    await ReminderService.refreshFromStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S(c.settings.language).t('reminderSaved'))),
      );
    }
  }

  Widget _prayerSettings(S s, AppSettings st) {
    final times = ReminderService.prayerTimesToday(st);
    String fmt(DateTime? t) => t == null
        ? '--:--'
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('prayerSettings'),
            style: const TextStyle(
              color: ZikrColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _textField(
            s.t('cityLabel'),
            st.prayerCity,
            (v) => _update(st..prayerCity = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _textField(
                  s.t('latLabel'),
                  '${st.prayerLat}',
                  (v) {
                    final d = double.tryParse(v);
                    if (d != null) _update(st..prayerLat = d);
                  },
                  number: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _textField(
                  s.t('lngLabel'),
                  '${st.prayerLng}',
                  (v) {
                    final d = double.tryParse(v);
                    if (d != null) _update(st..prayerLng = d);
                  },
                  number: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.t('prayerNote'),
            style: const TextStyle(
              color: ZikrColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              for (final k in prayerKeys)
                Text(
                  '${s.t(_presetKeyFor(k))}: ${fmt(times[k])}',
                  style: const TextStyle(
                    color: ZikrColors.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textField(
    String label,
    String initial,
    ValueChanged<String> onSubmitted, {
    bool number = false,
  }) {
    return TextField(
      key: ValueKey('$label$initial'),
      controller: TextEditingController(text: initial),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: ZikrColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ZikrColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ZikrColors.cardBorder),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onSubmitted: onSubmitted,
    );
  }

  Widget _conditionalRow(S s) {
    final cond = _conditional;
    final enabled = cond?['enabled'] == true;
    final time =
        '${((cond?['hour'] as num?)?.toInt() ?? 21).toString().padLeft(2, '0')}:${((cond?['minute'] as num?)?.toInt() ?? 0).toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.t('notCountedTitle'),
                  style: const TextStyle(
                    color: ZikrColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: enabled ? _pickConditionalTime : null,
                child: Text(
                  time,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF22F5FF),
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: (v) async {
                  if (v) {
                    await _pickConditionalTime();
                    final c2 = _conditional ?? {};
                    c2['enabled'] = true;
                    await _saveConditional(
                        Map<String, dynamic>.from(c2));
                  } else {
                    await _saveConditional(null);
                  }
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              s.t('notCountedDesc'),
              style: const TextStyle(
                color: ZikrColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------- data

  Future<void> _exportBackup() async {
    final s = S(c.settings.language);
    final path = await SystemBridge.exportBackup(c.exportJson());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path != null ? '${s.t('exportOk')}\n$path' : s.t('importFail'),
        ),
      ),
    );
  }

  Future<void> _importBackup() async {
    final s = S(c.settings.language);
    final raw = await SystemBridge.importBackup();
    if (!mounted) return;
    if (raw == null || raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('importFail'))),
      );
      return;
    }
    final ok = await c.importJson(raw);
    await ReminderService.refreshFromStorage();
    await _applyConditional();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ok ? s.t('importOk') : s.t('importFail'))),
    );
  }

  Future<void> _resetAll() async {
    final s = S(c.settings.language);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZikrColors.card,
        title: Text(s.t('resetAllTitle')),
        content: Text(s.t('resetAllBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              s.t('confirmReset'),
              style: const TextStyle(color: ZikrColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await Storage.clearAll();
    await c.init();
    await ReminderService.refreshFromStorage();
    await _saveConditional(null);
    if (mounted) setState(() {});
  }
}

/// Full-screen editor for one reminder.
class ReminderEditor extends StatefulWidget {
  final CounterService counter;
  final Reminder reminder;
  final bool isNew;

  const ReminderEditor({
    super.key,
    required this.counter,
    required this.reminder,
    required this.isNew,
  });

  @override
  State<ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<ReminderEditor> {
  late Reminder r;
  late TextEditingController _msgCtl;

  @override
  void initState() {
    super.initState();
    r = widget.reminder;
    _msgCtl = TextEditingController(text: r.message);
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.counter.settings.language);
    final parts = r.time.split(':');
    final tod = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t(widget.isNew ? 'addReminder' : 'editReminder')),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              r.message = _msgCtl.text.trim();
              Navigator.pop(context, r);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(s.t('timeLabel')),
            trailing: Text(
              r.prayer != null
                  ? s.t('prayerBased')
                  : '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: Color(0xFF22F5FF),
              ),
            ),
            onTap: r.prayer != null
                ? null
                : () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: tod,
                    );
                    if (t != null) {
                      setState(() {
                        r.time =
                            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
          ),
          const Divider(color: ZikrColors.cardBorder),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.t('repeatLabel'),
              style: const TextStyle(
                color: ZikrColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(s.dayShort[d - 1]),
                  selected: r.days.contains(d),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        r.days.add(d);
                      } else {
                        r.days.remove(d);
                      }
                    });
                  },
                ),
            ],
          ),
          if (r.days.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                s.t('everyDay'),
                style: const TextStyle(
                  color: ZikrColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          const Divider(color: ZikrColors.cardBorder),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.t('prayerBased'),
              style: const TextStyle(
                color: ZikrColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<String?>(
            value: r.prayer,
            isExpanded: true,
            dropdownColor: ZikrColors.card,
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(s.t('timeLabel')),
              ),
              for (final k in prayerKeys)
                DropdownMenuItem<String?>(
                  value: k,
                  child: Text(s.t(_presetKey(k))),
                ),
            ],
            onChanged: (v) => setState(() => r.prayer = v),
          ),
          const Divider(color: ZikrColors.cardBorder),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.t('dhikrLabel'),
              style: const TextStyle(
                color: ZikrColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<String>(
            value: r.dhikrId,
            isExpanded: true,
            dropdownColor: ZikrColors.card,
            items: [
              for (final d in dhikrPresets)
                DropdownMenuItem(
                  value: d.id,
                  child: Text(d.transliteration),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => r.dhikrId = v);
            },
          ),
          const Divider(color: ZikrColors.cardBorder),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              s.t('messageLabel'),
              style: const TextStyle(
                color: ZikrColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextField(
            controller: _msgCtl,
            decoration: InputDecoration(
              hintText: s.t('messageHint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(s.t('enableLabel')),
            value: r.enabled,
            onChanged: (v) => setState(() => r.enabled = v),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              r.message = _msgCtl.text.trim();
              Navigator.pop(context, r);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A74FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(s.t('save')),
          ),
        ],
      ),
    );
  }

  String _presetKey(String prayer) {
    switch (prayer) {
      case 'fajr':
        return 'afterFajr';
      case 'dhuhr':
        return 'afterZuhr';
      case 'asr':
        return 'afterAsr';
      case 'maghrib':
        return 'afterMaghrib';
      case 'isha':
        return 'afterIsha';
      default:
        return 'afterFajr';
    }
  }
}
