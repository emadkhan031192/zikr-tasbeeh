import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/counter.dart';
import '../services/system_bridge.dart';
import '../theme.dart';

/// About: version and the privacy note.
class AboutScreen extends StatefulWidget {
  final CounterService counter;

  const AboutScreen({super.key, required this.counter});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    SystemBridge.getAppVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S(widget.counter.settings.language);
    final accent = AccentTheme.of(widget.counter.settings.theme);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('navAbout'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent.top, accent.bottom],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.glow.withValues(alpha: 0.4),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(
                Icons.fingerprint,
                size: 48,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.t('appName'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: ZikrColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${s.t('versionLabel')} $_version',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZikrColors.textMuted),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
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
                    const Icon(
                      Icons.lock_outline,
                      color: ZikrColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.t('privacyTitle'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: ZikrColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.t('privacyBody'),
                  style: const TextStyle(
                    color: ZikrColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.t('madeWith'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ZikrColors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
