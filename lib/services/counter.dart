import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/dhikr.dart';
import '../models/reminder.dart';
import '../models/settings.dart';
import 'feedback.dart';
import 'overlay_bridge.dart';
import 'storage.dart';

/// The heart of the app: per-dhikr counts, targets, rounds, history and
/// settings. SharedPreferences is the single source of truth so the native
/// overlay service (which may run while this app is dead) can read and write
/// the same values.
class CounterService extends ChangeNotifier {
  static const int maxCount = 999999;

  AppSettings settings = AppSettings();
  final Map<String, DhikrState> states = {};
  String currentId = dhikrPresets.first.id;
  List<Reminder> reminders = [];
  bool overlayRunning = false;

  Timer? _syncTimer;
  bool _disposed = false;

  DhikrPreset get current => dhikrById(currentId);
  DhikrState get state => states[currentId] ??= _freshState(current);

  int get todayTotal => Storage.todayTotal();
  int get allTimeTotal => Storage.allTimeTotal();

  DhikrState _freshState(DhikrPreset d) => DhikrState.initial(
        d.isCustom ? settings.defaultTarget : d.defaultTarget,
      );

  Future<void> init() async {
    await Storage.init();
    await _loadAll();
    overlayRunning = await OverlayBridge.isOverlayRunning();
    _syncTimer?.cancel();
    // While the overlay is up it can change counts behind our back;
    // re-read them regularly so the app never shows stale numbers.
    _syncTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!_disposed && overlayRunning) {
        syncCountsOnly();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    settings = AppSettings.fromJson(
      Storage.getJson(Storage.keySettings) ?? {},
    );
    currentId = Storage.getString(Storage.keyCurrentDhikr) ??
        dhikrPresets.first.id;
    states.clear();
    for (final d in dhikrPresets) {
      final saved = Storage.getJson(Storage.dhikrKey(d.id));
      states[d.id] =
          saved != null ? DhikrState.fromJson(saved) : _freshState(d);
    }
    reminders = Storage.getJsonList(Storage.keyReminders)
        .whereType<Map<String, dynamic>>()
        .map(Reminder.fromJson)
        .toList();
  }

  /// Re-reads counts (and current dhikr) written by the overlay service.
  Future<void> syncCountsOnly() async {
    try {
      await Storage.reload();
    } catch (_) {
      return;
    }
    final before = _countsSignature();
    final newCurrent =
        Storage.getString(Storage.keyCurrentDhikr) ?? currentId;
    currentId = newCurrent;
    for (final d in dhikrPresets) {
      final saved = Storage.getJson(Storage.dhikrKey(d.id));
      if (saved != null) {
        states[d.id] = DhikrState.fromJson(saved);
      }
    }
    if (_countsSignature() != before) {
      notifyListeners();
    }
  }

  String _countsSignature() {
    final sb = StringBuffer(currentId);
    for (final d in dhikrPresets) {
      final s = states[d.id];
      sb.write('|${d.id}:${s?.count}:${s?.target}:${s?.rounds}');
    }
    return sb.toString();
  }

  Future<void> _saveState(String id) =>
      Storage.setJson(Storage.dhikrKey(id), states[id]!.toJson());

  Future<void> _saveCurrent() =>
      Storage.setString(Storage.keyCurrentDhikr, currentId);

  // ---------------------------------------------------------------- counting

  Future<void> increment([int? step]) async {
    final s = state;
    // "Stop at target" mode: never count past the target.
    if (settings.onTargetReached == 'stop' && s.count >= s.target) {
      return;
    }
    final add = (step ?? settings.stepSize).clamp(1, 1000);
    final oldCount = s.count;
    var newCount = (oldCount + add).clamp(0, maxCount);
    var delta = newCount - oldCount;
    final crossed = oldCount < s.target && newCount >= s.target;

    String? switchTo;
    if (crossed) {
      switch (settings.onTargetReached) {
        case 'stop':
          newCount = s.target;
          delta = newCount - oldCount;
          break;
        case 'newRound':
          s.rounds += 1;
          newCount = newCount - s.target;
          break;
        case 'nextDhikr':
          s.rounds += 1;
          newCount = 0;
          switchTo = _nextDhikrId();
          break;
      }
    }

    s.count = newCount;
    await _saveState(currentId);
    if (delta > 0) {
      await Storage.addToHistory(delta);
    }
    if (switchTo != null) {
      currentId = switchTo;
      await _saveCurrent();
    }

    if (crossed) {
      await Feedback.targetReached(settings);
    } else if (delta > 0) {
      final m = settings.milestoneEvery;
      if (m > 0 && (newCount ~/ m) > (oldCount ~/ m)) {
        await Feedback.milestone(settings);
      } else {
        await Feedback.tap(settings);
      }
    }

    await OverlayBridge.refreshOverlay();
    notifyListeners();
  }

