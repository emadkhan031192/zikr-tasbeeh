import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/dhikr.dart';
import '../services/counter.dart';
import '../services/overlay_bridge.dart';
import '../services/system_bridge.dart';
import '../theme.dart';
import '../widgets/neon_digits.dart';
import 'fullscreen_count_screen.dart';
import 'setup_screen.dart';

/// The control panel: dhikr chips, the huge tap zone, progress, step chips,
/// the − / +1 / reset row, and the on-screen counter switch.
class HomeScreen extends StatefulWidget {
  final CounterService counter;

  const HomeScreen({super.key, required this.counter});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  bool _resetArmed = false;
  Timer? _resetTimer;
  Map<String, bool>? _permStatus;

  CounterService get c => widget.counter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _loadPermStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _resetTimer?.cancel();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    if (!c.settings.volumeButtons) return false;
    if (e.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      c.increment();
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      c.decrement();
      return true;
    }
    return false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.syncCountsOnly();
      c.refreshOverlayRunning();
      _loadPermStatus();
    }
  }

  Future<void> _loadPermStatus() async {
    final st = await SystemBridge.getPermissionStatus();
    if (mounted) setState(() => _permStatus = st);
  }

  // ------------------------------------------------------------------ actions

  void _onResetTap() {
    final s = S(c.settings.language);
    if (c.settings.lockReset) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('resetLocked'))),
      );
      return;
    }
    if (!_resetArmed) {
      setState(() => _resetArmed = true);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _resetArmed = false);
      });
      return;
    }
    _resetTimer?.cancel();
    setState(() => _resetArmed = false);
    if (c.settings.resetConfirmation) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ZikrColors.card,
          title: Text(s.t('resetTitle')),
          content: Text(s.t('resetBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.t('cancel')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                c.resetCount();
              },
              child: Text(
                s.t('reset'),
                style: const TextStyle(color: ZikrColors.danger),
              ),
            ),
          ],
        ),
      );
    } else {
      c.resetCount();
    }
  }

  Future<void> _toggleOverlay() async {
    if (c.overlayRunning) {
      await OverlayBridge.stopOverlay();
    } else {
      if (!await OverlayBridge.hasOverlayPermission()) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SetupScreen(counter: c),
          ),
        );
        return;
      }
      final s = S(c.settings.language);
      final started = await OverlayBridge.startOverlay(
        mode: c.settings.overlayDefaultMode,
        s: s,
      );
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('permOverlayWhy'))),
        );
      }
    }
    await c.refreshOverlayRunning();
  }

  Future<void> _typeExactNumber() async {
    final s = S(c.settings.language);
    final ctl = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZikrColors.card,
        title: Text(s.t('typeNumberTitle')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: 28,
          ),
          decoration: InputDecoration(hintText: s.t('typeNumberHint')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctl.text.trim());
              if (v == null) {
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
      ),
    );
    if (value != null) {
      await c.setCount(value);
    }
  }

  Future<void> _editTarget() async {
    final s = S(c.settings.language);
    final ctl =
        TextEditingController(text: c.state.target.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZikrColors.card,
        title: Text(s.t('defaultTarget')),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w900,
            fontSize: 28,
          ),
          decoration: const InputDecoration(hintText: '33'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.t('cancel')),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctl.text.trim());
              if (v == null || v < 1) {
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
      ),
    );
    if (value != null) {
      await c.setTarget(value);
    }
  }

  // -------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = S(c.settings.language);
        final accent = AccentTheme.of(c.settings.theme);
        final st = c.state;
        final preset = c.current;
        final reached = st.count >= st.target && st.target > 0;
        final toGo = (st.target - st.count).clamp(0, CounterService.maxCount);

        return SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(s),
                const SizedBox(height: 12),
                _dhikrChips(s, accent),
                const SizedBox(height: 8),
                if (c.settings.showArabic)
                  Text(
                    preset.arabic,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 22,
                      color: ZikrColors.textPrimary,
                    ),
                  ),
                if (c.settings.showTransliteration)
                  Text(
                    preset.transliteration,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ZikrColors.textMuted,
                    ),
                  ),
                if (c.settings.showMeaning)
                  Text(
                    preset.meaningEn,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: ZikrColors.textMuted,
                    ),
                  ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => c.increment(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: NeonDigits(
                      value: st.count,
                      accent: accent,
                      sizeSetting: c.settings.digitSize,
                    ),
                  ),
                ),
                _progress(s, accent, st, reached, toGo),
                const SizedBox(height: 10),
                _stepChips(s, accent),
                const SizedBox(height: 14),
                _counterRow(s, accent),
                if (_resetArmed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      s.t('resetTapAgain'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ZikrColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _overlaySwitch(s, accent),
                const SizedBox(height: 8),
                _setupRow(s),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(S s) {
    return Row(
      children: [
        Text(
          s.dateLine(DateTime.now()),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: ZikrColors.textPrimary,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: s.t('typeExactNumber'),
          onPressed: _typeExactNumber,
          icon: const Icon(Icons.edit, color: ZikrColors.textMuted),
        ),
        IconButton(
          tooltip: s.t('fullscreen'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenCountScreen(counter: c),
            ),
          ),
          icon: const Icon(Icons.fullscreen, color: ZikrColors.textMuted),
        ),
      ],
    );
  }

  Widget _dhikrChips(S s, AccentTheme accent) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dhikrPresets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = dhikrPresets[i];
          final selected = d.id == c.currentId;
          final label =
              d.isCustom ? s.t('custom') : d.transliteration;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => c.selectDhikr(d.id),
            selectedColor: accent.bottom.withValues(alpha: 0.25),
            backgroundColor: ZikrColors.card,
            side: BorderSide(
              color: selected ? accent.top : ZikrColors.cardBorder,
            ),
            labelStyle: TextStyle(
              color:
                  selected ? ZikrColors.textPrimary : ZikrColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }

  Widget _progress(
    S s,
    AccentTheme accent,
    DhikrState st,
    bool reached,
    int toGo,
  ) {
    final frac = st.target <= 0 ? 0.0 : (st.count / st.target).clamp(0.0, 1.0);
    final barColor = reached ? ZikrColors.success : accent.top;
    final progressText =
        s.t('progressOf').replaceAll('{c}', '${st.count}').replaceAll(
              '{t}',
              '${st.target}',
            );
    return Column(
      children: [
        GestureDetector(
          onTap: _editTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                progressText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ZikrColors.textPrimary,
                ),
              ),
              if (st.rounds > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ZikrColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ZikrColors.cardBorder),
                    ),
                    child: Text(
                      '${s.t('roundLabel')} ${st.rounds + 1}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: ZikrColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 8,
            backgroundColor: ZikrColors.cardBorder,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          reached
              ? s.t('targetReached')
              : s.t('toGoFmt').replaceAll('{n}', '$toGo'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: reached ? ZikrColors.success : ZikrColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _stepChips(S s, AccentTheme accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [1, 5, 10].map((step) {
        final selected = c.settings.stepSize == step;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ChoiceChip(
            label: Text('+$step'),
            selected: selected,
            onSelected: (_) async {
              final next = c.settings..stepSize = step;
              await c.updateSettings(next);
            },
            selectedColor: accent.bottom.withValues(alpha: 0.25),
            backgroundColor: ZikrColors.card,
            side: BorderSide(
              color: selected ? accent.top : ZikrColors.cardBorder,
            ),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
    );
  }

  Widget _counterRow(S s, AccentTheme accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundButton(
          icon: Icons.remove,
          onTap: () => c.decrement(),
          accent: accent,
          size: 56,
        ),
        const SizedBox(width: 24),
        _roundButton(
          icon: Icons.add,
          onTap: () => c.increment(),
          accent: accent,
          size: 88,
          primary: true,
        ),
        const SizedBox(width: 24),
        Column(
          children: [
            _roundButton(
              icon: Icons.refresh,
              onTap: _onResetTap,
              accent: accent,
              size: 56,
              danger: _resetArmed,
            ),
          ],
        ),
      ],
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    required AccentTheme accent,
    required double size,
    bool primary = false,
    bool danger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: primary
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent.top, accent.bottom],
                  )
                : null,
            color: primary ? null : ZikrColors.card,
            border: Border.all(
              color: danger
                  ? ZikrColors.danger
                  : (primary ? Colors.transparent : ZikrColors.cardBorder),
              width: 1.5,
            ),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: accent.glow.withValues(alpha: 0.35),
                      blurRadius: 22,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: primary
                ? Colors.black
                : (danger ? ZikrColors.danger : ZikrColors.textPrimary),
            size: size * 0.42,
          ),
        ),
      ),
    );
  }

  Widget _overlaySwitch(S s, AccentTheme accent) {
    final running = c.overlayRunning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: running ? accent.top : ZikrColors.cardBorder,
        ),
      ),
      child: Row(
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
            ),
            child: const Icon(
              Icons.picture_in_picture_alt,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              running ? s.t('stop') : s.t('startOnScreen'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ZikrColors.textPrimary,
              ),
            ),
          ),
          Switch(
            value: running,
            onChanged: (_) => _toggleOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _setupRow(S s) {
    final st = _permStatus;
    String label;
    IconData icon;
    Color color;
    if (st == null) {
      label = s.t('setupRow');
      icon = Icons.settings;
      color = ZikrColors.textMuted;
    } else {
      final missing = [
        st['overlay'],
        st['notifications'],
        st['exactAlarm'],
      ].where((v) => v != true).length;
      if (missing == 0) {
        label = s.t('setupComplete');
        icon = Icons.check_circle;
        color = ZikrColors.success;
      } else {
        label = '$missing ${s.t('setupNeeded')}';
        icon = Icons.warning_amber_rounded;
        color = ZikrColors.danger;
      }
    }
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SetupScreen(counter: c)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              '${s.t('setupRow')}: $label',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: ZikrColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
