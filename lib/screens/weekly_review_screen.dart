// ════════════════════════════════════════════════════
// screens/weekly_review_screen.dart — Weekly Review
//
// Показывается автоматически в воскресенье при первом
// открытии приложения (проверяется в home_screen).
// Показывает итоги недели: лучшие/худшие дни, средние
// по метрикам, инсайт-фраза, streak.
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../constants/colors.dart';

class WeeklyReviewScreen extends StatelessWidget {
  final Map<String, Map<String, int>> weekRatings; // ключ = 'YYYY-MM-DD'
  final int streak;
  final int daysFilledThisWeek;
  final String userName;

  const WeeklyReviewScreen({
    super.key,
    required this.weekRatings,
    required this.streak,
    required this.daysFilledThisWeek,
    this.userName = '',
  });

  static const _metrics = ['energy', 'productivity', 'mood', 'food', 'sleep'];
  static const _labels  = ['Энергия', 'Продуктивность', 'Настроение', 'Еда', 'Сон'];
  static const _emojis  = ['⚡', '🎯', '🧠', '🍎', '💤'];

  // Средние за неделю по каждой метрике
  Map<String, double> _weeklyAverages() {
    final result = <String, double>{};
    for (int i = 0; i < _metrics.length; i++) {
      final vals = weekRatings.values
          .map((r) => r[_metrics[i]])
          .whereType<int>()
          .toList();
      result[_metrics[i]] = vals.isEmpty
          ? 0
          : vals.reduce((a, b) => a + b) / vals.length;
    }
    return result;
  }

  // Лучший и худший день по сумме всех метрик
  (String?, String?) _bestWorstDay() {
    if (weekRatings.isEmpty) return (null, null);
    String? bestKey;
    String? worstKey;
    double bestSum  = -1;
    double worstSum = double.infinity;

    for (final e in weekRatings.entries) {
      final sum = e.value.values.fold<int>(0, (a, b) => a + b).toDouble();
      if (sum > bestSum)  { bestSum  = sum;  bestKey  = e.key; }
      if (sum < worstSum) { worstSum = sum;  worstKey = e.key; }
    }
    return (bestKey, worstKey);
  }

  // Лучшая метрика недели
  String? _bestMetric(Map<String, double> avgs) {
    if (avgs.isEmpty) return null;
    String? best;
    double bestVal = 0;
    for (final e in avgs.entries) {
      if (e.value > bestVal) { bestVal = e.value; best = e.key; }
    }
    return best;
  }

  // Метрика которую стоит улучшить
  String? _weakestMetric(Map<String, double> avgs) {
    if (avgs.isEmpty) return null;
    String? worst;
    double worstVal = 11;
    for (final e in avgs.entries) {
      if (e.value > 0 && e.value < worstVal) { worstVal = e.value; worst = e.key; }
    }
    return worst;
  }

  String _formatDate(String key) {
    final dt = DateTime.parse(key);
    const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return '${days[dt.weekday - 1]}, ${dt.day}';
  }

  Color _metricColor(String key) {
    final i = _metrics.indexOf(key);
    return AppColors.metricColors[i < 0 ? 0 : i];
  }

  String _metricLabel(String key) {
    final i = _metrics.indexOf(key);
    return i < 0 ? key : _labels[i];
  }