  Future<void> decrement([int? step]) async {
    final s = state;
    final sub = (step ?? settings.stepSize).clamp(1, 1000);
    s.count = (s.count - sub).clamp(0, maxCount);
    await _saveState(currentId);
    await Feedback.tap(settings);
    await OverlayBridge.refreshOverlay();
    notifyListeners();
  }

  /// Sets the count to an exact typed number (no history entry: this is a
  /// correction, not counted taps).
  Future<void> setCount(int value) async {
    state.count = value.clamp(0, maxCount);
    await _saveState(currentId);
    await OverlayBridge.refreshOverlay();
    notifyListeners();
  }

  Future<void> resetCount() async {
    state.count = 0;
    await _saveState(currentId);
    await OverlayBridge.refreshOverlay();
    notifyListeners();
  }

  Future<void> setTarget(int target) async {
    state.target = target.clamp(1, maxCount);
    await _saveState(currentId);
    await OverlayBridge.refreshOverlay();
    notifyListeners();
  }

  String _nextDhikrId() {
    final idx = dhikrPresets.indexWhere((d) => d.id == currentId);
    return dhikrPresets[(idx + 1) % dhikrPresets.length].id;
  }

  Future<void> selectDhikr(String id) async {
    if (!dhikrPresets.any((d) => d.id == id)) return;
    currentId = id;
    await _saveCurrent();
    await OverlayBridge.refreshOverlay();
    notifyListeners();
  }

  // ---------------------------------------------------------------- settings

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await Storage.setJson(Storage.keySettings, next.toJson());
    await OverlayBridge.refreshOverlay();
    notifyListeners();
  }

  // ---------------------------------------------------------------- reminders

  Future<void> saveReminders(List<Reminder> next) async {
    reminders = next;
    await Storage.setJsonList(
      Storage.keyReminders,
      next.map((r) => r.toJson()).toList(),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------- overlay

  Future<void> refreshOverlayRunning() async {
    overlayRunning = await OverlayBridge.isOverlayRunning();
    notifyListeners();
  }

  // ---------------------------------------------------------------- backup

  /// Serializes everything for export.
  String exportJson() {
    final dhikrs = <String, dynamic>{};
    for (final d in dhikrPresets) {
      dhikrs[d.id] = states[d.id]?.toJson();
    }
    return jsonEncode({
      'app': 'zikr_tasbeeh',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'currentDhikr': currentId,
      'dhikrs': dhikrs,
      'settings': settings.toJson(),
      'reminders': reminders.map((r) => r.toJson()).toList(),
      'history': Storage.getJson(Storage.keyHistory) ?? {},
      'allTime': Storage.allTimeTotal(),
      'lastCountDate': Storage.getString(Storage.keyLastCountDate),
    });
  }

  /// Restores from an exported backup. Returns false when invalid.
  Future<bool> importJson(String raw) async {
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['app'] != 'zikr_tasbeeh') {
        return false;
      }
      final dhikrs = data['dhikrs'];
      if (dhikrs is Map<String, dynamic>) {
        for (final d in dhikrPresets) {
          final v = dhikrs[d.id];
          if (v is Map<String, dynamic>) {
            await Storage.setJson(
              Storage.dhikrKey(d.id),
              DhikrState.fromJson(v).toJson(),
            );
          }
        }
      }
      final s = data['settings'];
      if (s is Map<String, dynamic>) {
        await Storage.setJson(Storage.keySettings, s);
      }
      final rems = data['reminders'];
      if (rems is List) {
        await Storage.setJsonList(Storage.keyReminders, rems);
      }
      final history = data['history'];
      if (history is Map<String, dynamic>) {
        await Storage.setJson(Storage.keyHistory, history);
      }
      final allTime = data['allTime'];
      if (allTime is num) {
        await Storage.setInt(Storage.keyAllTime, allTime.toInt());
      }
      final lcd = data['lastCountDate'];
      if (lcd is String) {
        await Storage.setString(Storage.keyLastCountDate, lcd);
      }
      final cur = data['currentDhikr'];
      if (cur is String) {
        await Storage.setString(Storage.keyCurrentDhikr, cur);
      }
      await _loadAll();
      await OverlayBridge.refreshOverlay();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
