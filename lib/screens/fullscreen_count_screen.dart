import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../services/counter.dart';
import '../theme.dart';
import '../widgets/neon_digits.dart';

/// In-app fullscreen counting: black screen, huge digits, tap anywhere to
/// count, a small × to exit. (The on-screen overlay's fullscreen mode is the
/// native equivalent that works above other apps.)
class FullscreenCountScreen extends StatefulWidget {
  final CounterService counter;

  const FullscreenCountScreen({super.key, required this.counter});

  @override
  State<FullscreenCountScreen> createState() =>
      _FullscreenCountScreenState();
}

class _FullscreenCountScreenState extends State<FullscreenCountScreen> {
  CounterService get c => widget.counter;

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
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = S(c.settings.language);
        final accent = AccentTheme.of(c.settings.theme);
        final preset = c.current;
        return Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: () => c.increment(),
            behavior: HitTestBehavior.opaque,
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.settings.showArabic)
                          Text(
                            preset.arabic,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 26,
                              color: ZikrColors.textPrimary,
                            ),
                          ),
                        const SizedBox(height: 12),
                        NeonDigits(
                          value: c.state.count,
                          accent: accent,
                          sizeSetting: 'large',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.t('tapToCount'),
                          style: const TextStyle(
                            color: ZikrColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: IconButton(
                      tooltip: s.t('exitLabel'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: ZikrColors.textMuted,
                        size: 28,
                      ),
                    ),
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
