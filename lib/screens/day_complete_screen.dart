// ════════════════════════════════════════════════════
// screens/day_complete_screen.dart — экран "День записан"
//
// ВОЛНА 3:
//   • Milestone экраны: 7 / 30 / 100 дней — особое
//     оформление с конфетти-эмодзи и особым текстом
//   • Insight карточка: умный факт на основе оценок
//     дня (показывает что было лучше/хуже обычного)
//   • Таймер 7с, свайп вниз — без изменений
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../logic/daily_logic.dart';

class DayCompleteScreen extends StatefulWidget {
  final DateTime date;
  final String userName;
  final int streak;
  // Оценки текущего дня для Insight карточки
  final Map<String, int>? ratings;
  // Средние оценки за последние 7 дней для сравнения
  final Map<String, double>? recentAverages;
  // Если true — milestone показывается независимо от точного значения streak.
  // Устанавливается из home_screen когда порог достигнут впервые.
  final bool isMilestoneReached;

  const DayCompleteScreen({
    super.key,
    required this.date,
    this.userName = '',
    this.streak = 0,
    this.ratings,
    this.recentAverages,
    this.isMilestoneReached = false,
  });

  @override
  State<DayCompleteScreen> createState() => _DayCompleteScreenState();
}

class _DayCompleteScreenState extends State<DayCompleteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim  = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    Future.delayed(const Duration(seconds: 7), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
      Navigator.pop(context);
    }
  }

  // ─── Milestone данные ─────────────────────────────────────────
  // isMilestoneReached устанавливается из home_screen при первом достижении порога.
  // Не зависит от точного значения streak — защищает от пропуска при заполнении
  // задним числом (например: стрик стал 8 минуя 7).
  bool get _isMilestone => widget.isMilestoneReached;

  // Определяем какой именно milestone отображать по текущему streak
  int get _milestoneThreshold {
    if (widget.streak >= 100) return 100;
    if (widget.streak >= 30)  return 30;
    return 7;
  }

  String get _milestoneEmoji {
    if (_milestoneThreshold >= 100) return '💎';
    if (_milestoneThreshold >= 30)  return '🏆';
    return '⭐';
  }

  String get _milestoneTitle {
    if (_milestoneThreshold >= 100) return '100 дней. Легенда.';
    if (_milestoneThreshold >= 30)  return '30 дней подряд!';
    return 'Неделя без пропусков!';
  }

  String get _milestoneSubtitle {
    if (_milestoneThreshold >= 100) return 'Ты входишь в 1% людей которые реально меняются.';
    if (_milestoneThreshold >= 30)  return 'Месяц привычки. Теперь это часть тебя.';
    return 'Первая неделя — самая важная. Ты справился.';
  }

  // ─── Insight: что было лучше/хуже среднего ───────────────────
  String? _buildInsight() {
    final r = widget.ratings;
    final avg = widget.recentAverages;
    if (r == null || r.isEmpty || avg == null || avg.isEmpty) return null;

    const labels = {
      'energy':       'Энергия',
      'productivity': 'Продуктивность',
      'mood':         'Настроение',
      'food':         'Еда',
      'sleep':        'Сон',
    };
    const emojis = {
      'energy': '⚡', 'productivity': '🎯',
      'mood': '🧠', 'food': '🍎', 'sleep': '💤',
    };

    String? bestKey;
    double  bestDelta = 0.5; // минимальный порог чтобы было интересно
    String? worstKey;
    double  worstDelta = -0.5;

    for (final key in r.keys) {
      final val  = r[key]!.toDouble();
      final mean = avg[key] ?? 5.0;
      final delta = val - mean;
      if (delta > bestDelta)  { bestDelta = delta;  bestKey = key; }
      if (delta < worstDelta) { worstDelta = delta; worstKey = key; }
    }

    if (bestKey != null && worstKey != null) {
      return '${emojis[bestKey]} ${labels[bestKey]} лучше обычного, '
             '${emojis[worstKey]} ${labels[worstKey]} — чуть хуже.';
    }
    if (bestKey != null) {
      return '${emojis[bestKey]} ${labels[bestKey]} сегодня выше твоего среднего — хороший день!';
    }
    if (worstKey != null) {
      return '${emojis[worstKey]} ${labels[worstKey]} ниже обычного. Завтра лучше.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent    = AppSettings.of(context).accent;
    final quote     = getDailyQuote(widget.date);
    final name      = widget.userName.trim();
    final isMile    = _isMilestone;
    final insight   = _buildInsight();

    return GestureDetector(
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // ── Главный значок ──────────────────────────────
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Text(
                      isMile ? _milestoneEmoji : '🔥',
                      style: TextStyle(fontSize: isMile ? 96 : 80),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Заголовок ───────────────────────────────────
                  Text(
                    isMile
                        ? _milestoneTitle
                        : name.isNotEmpty
                            ? 'Отличная работа, $name!'
                            : 'День записан',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: isMile ? 30 : 28,
                        fontWeight: FontWeight.w900,
                        color: isMile ? accent : textColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isMile ? _milestoneSubtitle : 'Ты на пути.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        color: textColor.withValues(alpha: 0.55),
                        height: 1.4),
                  ),

                  // ── Стрик-бейдж ─────────────────────────────────
                  if (widget.streak > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: accent.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '🔥 ${widget.streak} ${_dayWord(widget.streak)} подряд',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: accent),
                      ),
                    ),
                  ],

                  // Подсказка свайпа
                  const SizedBox(height: 8),
                  Text('↓ свайп чтобы закрыть',
                      style: TextStyle(fontSize: 12,
                          color: textColor.withValues(alpha: 0.2))),

                  const Spacer(),

                  // ── Insight карточка ────────────────────────────
                  if (insight != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: textColor.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('💡', style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(insight,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: textColor.withValues(alpha: 0.75),
                                    height: 1.45)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Цитата ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(children: [
                      Text(
                        '"${quote['text']}"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: textColor,
                            height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      if ((quote['author'] ?? '').isNotEmpty)
                        Text('— ${quote['author']}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accent)),
                    ]),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
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
