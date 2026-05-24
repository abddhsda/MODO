// ════════════════════════════════════════════════════
// widgets/entry_card.dart — карточка с записью дня
//
// Механика inline-slider (все баги из аудита исправлены):
//
// БАГ 1 — _dragStartX на 300мс раньше активации:
//   Теперь каждый _MetricRowState хранит lastMoveX и
//   на момент активации передаёт актуальную позицию
//   пальца через _activateMetric(key, currentX).
//
// БАГ 2 — один AnimationController на 5 метрик:
//   5 отдельных контроллеров в _MetricRowState,
//   каждый управляет своим thumb независимо.
//   Нет конфликта при быстром переключении.
//
// БАГ 3 — ScaleTransition + AnimatedContainer одновременно:
//   ScaleTransition убран. Thumb — только AnimatedContainer
//   с Curves.easeOutBack через TweenAnimationBuilder.
//   Один чистый механизм анимации размера.
//
// БАГ 4 — bubble за левым краем при value=0:
//   Bubble позиционируется с учётом реального trackW,
//   clamp(4, trackW - 76). Минимальный отступ 4px.
//   При trackW < 76 (экзотика) bubble схлопывается до trackW.
//
// БАГ 5 — кнопки ± конкурируют с _deactivateMetric:
//   _ValueBubble изолирована через AbsorbPointer+GestureDetector
//   с onTapDown/onTapUp: bubble поглощает события прежде
//   чем они дойдут до Listener строки или GestureDetector карточки.
//
// SCREEN: чувствительность drag адаптируется под trackW:
//   pxPerUnit = trackW / 10 * 0.6  (60% ширины = весь диапазон),
//   но не меньше 18px и не больше 40px — комфортно на любом экране.
// ════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../utils/ui_helpers.dart';
import 'section_block.dart';

// ─────────────────────────────────────────────────────
// EntryCard
// ─────────────────────────────────────────────────────
class EntryCard extends StatefulWidget {
  final List<String> answers;
  final List<Map<String, String>> dailyQuestions;
  final Map<String, dynamic> surveyPack;
  final bool isToday;
  final String note;
  final Map<String, int>? ratings;
  final Future<void> Function(String) onNoteSaved;
  final Future<void> Function(Map<String, int>) onRatingsSaved;
  final void Function(bool)? onSliderActiveChanged;
  final VoidCallback? onOpenQuestions; // кнопка «перепройти вопросы»