  String _metricEmoji(String key) {
    final i = _metrics.indexOf(key);
    return i < 0 ? '📊' : _emojis[i];
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent    = AppSettings.of(context).accent;
    final avgs      = _weeklyAverages();
    final (bestDay, worstDay) = _bestWorstDay();
    final bestM   = _bestMetric(avgs);
    final weakM   = _weakestMetric(avgs);
    final name    = userName.trim();
    final hasData = weekRatings.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Заголовок ──────────────────────────────────────
              Row(children: [
                Text('📋', style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? 'Итоги недели, $name' : 'Итоги недели',
                        style: TextStyle(fontSize: 22,
                            fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        '$daysFilledThisWeek из 7 дней заполнено',
                        style: TextStyle(fontSize: 13,
                            color: textColor.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Стрик-бейдж ───────────────────────────────────
              if (streak > 0) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Text('🔥', style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$streak ${_dayWord(streak)} подряд',
                          style: TextStyle(fontSize: 20,
                              fontWeight: FontWeight.w900, color: accent)),
                      Text('Продолжай — ты строишь привычку',
                          style: TextStyle(fontSize: 12,
                              color: textColor.withValues(alpha: 0.5))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              if (!hasData) ...[
                // Пустое состояние
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    const Text('📭', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    Text('На этой неделе записей нет',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700, color: textColor)),
                    const SizedBox(height: 6),
                    Text('Начни сегодня — через неделю здесь будет твоя история',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13,
                            color: textColor.withValues(alpha: 0.45))),
                  ]),
                ),
              ] else ...[

                // ── Средние по метрикам ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Средние за неделю',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor.withValues(alpha: 0.5))),
                      const SizedBox(height: 12),
                      ...List.generate(_metrics.length, (i) {
                        final avg   = avgs[_metrics[i]] ?? 0;
                        final color = AppColors.metricColors[i];
                        if (avg == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(children: [
                            Text(_emojis[i],
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_labels[i],
                                style: TextStyle(fontSize: 14,
                                    color: textColor))),
                            // Мини прогресс-бар
                            SizedBox(
                              width: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: avg / 10,
                                  minHeight: 6,
                                  backgroundColor:
                                      color.withValues(alpha: 0.12),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(color),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 28,
                              child: Text(avg.toStringAsFixed(1),
                                  style: TextStyle(fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: color),
                                  textAlign: TextAlign.right),
                            ),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Лучший / худший день ─────────────────────────
                if (bestDay != null && weekRatings.length > 1)
                  Row(children: [
                    Expanded(child: _DayBadge(
                      label: 'Лучший день',
                      day: _formatDate(bestDay),
                      emoji: '🏆',
                      color: const Color(0xFF4CAF50),
                      textColor: textColor,
                    )),
                    const SizedBox(width: 10),
                    if (worstDay != null && worstDay != bestDay)
                      Expanded(child: _DayBadge(
                        label: 'Слабый день',
                        day: _formatDate(worstDay),
                        emoji: '📉',
                        color: const Color(0xFFFF7043),
                        textColor: textColor,
                      )),
                  ]),

                const SizedBox(height: 12),

                // ── Инсайт недели ────────────────────────────────
                if (bestM != null || weakM != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💡 Инсайт недели',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accent)),
                        const SizedBox(height: 8),
                        if (bestM != null)
                          Text(
                            '${_metricEmoji(bestM)} ${_metricLabel(bestM)} была твоей '
                            'сильной стороной этой недели (${avgs[bestM]!.toStringAsFixed(1)}/10).',
                            style: TextStyle(fontSize: 13,
                                color: textColor, height: 1.4),
                          ),
                        if (weakM != null && weakM != bestM) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${_metricEmoji(weakM)} ${_metricLabel(weakM)} — зона роста '
                            '(${avgs[weakM]!.toStringAsFixed(1)}/10). '
                            'Попробуй уделить ей больше внимания на следующей неделе.',
                            style: TextStyle(fontSize: 13,
                                color: textColor.withValues(alpha: 0.75),
                                height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],

              const SizedBox(height: 24),

              // ── Кнопка закрыть ───────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Закрыть',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayWord(int n) {
    if (n % 100 >= 11 && n % 100 <= 14) return 'дней';
    switch (n % 10) {
      case 1:  return 'день';
      case 2:
      case 3:
      case 4:  return 'дня';
      default: return 'дней';
    }
  }
}

class _DayBadge extends StatelessWidget {
  final String label, day, emoji;
  final Color color, textColor;
  const _DayBadge({
    required this.label,
    required this.day,
    required this.emoji,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11,
          color: textColor.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text(day, style: TextStyle(fontSize: 14,
            fontWeight: FontWeight.w800, color: color)),
      ]),
    ]),
  );
}
