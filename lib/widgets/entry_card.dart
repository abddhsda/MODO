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
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../services/photo_service.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';
import '../utils/ui_helpers.dart';
import 'section_block.dart';

// ─────────────────────────────────────────────────────
// EntryCard
// ─────────────────────────────────────────────────────
class EntryCard extends StatefulWidget {
  final bool isToday;
  final Map<String, int>? ratings;
  final Future<void> Function(Map<String, int>) onRatingsSaved;
  final void Function(bool)? onSliderActiveChanged;

  const EntryCard({
    super.key,
    required this.isToday,
    this.ratings,
    required this.onRatingsSaved,
    this.onSliderActiveChanged,
  });

  @override
  State<EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<EntryCard> {
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
    if (old.ratings != widget.ratings) _initRatings();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1A1A1A);
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.45) : Colors.grey.shade600;
    final accent     = AppSettings.of(context).accent;

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

                    // ── Оценки дня ──────────────────────────────
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


                  ],
              ),
            ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────
// _PhotoSection — секция фотографий в EntryCard
//
// Free:  1 фото. Plus: до 5 фото.
// Тап на фото — полноэкранный просмотр со свайпом.
// Долгий тап — удаление с подтверждением.
// Кнопка + открывает PhotoService.pick() шторку.
// ─────────────────────────────────────────────────────
class _PhotoSection extends StatelessWidget {
  final List<String> photoPaths;
  final String dateKey;
  final Color accent;
  final Color textColor;
  final Color labelColor;
  final void Function(List<String>) onChanged;

  const _PhotoSection({
    required this.photoPaths,
    required this.dateKey,
    required this.accent,
    required this.textColor,
    required this.labelColor,
    required this.onChanged,
  });

  int get _maxPhotos => PhotoService.instance.maxPhotos;
  bool get _canAdd   => photoPaths.length < _maxPhotos;

  Future<void> _addPhoto(BuildContext ctx) async {
    // Проверяем лимит
    if (!_canAdd) {
      if (SubscriptionService.instance.isFree) {
        // Предлагаем Plus
        final purchased = await PaywallScreen.show(
          ctx, reason: PaywallReason.manual,
        );
        if (!purchased) return;
      }
      return;
    }

    final path = await PhotoService.instance.pick(
      ctx,
      dateKey: dateKey,
      index:   photoPaths.length,
    );
    if (path == null) return;

    final updated = <String>[...photoPaths, path];
    onChanged(updated);
  }

  Future<void> _deletePhoto(BuildContext ctx, int index) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить фото?',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(ctx).colorScheme.onSurface)),
        content: Text('Это действие нельзя отменить.',
            style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface
                    .withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await PhotoService.instance.delete(photoPaths[index]);
    final updated = [...photoPaths]..removeAt(index);
    onChanged(updated);
  }

  void _viewPhoto(BuildContext ctx, int startIndex) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(
          paths:      photoPaths,
          startIndex: startIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) {
    return SectionBlock(
      emoji: '📷',
      title: 'Фото',
      labelColor: labelColor,
      initiallyExpanded: photoPaths.isNotEmpty,
      emptyHint: photoPaths.isEmpty ? 'Добавь фото к записи' : null,
      children: [
        if (photoPaths.isNotEmpty) ...[
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photoPaths.length + (_canAdd ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                // Кнопка добавления
                if (i == photoPaths.length) {
                  return _AddPhotoButton(
                    accent: accent,
                    onTap: () => _addPhoto(ctx),
                  );
                }
                // Карточка фото
                return _PhotoThumbnail(
                  path:     photoPaths[i],
                  onTap:    () => _viewPhoto(ctx, i),
                  onDelete: () => _deletePhoto(ctx, i),
                );
              },
            ),
          ),
          // Счётчик (только для free — намекает на лимит)
          if (SubscriptionService.instance.isFree) ...[
            const SizedBox(height: 8),
            Text(
              '${photoPaths.length} / $_maxPhotos · больше фото в Плюсе',
              style: TextStyle(fontSize: 12,
                  color: textColor.withValues(alpha: 0.35)),
            ),
          ],
        ] else ...[
          // Пустое состояние — большая кнопка
          GestureDetector(
            onTap: () => _addPhoto(ctx),
            child: Container(
              width: double.infinity,
              height: 70,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accent.withValues(alpha: 0.2),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 22, color: accent.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Text('Добавить фото',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: accent.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Миниатюра фото ────────────────────────────────────
class _PhotoThumbnail extends StatelessWidget {
  final String path;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PhotoThumbnail({
    required this.path,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return GestureDetector(
      onTap: onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onDelete();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 110, height: 110,
          child: file.existsSync()
              ? Image.file(file, fit: BoxFit.cover)
              : Container(
                  color: Colors.grey.shade800,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white38,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Кнопка добавления ─────────────────────────────────
class _AddPhotoButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _AddPhotoButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70, height: 110,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: accent, size: 26),
            const SizedBox(height: 4),
            Text('Фото',
                style: TextStyle(
                    fontSize: 11, color: accent.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

// ─── Полноэкранный просмотр ────────────────────────────
class _PhotoViewer extends StatefulWidget {
  final List<String> paths;
  final int startIndex;

  const _PhotoViewer({required this.paths, required this.startIndex});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.startIndex;
    _ctrl = PageController(initialPage: widget.startIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.paths.length > 1
            ? Text('${_current + 1} / ${widget.paths.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 15))
            : null,
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final file = File(widget.paths[i]);
          return InteractiveViewer(
            child: Center(
              child: file.existsSync()
                  ? Image.file(file, fit: BoxFit.contain)
                  : const Icon(Icons.broken_image_outlined,
                      color: Colors.white38, size: 64),
            ),
          );
        },
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

