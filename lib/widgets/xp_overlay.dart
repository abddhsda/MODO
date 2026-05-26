// ════════════════════════════════════════════════════
// widgets/xp_overlay.dart
//
// Всплывающая анимация "+20 XP" и баннер достижения.
// Показывается поверх любого экрана через Overlay.
//
// Использование (из home_screen после сохранения дня):
//   XPOverlay.show(context, result: xpResult);
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../services/gamification_service.dart';
import '../app.dart';

class XPOverlay {
  // Показываем +XP и достижения последовательно
  static Future<void> show(
    BuildContext context, {
    required XPResult result,
  }) async {
    if (!result.hasAnything) return;

    // Сначала +XP флоатер
    if (result.xpGained > 0) {
      await _showXPFloat(context, result.xpGained, result.leveledUp, result.newLevel);
    }

    // Затем каждое достижение по очереди
    for (final ach in result.newAchievements) {
      if (context.mounted) {
        await _showAchievementBanner(context, ach);
      }
    }
  }

  // ── +XP всплывашка ────────────────────────────────────────
  static Future<void> _showXPFloat(
    BuildContext context, int xp, bool leveledUp, int newLevel) async {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _XPFloat(
        xp: xp,
        leveledUp: leveledUp,
        newLevel: newLevel,
        accent: AppSettings.of(context).accent,
        onDone: () {
          try { entry.remove(); } catch (_) {}
        },
      ),
    );

    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 1800));
  }

  // ── Баннер достижения ─────────────────────────────────────
  static Future<void> _showAchievementBanner(
    BuildContext context, Achievement ach) async {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _AchievementBanner(
        achievement: ach,
        accent: AppSettings.of(context).accent,
        onDone: () {
          try { entry.remove(); } catch (_) {}
        },
      ),
    );

    overlay.insert(entry);
    await Future.delayed(const Duration(milliseconds: 2800));
  }
}

// ─── Виджет +XP ───────────────────────────────────────────────
class _XPFloat extends StatefulWidget {
  final int xp;
  final bool leveledUp;
  final int newLevel;
  final Color accent;
  final VoidCallback onDone;

  const _XPFloat({
    required this.xp,
    required this.leveledUp,
    required this.newLevel,
    required this.accent,
    required this.onDone,
  });

  @override
  State<_XPFloat> createState() => _XPFloatState();
}

class _XPFloatState extends State<_XPFloat>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _fade = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 25),
    ]).animate(_ctrl);
    _slide = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 60),
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(0, -0.5))
          .chain(CurveTween(curve: Curves.easeIn)), weight: 25),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: widget.leveledUp
                  ? _LevelUpBadge(level: widget.newLevel, accent: widget.accent)
                  : _XPBadge(xp: widget.xp, accent: widget.accent),
            ),
          ),
        ),
      ),
    );
  }
}

class _XPBadge extends StatelessWidget {
  final int xp;
  final Color accent;
  const _XPBadge({required this.xp, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Text(
        '+$xp XP',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _LevelUpBadge extends StatelessWidget {
  final int level;
  final Color accent;
  const _LevelUpBadge({required this.level, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.5),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🚀', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            'Уровень $level!',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Виджет баннера достижения ────────────────────────────────
class _AchievementBanner extends StatefulWidget {
  final Achievement achievement;
  final Color accent;
  final VoidCallback onDone;

  const _AchievementBanner({
    required this.achievement,
    required this.accent,
    required this.onDone,
  });

  @override
  State<_AchievementBanner> createState() => _AchievementBannerState();
}

class _AchievementBannerState extends State<_AchievementBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _fade = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 20),
    ]).animate(_ctrl);
    _slide = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: const Offset(0, -1), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutBack)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(Offset.zero), weight: 70),
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(0, -1))
          .chain(CurveTween(curve: Curves.easeIn)), weight: 20),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final bg = isDark ? const Color(0xFF1E2A1E) : Colors.white;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: widget.accent.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(widget.achievement.emoji,
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Достижение разблокировано!',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: widget.accent,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(widget.achievement.title,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: textColor)),
                        Text(widget.achievement.description,
                            style: TextStyle(
                                fontSize: 12,
                                color: textColor.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+${widget.achievement.xpReward}',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: widget.accent)),
                      Text('XP', style: TextStyle(
                          fontSize: 11,
                          color: widget.accent.withValues(alpha: 0.7))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
