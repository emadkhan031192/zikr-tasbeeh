import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/counter.dart';
import '../services/storage.dart';
import '../theme.dart';

/// History: today's total, all-time total, daily-goal progress and a simple
/// bar chart of the last 30 days.
class HistoryScreen extends StatelessWidget {
  final CounterService counter;

  const HistoryScreen({super.key, required this.counter});

  List<(DateTime, int)> _last30() {
    final history = Storage.getJson(Storage.keyHistory) ?? {};
    final now = DateTime.now();
    return List.generate(30, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 29 - i));
      final key = Storage.todayKey(day);
      final v = (history[key] as num?)?.toInt() ?? 0;
      return (day, v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: counter,
      builder: (context, _) {
        final s = S(counter.settings.language);
        final accent = AccentTheme.of(counter.settings.theme);
        final data = _last30();
        final today = counter.todayTotal;
        final allTime = counter.allTimeTotal;
        final goal = counter.settings.dailyGoal;
        final goalFrac =
            goal <= 0 ? 0.0 : (today / goal).clamp(0.0, 1.0);

        return Scaffold(
          appBar: AppBar(title: Text(s.t('navHistory'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      s.t('todayLabel'),
                      '$today',
                      accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      s.t('allTime'),
                      '$allTime',
                      accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
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
                          child: Text(
                            s.t('dailyGoal'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: ZikrColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '$today / $goal',
                          style: const TextStyle(
                            color: ZikrColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: goalFrac,
                        minHeight: 8,
                        backgroundColor: ZikrColors.cardBorder,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          goalFrac >= 1
                              ? ZikrColors.success
                              : accent.top,
                        ),
                      ),
                    ),
                    if (goalFrac >= 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          s.t('goalReached'),
                          style: const TextStyle(
                            color: ZikrColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ZikrColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ZikrColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('last30'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ZikrColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: CustomPaint(
                        painter: _BarChartPainter(
                          data: data,
                          barColor: accent.top,
                          todayColor: ZikrColors.success,
                          labelColor: ZikrColors.textMuted,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, AccentTheme accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZikrColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ZikrColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ZikrColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: 30,
              color: accent.top,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<(DateTime, int)> data;
  final Color barColor;
  final Color todayColor;
  final Color labelColor;

  _BarChartPainter({
    required this.data,
    required this.barColor,
    required this.todayColor,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxV =
        data.map((e) => e.$2).fold<int>(1, (a, b) => a > b ? a : b);
    const padBottom = 18.0;
    const padTop = 8.0;
    final chartH = size.height - padBottom - padTop;
    final n = data.length;
    final slot = size.width / n;
    final barW = (slot * 0.62).clamp(2.0, 14.0);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var i = 0; i < n; i++) {
      final v = data[i].$2;
      final h = chartH * (v / maxV);
      final x = i * slot + (slot - barW) / 2;
      final y = padTop + chartH - h;
      final isToday = i == n - 1;
      final paint = Paint()
        ..color = (isToday ? todayColor : barColor)
            .withValues(alpha: v == 0 ? 0.25 : 0.9);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barW, h < 2 ? 2 : h),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
      if (i % 5 == 0 || isToday) {
        textPainter.text = TextSpan(
          text: '${data[i].$1.day}',
          style: TextStyle(color: labelColor, fontSize: 9),
        );
        textPainter.layout(maxWidth: slot);
        textPainter.paint(
          canvas,
          Offset(i * slot + (slot - textPainter.width) / 2,
              size.height - padBottom + 4),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.data != data ||
      old.barColor != barColor ||
      old.todayColor != todayColor;
}