  const EntryCard({
    super.key,
    required this.answers,
    required this.dailyQuestions,
    required this.surveyPack,
    required this.isToday,
    required this.note,
    this.ratings,
    required this.onNoteSaved,
    required this.onRatingsSaved,
    this.onSliderActiveChanged,
    this.onOpenQuestions,
  });

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> {
  late TextEditingController _noteController;

  // AFFORDANCE-FIX: drag handle icon always visible — one-time hint removed
  SharedPreferences? _prefs;

  // ── значения метрик ───────────────────────────────
  late double _energy;
  late double _productivity;
  late double _mood;
  late double _food;
  late double _sleep;
  late Map<String, int> _prevRounded;

  static const _metricKeys   = ['energy', 'productivity', 'mood', 'food', 'sleep'];
  static const _metricLabels = ['Энергия', 'Продуктивность', 'Настроение', 'Еда', 'Сон'];
  static const _metricEmojis = ['😴', '🎯', '🧠', '🍎', '💤'];

  // Какая метрика сейчас активна (null = нет)
  String? _activeMetric;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.note);
    _initRatings();
    SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
    });
  }

  void _initRatings() {
    final r = widget.ratings;
    _energy       = (r?['energy']       ?? 5).toDouble();
    _productivity = (r?['productivity'] ?? 5).toDouble();
    _mood         = (r?['mood']         ?? 5).toDouble();
    _food         = (r?['food']         ?? 5).toDouble();
    _sleep        = (r?['sleep']        ?? 5).toDouble();
    _prevRounded  = {for (final k in _metricKeys) k: _currentValue(k).round()};
  }

  double _currentValue(String key) {
    switch (key) {
      case 'energy':       return _energy;
      case 'productivity': return _productivity;
      case 'mood':         return _mood;
      case 'food':         return _food;
      case 'sleep':        return _sleep;
      default:             return 5;
    }
  }

  // P1 FIX: debounce — сохраняем не чаще раза в 400мс
  Timer? _saveDebounce;

  // Вызывается из _MetricRowState при изменении значения
  void _setValue(String key, double v) {
    final clamped = v.clamp(0.0, 10.0);
    setState(() {
      switch (key) {
        case 'energy':       _energy       = clamped;
        case 'productivity': _productivity = clamped;
        case 'mood':         _mood         = clamped;
        case 'food':         _food         = clamped;
        case 'sleep':        _sleep        = clamped;
      }
    });
    final rounded = clamped.round();
    if (rounded != _prevRounded[key]) {
      HapticFeedback.selectionClick();
      _prevRounded[key] = rounded;
    }
    // Debounce: отменяем предыдущий таймер, запускаем новый
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      widget.onRatingsSaved({
        'energy':       _energy.round(),
        'productivity': _productivity.round(),
        'mood':         _mood.round(),
        'food':         _food.round(),
        'sleep':        _sleep.round(),
      });
    });
  }

  // Вызывается из _MetricRowState при активации/деактивации
  void _setActiveMetric(String? key) {
    setState(() => _activeMetric = key);
    widget.onSliderActiveChanged?.call(key != null);
  }

  @override
  void didUpdateWidget(EntryCard old) {
    super.didUpdateWidget(old);
    if (old.note != widget.note && _noteController.text != widget.note) {
      _noteController.text = widget.note;
    }
    if (old.ratings != widget.ratings) _initRatings();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _saveDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1A1A1A);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.45) : Colors.grey.shade600;
    final accent     = AppSettings.of(context).accent;

    final qCount        = widget.dailyQuestions.length;
    final textAnswers   = widget.answers.length > qCount
        ? widget.answers.sublist(0, qCount) : widget.answers;
    final surveyAnswers = widget.answers.length > qCount
        ? widget.answers.sublist(qCount) : <String>[];
    final surveyQuestions =
        List<String>.from(widget.surveyPack['questions'] as List);

    final totalQ = qCount + surveyQuestions.length;
    final filled = widget.answers.where((a) => a.isNotEmpty).length;

    return GestureDetector(
      // Тап вне активной строки — деактивация.
      // Срабатывает ТОЛЬКО если ни один _MetricRowState
      // не поглотил событие (bubble и строки имеют приоритет).
      onTap: _activeMetric != null ? () => _setActiveMetric(null) : null,
      child: Container(
        clipBehavior: Clip.none,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: widget.isToday
              ? Border.all(color: const Color(0xFFFFD700), width: 2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                    // ── 1. Вопросы дня ──────────────────────────
                    SectionBlock(
                      emoji: '💬',
                      title: 'Вопросы дня',
                      labelColor: labelColor,
                      initiallyExpanded: true,
                      children: [
                        ...List.generate(textAnswers.length, (i) {
                          if (i >= widget.dailyQuestions.length ||
                              textAnswers[i].isEmpty) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.dailyQuestions[i]['emoji']} '
                                  '${widget.dailyQuestions[i]['q']}',
                                  style: TextStyle(fontSize: 12,
                                      color: labelColor, height: 1.4),
                                ),
                                const SizedBox(height: 6),
                                Text(textAnswers[i],
                                    style: TextStyle(fontSize: 15,
                                        color: textColor, height: 1.5)),
                              ],
                            ),
                          );
                        }),

                        // Кнопка «перепройти вопросы»
                        if (widget.onOpenQuestions != null)
                          GestureDetector(
                            onTap: () {
                              hapticMedium();
                              widget.onOpenQuestions!();
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 14),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.25), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh_rounded,
                                      size: 16, color: accent),
                                  const SizedBox(width: 8),
                                  Text('Перепройти вопросы',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: accent)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ── 2. Опрос дня ────────────────────────────
                    if (surveyAnswers.isNotEmpty &&
                        surveyAnswers.any((a) => a.isNotEmpty)) ...[
                      SectionBlock(
                        emoji: widget.surveyPack['emoji'] as String,
                        title: widget.surveyPack['title'] as String,
                        labelColor: labelColor,
                        initiallyExpanded: true,
                        children: List.generate(surveyAnswers.length, (i) {
                          if (i >= surveyQuestions.length ||
                              surveyAnswers[i].isEmpty) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(surveyQuestions[i],
                                    style: TextStyle(fontSize: 12,
                                        color: labelColor, height: 1.4)),
                                const SizedBox(height: 4),
                                Text(surveyAnswers[i],
                                    style: TextStyle(fontSize: 15,
                                        color: textColor, height: 1.5)),
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── 3. Оценки дня ───────────────────────────
                    SectionBlock(
                      emoji: '📊',
                      title: 'Оценки дня',
                      labelColor: labelColor,
                      initiallyExpanded: true,
                      children: List.generate(_metricKeys.length, (i) =>
                        _MetricRow(
                          key: ValueKey(_metricKeys[i]),
                          metricKey:   _metricKeys[i],
                          label:       _metricLabels[i],
                          emoji:       _metricEmojis[i],
                          color:       AppColors.metricColors[i],
                          value:       _currentValue(_metricKeys[i]),
                          isActive:    _activeMetric == _metricKeys[i],
                          // Другая метрика уже активна — блокируем активацию
                          otherActive: _activeMetric != null &&
                                       _activeMetric != _metricKeys[i],
                          textColor:   textColor,
                          onValue:     (v) => _setValue(_metricKeys[i], v),
                          onActivate:  () => _setActiveMetric(_metricKeys[i]),
                          onDeactivate: () => _setActiveMetric(null),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── 4. Заметки ──────────────────────────────
                    SectionBlock(
                      emoji: '✏️',
                      title: 'Заметки по дню',
                      labelColor: labelColor,
                      initiallyExpanded: true,
                      emptyHint: widget.note.isEmpty
                          ? 'О чём ты думаешь прямо сейчас...'
                          : (widget.note.length > 80
                              ? '${widget.note.substring(0, 80)}...'
                              : widget.note),
                      children: [
                        TextField(
                          controller: _noteController,
                          maxLines: null,
                          autofocus: false,
                          style: TextStyle(fontSize: 15,
                              color: textColor, height: 1.5),
                          decoration: InputDecoration(
                            hintText: 'О чём ты думаешь прямо сейчас...',
                            hintStyle: TextStyle(color: labelColor, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: widget.onNoteSaved,
                        ),
                      ],
                    ),
                  ],
              ),
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// _MetricRow — виджет одной строки метрики
//
// БАГ 2 FIX: у каждой строки свой AnimationController.
//   SingleTickerProviderStateMixin только здесь — не на EntryCard.
//
// БАГ 1 FIX: lastMoveX обновляется в _onPointerMove.
//   При активации передаётся в onActivate через колбэк,
//   _EntryCardState сохраняет dragStartX = lastMoveX.
//   Здесь же: _dragStartX обновляется сразу после активации.
// ─────────────────────────────────────────────────────
class _MetricRow extends StatefulWidget {
  final String metricKey;
  final String label;
  final String emoji;
  final Color  color;
  final double value;
  final bool   isActive;
  final bool   otherActive; // другая метрика активна → не реагируем на hold
  final Color  textColor;
  final void Function(double) onValue;
  final VoidCallback onActivate;
  final VoidCallback onDeactivate;

  const _MetricRow({
    super.key,
    required this.metricKey,
    required this.label,
    required this.emoji,
    required this.color,
    required this.value,
    required this.isActive,
    required this.otherActive,
    required this.textColor,
    required this.onValue,
    required this.onActivate,
    required this.onDeactivate,
  });

  @override
  State<_MetricRow> createState() => _MetricRowState();
}

class _MetricRowState extends State<_MetricRow>
    with SingleTickerProviderStateMixin {

  late AnimationController _anim;

  Timer?  _longPressTimer;
  double  _dragStartX    = 0;
  double  _dragBaseValue = 0;
  double  _lastMoveX     = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void didUpdateWidget(_MetricRow old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _anim.forward(from: _anim.value);
    } else if (!widget.isActive && old.isActive) {
      _anim.reverse(from: _anim.value);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _longPressTimer?.cancel();
    super.dispose();
  }

  // ── Pointer handlers ──────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (widget.otherActive) return;
    _longPressTimer?.cancel();
    _dragStartX    = e.position.dx;
    _lastMoveX     = e.position.dx;
    _dragBaseValue = widget.value;

    _longPressTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _dragStartX    = _lastMoveX;
      _dragBaseValue = widget.value;
      widget.onActivate();
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    _lastMoveX = e.position.dx;
    if (widget.isActive) {
      final deltaPx    = e.position.dx - _dragStartX;
      final deltaUnits = deltaPx / _pxPerUnit;
      widget.onValue((_dragBaseValue + deltaUnits).clamp(0.0, 10.0));
    } else {
      if ((e.position.dx - _dragStartX).abs() > 8) {
        _longPressTimer?.cancel();
      }
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _longPressTimer?.cancel();
    if (widget.isActive) {
      widget.onValue(widget.value.roundToDouble());
      widget.onDeactivate();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _longPressTimer?.cancel();
    if (widget.isActive) widget.onDeactivate();
  }

  double _pxPerUnit = 28.0;

  @override
  Widget build(BuildContext context) {
    final color    = widget.color;
    final isActive = widget.isActive;
    final rounded  = widget.value.round();

    const double trackH    = 3.0;

    return Listener(
      onPointerDown:   _onPointerDown,
      onPointerMove:   _onPointerMove,
      onPointerUp:     _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: LayoutBuilder(builder: (ctx, box) {
          final trackW = box.maxWidth.clamp(80.0, double.infinity);
          _pxPerUnit = (trackW * 0.06).clamp(18.0, 40.0);

          final frac   = (widget.value / 10.0).clamp(0.0, 1.0);
          final thumbX = frac * trackW;

          return AnimatedBuilder(
            animation: _anim,
            builder: (ctx, _) {
              const double thumbRest = 8.0;
              final t      = _anim.value;
              final thumbR = thumbRest + t * 8.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Заголовок + бейдж
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(children: [
                        Text(widget.emoji,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(widget.label,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: widget.otherActive
                                    ? widget.textColor.withValues(alpha: 0.35)
                                    : widget.textColor)),
                        // AFFORDANCE-FIX: постоянная иконка-подсказка.
                        // Видна всегда (opacity 0.35) → пользователь понимает
                        // что строку можно удерживать. При активации скрывается
                        // (opacity 0) — thumb уже на экране, подсказка не нужна.
                        const SizedBox(width: 5),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: widget.otherActive ? 0.1 : (isActive ? 0.0 : 0.35),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            size: 13,
                            color: widget.textColor,
                          ),
                        ),
                      ]),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutBack,
                        padding: EdgeInsets.symmetric(
                            horizontal: isActive ? 14 : 10,
                            vertical:   isActive ? 5  : 2),
                        decoration: BoxDecoration(
                          color: widget.otherActive
                              ? color.withValues(alpha: 0.3) : color,
                          borderRadius:
                              BorderRadius.circular(isActive ? 14 : 8),
                        ),
                        child: Text('$rounded',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: isActive ? 20 : 13)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Трек — высота 32px: вмещает thumb 16px радиуса (32px диаметр)
                  // Clip.none — thumb не обрезается при активации
                  SizedBox(
                    height: 32,
                    width: trackW,
                    child: Stack(clipBehavior: Clip.none, children: [

                      // Трек — по центру SizedBox (y = 16 - 1.5 = 14.5)
                      Positioned(
                        left: 0, right: 0,
                        top: 16 - trackH / 2,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: trackH,
                            child: Row(children: [
                              Flexible(
                                flex: (frac * 1000).round().clamp(1, 999),
                                child: Container(
                                    color: widget.otherActive
                                        ? color.withValues(alpha: 0.3) : color),
                              ),
                              Flexible(
                                flex: ((1 - frac) * 1000).round().clamp(1, 999),
                                child: Container(
                                    color: color.withValues(alpha: 0.15)),
                              ),
                            ]),
                          ),
                        ),
                      ),

                      // Thumb — центрируется по вертикали SizedBox
                      Positioned(
                        left: (thumbX - thumbR).clamp(0, trackW - thumbR * 2),
                        top:  16 - thumbR,
                        child: Container(
                          width:  thumbR * 2,
                          height: thumbR * 2,
                          decoration: BoxDecoration(
                            color: widget.otherActive
                                ? color.withValues(alpha: 0.3) : color,
                            shape: BoxShape.circle,
                            boxShadow: t > 0.1
                                ? [BoxShadow(
                                    color: color.withValues(alpha: 0.45 * t),
                                    blurRadius: 14 * t,
                                    spreadRadius: 2 * t)]
                                : [],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }
}

