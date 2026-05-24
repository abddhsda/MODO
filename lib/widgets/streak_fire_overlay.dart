// ════════════════════════════════════════════════════
// widgets/streak_fire_overlay.dart
// ════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _milestones = {
  5:    'Пять дней подряд!\nПривычка формируется 🔥',
  10:   'Десять дней!\nТы серьёзно настроен 💪',
  30:   'Месяц без остановки.\nЭто уже характер 🏆',
  60:   'Два месяца.\nModo стал частью твоей жизни ⚡',
  100:  'СТО ДНЕЙ.\nЛегенда. 💯',
  200:  'Двести дней.\nТы пример для подражания 🌟',
  300:  'Триста дней.\nПочти год. Невероятно 🎯',
  365:  'ЦЕЛЫЙ ГОД.\nТы сделал это 🎉',
  500:  'Пятьсот дней.\nЭто образ жизни 🔮',
  1000: 'ТЫСЯЧА ДНЕЙ.\nТы — легенда Modo 👑',
};

class StreakFireOverlay {
  static void show(BuildContext context, int streak) {
    if (!context.mounted) return;
    final isMilestone = _milestones.containsKey(streak);
    HapticFeedback.heavyImpact();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => isMilestone
          ? _MilestoneOverlay(
              streak: streak,
              text:   _milestones[streak]!,
              onDone: () { try { entry.remove(); } catch (_) {} },
            )
          : _FireOverlay(
              streak: streak,
              onDone: () { try { entry.remove(); } catch (_) {} },
            ),
    );
    overlay.insert(entry);
  }
}

// ─────────────────────────────────────────────────────
// Обычный день
// ─────────────────────────────────────────────────────
class _FireOverlay extends StatefulWidget {
  final int streak;
  final VoidCallback onDone;
  const _FireOverlay({required this.streak, required this.onDone});
  @override State<_FireOverlay> createState() => _FireOverlayState();
}

