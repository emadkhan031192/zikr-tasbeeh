import 'package:flutter/material.dart';

/// The neon look: pure black background, huge Nunito 900 digits with a
/// vertical gradient and a soft glow.
class ZikrColors {
  static const background = Color(0xFF04060C);
  static const card = Color(0xFF0B1220);
  static const cardBorder = Color(0xFF1B2740);
  static const textPrimary = Color(0xFFF2F6FF);
  static const textMuted = Color(0xFF8A94A8);
  static const success = Color(0xFF35E08A);
  static const danger = Color(0xFFFF5D5D);
}

/// One accent theme: gradient top/bottom colors plus the glow color.
class AccentTheme {
  final Color top;
  final Color bottom;
  final Color glow;

  const AccentTheme({
    required this.top,
    required this.bottom,
    required this.glow,
  });

  static AccentTheme of(String name) {
    switch (name) {
      case 'green':
        return const AccentTheme(
          top: Color(0xFF3DFF88),
          bottom: Color(0xFF00A651),
          glow: Color(0xFF3DFF88),
        );
      case 'orange':
        return const AccentTheme(
          top: Color(0xFFFFC53D),
          bottom: Color(0xFFFF6A00),
          glow: Color(0xFFFFB020),
        );
      case 'purple':
        return const AccentTheme(
          top: Color(0xFFD18BFF),
          bottom: Color(0xFF7A2BFF),
          glow: Color(0xFFB45CFF),
        );
      case 'cyan':
      default:
        return const AccentTheme(
          top: Color(0xFF22F5FF),
          bottom: Color(0xFF0A74FF),
          glow: Color(0xFF22F5FF),
        );
    }
  }
}

/// Base digit size by number of digits, per the design spec.
double digitBaseSize(int value) {
  final len = '$value'.length;
  if (len <= 2) return 200;
  if (len == 3) return 170;
  if (len == 4) return 128;
  if (len == 5) return 104;
  return 86;
}

/// User digit-size setting multiplier.
double digitScale(String setting) {
  switch (setting) {
    case 'small':
      return 0.78;
    case 'large':
      return 1.18;
    case 'normal':
    default:
      return 1.0;
  }
}

ThemeData buildTheme() {
  return ThemeData.dark(useMaterial3: true).copyWith(
    scaffoldBackgroundColor: ZikrColors.background,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF22F5FF),
      surface: ZikrColors.card,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ZikrColors.background,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: ZikrColors.background,
      selectedItemColor: Color(0xFF22F5FF),
      unselectedItemColor: ZikrColors.textMuted,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Color(0xFF22F5FF)
            : ZikrColors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Color(0xFF0A74FF).withValues(alpha: 0.5)
            : ZikrColors.cardBorder,
      ),
    ),
  );
}
