// ════════════════════════════════════════════════════
// screens/stats_screen.dart — экран статистики
// Без стрелки назад — навигация через bottom nav
//
// ПРАВКА 2:
//   • Мотивирующий empty state вместо «Нет данных»
//   • Показывает прогресс-бар «X из 7 дней этой недели»
//     и счётчик дней до «оживления» графика
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../utils/ui_helpers.dart';
import '../utils/date_labels.dart';
import '../widgets/chart_painter.dart';

class StatsScreen extends StatefulWidget {
  final Map<String, Map<String, int>> allRatings;
  const StatsScreen({super.key, required this.allRatings});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear  = DateTime.now().year;
  String? _highlightedMetric;
  final Set<String> _hiddenMetrics = {};
  int? _tooltipDay;

  static const _metrics = ['energy', 'productivity', 'mood', 'food', 'sleep'];
  static const _labels  = ['Энергия', 'Продуктивность', 'Настроение', 'Еда', 'Сон'];
  static const _emojis  = ['😴', '🎯', '🧠', '🍎', '💤'];

  List<String> get _visibleMetrics =>
      _metrics.where((m) => !_hiddenMetrics.contains(m)).toList();

  // null = нет данных за месяц, 0.0 = данные есть, среднее = 0
  Map<String, double?> _getMonthAverages() {
    final result = <String, double?>{};
    for (final metric in _metrics) {
      final values = <int>[];
      widget.allRatings.forEach((dateKey, ratings) {
        final parts = dateKey.split('-');
        if (parts.length == 3) {
          final year  = int.tryParse(parts[0]) ?? 0;
          final month = int.tryParse(parts[1]) ?? 0;
          if (year == _selectedYear && month == _selectedMonth &&
              ratings.containsKey(metric)) {
            values.add(ratings[metric]!);
          }
        }
      });
      result[metric] = values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;
    }
    return result;
  }

  Map<String, int>? _getDayRatings(int day) {
    final key =
        '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    return widget.allRatings[key];
  }