class _FireOverlayState extends State<_FireOverlay>
    with TickerProviderStateMixin {

  late final AnimationController _fireCtrl;
  late final AnimationController _numCtrl;
  late final AnimationController _exitCtrl;
  late final Animation<double> _numScale;
  late final Animation<double> _numFade;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _fireCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2400))
      ..forward();

    _numCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 450));
    _numScale = CurvedAnimation(parent: _numCtrl, curve: Curves.easeOutBack);
    _numFade  = CurvedAnimation(parent: _numCtrl, curve: Curves.easeOut);

    _exitCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700));
    _exitFade = Tween(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));

    Future.delayed(const Duration(milliseconds: 500),
        () { if (mounted) _numCtrl.forward(); });
    Future.delayed(const Duration(milliseconds: 2000),
        () { if (mounted) _exitCtrl.forward().then((_) => widget.onDone()); });
  }

  @override
  void dispose() {
    _fireCtrl.dispose();
    _numCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _exitFade,
          child: Stack(children: [

            // Мягкий огонь
            AnimatedBuilder(
              animation: _fireCtrl,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _SoftFirePainter(
                    progress: _fireCtrl.value, seed: widget.streak),
              ),
            ),

            // Бейдж со стриком — по центру чуть выше середины
            Positioned(
              left: 0, right: 0,
              top: size.height * 0.35,
              child: Center(
                child: ScaleTransition(
                  scale: _numScale,
                  child: FadeTransition(
                    opacity: _numFade,
                    child: _StreakBadge(streak: widget.streak),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// Бейдж — чистый дизайн без подчёркиваний
class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        // Тёмный матовый фон с лёгким золотым свечением
        color: const Color(0xFF1A1208),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: const Color(0xFFFFB020).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: DefaultTextStyle(
        // Сбрасываем decoration — убираем подчёркивания
        style: const TextStyle(decoration: TextDecoration.none),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 36, height: 1)),
            const SizedBox(width: 12),
            Text(
              '$streak',
              style: const TextStyle(
                color: Color(0xFFFFD060),
                fontSize: 52,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -1,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'дн.',
                style: TextStyle(
                  color: Color(0xFFFFB020),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Мягкий огонь — широкие плавные языки с glow
class _SoftFirePainter extends CustomPainter {
  final double progress;
  final int    seed;
  _SoftFirePainter({required this.progress, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng   = math.Random(seed * 7919);
    final count = 10;
    final cx    = size.width / 2;

    for (int i = 0; i < count; i++) {
      // Распределяем языки вдоль основания экрана
      final spread  = size.width * 0.9;
      final baseX   = cx + (i / (count - 1) - 0.5) * spread;
      final delay   = rng.nextDouble() * 0.3;
      final t       = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final easedT  = Curves.easeOutQuart.transform(t);

      // Высота — центральные языки выше
      final centerBias = 1.0 - (baseX - cx).abs() / (size.width * 0.5);
      final maxH    = size.height * (0.35 + centerBias * 0.35 + rng.nextDouble() * 0.15);
      final height  = maxH * easedT;

      // Ширина — широкие у основания
      final w       = size.width * (0.10 + rng.nextDouble() * 0.08);

      // Покачивание
      final sway    = math.sin(progress * math.pi * 2.5 + i * 1.3)
                      * w * 0.3;

      final tipY  = size.height - height;
      final baseY = size.height + 10.0;

      // Плавная форма через 2 контрольные точки
      final path = Path();
      path.moveTo(baseX - w / 2, baseY);
      path.cubicTo(
        baseX - w * 0.4 + sway * 0.5, (baseY * 2 + tipY) / 3,
        baseX + sway - w * 0.15,       (baseY + tipY * 2) / 3,
        baseX + sway, tipY,
      );
      path.cubicTo(
        baseX + sway + w * 0.15,       (baseY + tipY * 2) / 3,
        baseX + w * 0.4 + sway * 0.5, (baseY * 2 + tipY) / 3,
        baseX + w / 2, baseY,
      );
      path.close();

      // Opacity языка — fade в конце анимации
      final opacityMod = t < 0.7 ? 1.0 : (1.0 - t) / 0.3;

      final rect = Rect.fromLTWH(baseX - w, tipY, w * 2, baseY - tipY);
      final grad = LinearGradient(
        begin: Alignment.bottomCenter,
        end:   Alignment.topCenter,
        colors: [
          const Color(0xFFFF4400).withValues(alpha: 0.9 * opacityMod),
          const Color(0xFFFF8C00).withValues(alpha: 0.75 * opacityMod),
          const Color(0xFFFFD000).withValues(alpha: 0.4 * opacityMod),
          const Color(0xFFFFFF80).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      );

      // Основной язык
      canvas.drawPath(
        path,
        Paint()
          ..shader = grad.createShader(rect)
          ..style  = PaintingStyle.fill,
      );

      // Мягкое свечение (размытый повторный слой)
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end:   Alignment.topCenter,
            colors: [
              const Color(0xFFFF6600).withValues(alpha: 0.3 * opacityMod),
              Colors.transparent,
            ],
          ).createShader(rect)
          ..style      = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
  }

  @override
  bool shouldRepaint(_SoftFirePainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────
// Milestone
// ─────────────────────────────────────────────────────
class _MilestoneOverlay extends StatefulWidget {
  final int streak;
  final String text;
  final VoidCallback onDone;
  const _MilestoneOverlay(
      {required this.streak, required this.text, required this.onDone});
  @override State<_MilestoneOverlay> createState() => _MilestoneOverlayState();
}

class _MilestoneOverlayState extends State<_MilestoneOverlay>
    with TickerProviderStateMixin {

  late final AnimationController _fireCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _contentCtrl;
  late final AnimationController _exitCtrl;
  late final Animation<double> _ringArc;
  late final Animation<double> _contentScale;
  late final Animation<double> _contentFade;
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    _fireCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 2500))
      ..repeat();

    _ringCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 800));
    _ringArc  = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

    _contentCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 450));
    _contentScale = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutBack);
    _contentFade  = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);

    _exitCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _exitFade = Tween(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _ringCtrl.forward().then((_) {
      if (mounted) {
        HapticFeedback.mediumImpact();
        _contentCtrl.forward();
      }
    });
    Future.delayed(const Duration(seconds: 4), _close);
  }

  void _close() {
    if (!mounted) return;
    _exitCtrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _fireCtrl.dispose();
    _ringCtrl.dispose();
    _contentCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned.fill(
      child: GestureDetector(
        onTap: _close,
        child: FadeTransition(
          opacity: _exitFade,
          child: Material(
            color: Colors.black.withValues(alpha: 0.88),
            child: Stack(children: [

              // Фоновый огонь
              AnimatedBuilder(
                animation: _fireCtrl,
                builder: (_, __) => CustomPaint(
                  size: size,
                  painter: _SoftFirePainter(
                      progress: _fireCtrl.value, seed: widget.streak),
                ),
              ),

              // Затемнение нижней части чтобы контент читался
              Positioned(
                left: 0, right: 0, top: 0, bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end:   Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // Контент
              Center(
                child: DefaultTextStyle(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // Золотое кольцо
                      AnimatedBuilder(
                        animation: _ringArc,
                        builder: (_, __) => SizedBox(
                          width: 200, height: 200,
                          child: CustomPaint(
                            painter: _RingPainter(progress: _ringArc.value),
                            child: Center(
                              child: ScaleTransition(
                                scale: _contentScale,
                                child: FadeTransition(
                                  opacity: _contentFade,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🔥',
                                          style: TextStyle(
                                              fontSize: 40,
                                              decoration: TextDecoration.none)),
                                      Text(
                                        '${widget.streak}',
                                        style: const TextStyle(
                                          color:      Color(0xFFFFD060),
                                          fontSize:   58,
                                          fontWeight: FontWeight.w900,
                                          height:     1,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      ScaleTransition(
                        scale: _contentScale,
                        child: FadeTransition(
                          opacity: _contentFade,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Text(
                              widget.text,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   22,
                                fontWeight: FontWeight.w800,
                                height:     1.35,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      FadeTransition(
                        opacity: _contentFade,
                        child: Text(
                          'Нажми чтобы продолжить',
                          style: TextStyle(
                            color:      Colors.white.withValues(alpha: 0.3),
                            fontSize:   13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// Золотое кольцо
class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 12;

    // Фоновый трек
    canvas.drawCircle(Offset(cx, cy), r,
        Paint()
          ..color       = Colors.white.withValues(alpha: 0.07)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 5);

    // Glow под дугой
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color       = const Color(0xFFFFB020).withValues(alpha: 0.25)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap   = StrokeCap.round
        ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Основная дуга
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle:    3 * math.pi / 2,
          colors: const [
            Color(0xFFFFD700),
            Color(0xFFFF8C00),
            Color(0xFFFFD700),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: r))
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap   = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
