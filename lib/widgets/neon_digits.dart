import 'package:flutter/material.dart';

import '../theme.dart';

/// Huge bold rounded digits with a vertical gradient and a soft neon glow,
/// like a neon clock display.
class NeonDigits extends StatelessWidget {
  final int value;
  final AccentTheme accent;
  final String sizeSetting;
  final double? overrideSize;
  final double glowRadius;

  const NeonDigits({
    super.key,
    required this.value,
    required this.accent,
    this.sizeSetting = 'normal',
    this.overrideSize,
    this.glowRadius = 26,
  });

  @override
  Widget build(BuildContext context) {
    final text = '$value';
    final size =
        (overrideSize ?? digitBaseSize(value)) * digitScale(sizeSetting);
    final base = TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w900,
      fontSize: size,
      height: 1.0,
      letterSpacing: 2,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow layer: blurred copy in the accent color.
        Text(
          text,
          textAlign: TextAlign.center,
          style: base.copyWith(
            color: Colors.transparent,
            shadows: [
              Shadow(
                color: accent.glow.withValues(alpha: 0.55),
                blurRadius: glowRadius,
              ),
            ],
          ),
        ),
        // Gradient face.
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [accent.top, accent.bottom],
          ).createShader(
            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: base.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