  void _onChartTap(TapDownDetails details, double chartWidth, int daysInMonth) {
    final x   = details.localPosition.dx;
    final day = ((x / chartWidth) * daysInMonth).floor() + 1;
    final clampedDay = day.clamp(1, daysInMonth);
    final dayData = _getDayRatings(clampedDay);
    if (dayData == null || dayData.isEmpty) {
      setState(() { _tooltipDay = null; });
      return;
    }
    hapticLight();
    setState(() {
      if (_tooltipDay == clampedDay) {
        _tooltipDay = null;
      } else {
        _tooltipDay = clampedDay;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final averages  = _getMonthAverages();
    final hasData   = averages.values.any((v) => v != null);
    final textColor = Theme.of(context).colorScheme.onSurface;
    final accent    = AppSettings.of(context).accent;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Заголовок (без стрелки назад) ─────────────────
              Text('📊 Статистика',
                  style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w900, color: textColor)),

              const SizedBox(height: 24),

              // ── Переключатель месяца ──────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      hapticLight();
                      setState(() {
                        _tooltipDay = null;
                        if (_selectedMonth == 1) { _selectedMonth = 12; _selectedYear--; }
                        else _selectedMonth--;
                      });
                    },
                    icon: Icon(Icons.chevron_left, color: accent),
                  ),
                  Text('${monthShortCap[_selectedMonth - 1]} $_selectedYear',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w700, color: textColor)),
                  IconButton(
                    onPressed: () {
                      hapticLight();
                      setState(() {
                        _tooltipDay = null;
                        if (_selectedMonth == 12) { _selectedMonth = 1; _selectedYear++; }
                        else _selectedMonth++;
                      });
                    },
                    icon: Icon(Icons.chevron_right, color: accent),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Expanded(
                child: !hasData
                    ? _buildEmptyState(textColor, accent)
                    : _visibleMetrics.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Все метрики скрыты',
                                    style: TextStyle(
                                        color: textColor.withValues(alpha: 0.4),
                                        fontSize: 15)),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => setState(() => _hiddenMetrics.clear()),
                                  child: const Text('Показать все'),
                                ),
                              ],
                            ),
                          )
                    : SingleChildScrollView(
                        child: Column(children: [
                          // ── Средние значения ───────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(children: [
                              ...List.generate(_metrics.length, (i) {
                                final avg   = averages[_metrics[i]]; // null = нет данных
                                final color = AppColors.metricColors[i];
                                final isHidden = _hiddenMetrics.contains(_metrics[i]);
                                final isLast = i == _metrics.length - 1;
                                return GestureDetector(
                                  onTap: () {
                                    hapticLight();
                                    setState(() {
                                      if (isHidden) {
                                        _hiddenMetrics.remove(_metrics[i]);
                                      } else if (_highlightedMetric == _metrics[i]) {
                                        _highlightedMetric = null;
                                      } else {
                                        _highlightedMetric = _metrics[i];
                                      }
                                    });
                                  },
                                  child: Padding(
                                    // Последний элемент без bottom padding
                                    padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
                                    child: Opacity(
                                      opacity: isHidden ? 0.35 : 1.0,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Text(_emojis[i],
                                                style: const TextStyle(fontSize: 18)),
                                            const SizedBox(width: 10),
                                            Expanded(child: Text(_labels[i],
                                                style: TextStyle(fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: textColor))),
                                            Text(avg == null ? '—' : avg.toStringAsFixed(1),
                                                style: TextStyle(fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    color: avg == null
                                                        ? textColor.withValues(alpha: 0.3)
                                                        : color)),
                                          ]),
                                          if (avg != null) ...[
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: (avg ?? 0) / 10,
                                                backgroundColor:
                                                    textColor.withValues(alpha: 0.08),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                    _highlightedMetric == _metrics[i]
                                                        ? color
                                                        : color.withValues(alpha: 0.6)),
                                                minHeight: 4,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ]),
                          ),

                          const SizedBox(height: 16),

                          // ── График ─────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(children: [
                              Wrap(
                                spacing: 8, runSpacing: 8,
                                children: List.generate(_metrics.length, (i) {
                                  final isHidden     = _hiddenMetrics.contains(_metrics[i]);
                                  final isHighlighted = _highlightedMetric == _metrics[i];
                                  final color = isHidden
                                      ? Colors.grey.shade600
                                      : AppColors.metricColors[i];
                                  return GestureDetector(
                                    onTap: () {
                                      hapticLight();
                                      setState(() {
                                        _tooltipDay = null;
                                        if (isHidden) {
                                          _hiddenMetrics.remove(_metrics[i]);
                                        } else {
                                          _highlightedMetric =
                                              _highlightedMetric == _metrics[i]
                                                  ? null : _metrics[i];
                                        }
                                      });
                                    },
                                    onLongPress: () {
                                      hapticMedium();
                                      setState(() {
                                        _tooltipDay = null;
                                        if (isHidden) {
                                          _hiddenMetrics.remove(_metrics[i]);
                                        } else {
                                          _hiddenMetrics.add(_metrics[i]);
                                          if (_highlightedMetric == _metrics[i]) {
                                            _highlightedMetric = null;
                                          }
                                        }
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isHighlighted
                                            ? AppColors.metricColors[i].withValues(alpha: 0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: color.withValues(alpha:
                                              isHidden ? 0.3 : (isHighlighted ? 1.0 : 0.5)),
                                          width: isHighlighted ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        Container(width: 8, height: 8,
                                            decoration: BoxDecoration(
                                                color: color, shape: BoxShape.circle)),
                                        const SizedBox(width: 5),
                                        Text(_labels[i], style: TextStyle(
                                            fontSize: 11, color: color,
                                            fontWeight: isHighlighted
                                                ? FontWeight.w700 : FontWeight.w500,
                                            decoration: isHidden
                                                ? TextDecoration.lineThrough : null)),
                                      ]),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),



                              const SizedBox(height: 12),
                              SizedBox(
                                height: 160,
                                child: _buildChart(textColor),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 56), // отступ под навбар
                        ]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(Color textColor) {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final isDark      = Theme.of(context).brightness == Brightness.dark;

    // SCREEN FIX 2: LayoutBuilder даёт реальную ширину контейнера.
    // Точка на графике — минимум 20px, но если 20*days < availableWidth,
    // растягиваем чтобы график занимал всю ширину без скролла на wide-экранах.
    // На узких (320px) сохраняем скролл при 20px/day.
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final minChartWidth  = daysInMonth * 20.0;
        final chartWidth     = minChartWidth < availableWidth
            ? availableWidth   // шире минимума — растягиваем
            : minChartWidth;   // уже — скролл

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: chartWidth,
            child: Column(children: [
              Expanded(
                child: Stack(children: [
                  GestureDetector(
                    onTapDown: (d) => _onChartTap(d, chartWidth, daysInMonth),
                    // FIX: ClipRect убран — он обрезал точки у краёв.
                    // CustomPaint получает явный size с конечной высотой (160px).
                    // Раньше передавали double.infinity → NaN в paint() → пустой граф.
                    child: CustomPaint(
                      painter: ChartPainter(
                        allRatings: widget.allRatings,
                        year: _selectedYear,
                        month: _selectedMonth,
                        daysInMonth: daysInMonth,
                        metrics: _visibleMetrics,
                        colors: _visibleMetrics
                            .map((m) => AppColors.metricColors[_metrics.indexOf(m)])
                            .toList(),
                        selectedMetric: _highlightedMetric,
                        isDark: isDark,
                      ),
                      size: Size(chartWidth, 160),
                    ),
                  ),
                  if (_tooltipDay != null)
                    _buildTooltip(daysInMonth, chartWidth, isDark, textColor),
                ]),
              ),
              // Ось X рисуется внутри ChartPainter
            ]),
          ),
        );
      },
    );
  }

  // ПРАВКА 2: подсчёт заполненных дней в текущем месяце
  int _countFilledDays() {
    return widget.allRatings.keys.where((key) {
      final parts = key.split('-');
      if (parts.length != 3) return false;
      final y = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return y == _selectedYear && m == _selectedMonth;
    }).length;
  }

  // ПРАВКА 2: мотивирующий empty state вместо просто «Нет данных»
  Widget _buildEmptyState(Color textColor, Color accent) {
    final filledDays = _countFilledDays();
    final target     = 7;
    final remaining  = (target - filledDays).clamp(0, target);
    final progress   = (filledDays / target).clamp(0.0, 1.0);
    final isCurrentMonth = _selectedMonth == DateTime.now().month &&
                           _selectedYear  == DateTime.now().year;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📊', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              isCurrentMonth
                  ? 'График оживёт через $remaining ${_dayWord(remaining)}'
                  : 'Нет данных за этот месяц',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor),
              textAlign: TextAlign.center,
            ),
            if (isCurrentMonth) ...[
              const SizedBox(height: 8),
              Text(
                'Заполни ещё $remaining ${_dayWord(remaining)} — и увидишь свои тренды',
                style: TextStyle(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.5),
                    height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Прогресс-бар
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: textColor.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$filledDays из $target дней',
                      style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.4))),
                  Text('${(progress * 100).round()}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // «день / дня / дней»
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

  Widget _buildTooltip(
      int daysInMonth, double chartWidth, bool isDark, Color textColor) {
    final dayData = _getDayRatings(_tooltipDay!);
    if (dayData == null) return const SizedBox();
    final x    = (_tooltipDay! - 1) / daysInMonth * chartWidth;
    final left = (x - 70).clamp(0.0, chartWidth - 140);

    return Positioned(
      left: left, top: 0,
      child: GestureDetector(
        onTap: () => setState(() { _tooltipDay = null; }),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8, offset: const Offset(0, 2))],
            border: Border.all(color: textColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_tooltipDay} ${monthShortCap[_selectedMonth - 1]}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: textColor.withValues(alpha: 0.6))),
              const SizedBox(height: 6),
              ..._visibleMetrics.map((m) {
                final i     = _metrics.indexOf(m);
                final value = dayData[m];
                if (value == null) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: AppColors.metricColors[i],
                            shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(_labels[i], style: TextStyle(fontSize: 10,
                        color: textColor.withValues(alpha: 0.7))),
                    const Spacer(),
                    Text('$value', style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.metricColors[i])),
                  ]),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

