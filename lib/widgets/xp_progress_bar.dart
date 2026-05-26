// ════════════════════════════════════════════════════
// widgets/xp_progress_bar.dart
//
// Полоска XP + уровень — вставляется в HomeTab
// прямо под приветствием.
//
// Использование:
//   XPProgressBar()  // сам слушает GamificationService.notifier
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../services/gamification_service.dart';
import '../app.dart';

class XPProgressBar extends StatelessWidget {
  const XPProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GamificationState>(
      valueListenable: GamificationService.instance.notifier,
      builder: (context, state, _) {
        final accent    = AppSettings.of(context).accent;
        final isDark    = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              // Уровень
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${state.level}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: accent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Прогресс-бар
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Уровень ${state.level}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textColor.withValues(alpha: 0.5))),
                        Text('${state.xpInLevel} / ${state.xpForNextLevel} XP',
                            style: TextStyle(
                                fontSize: 11,
                                color: textColor.withValues(alpha: 0.4))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: state.levelProgress.clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: textColor.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Суммарный XP
              Text(
                '${state.totalXP} XP',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent.withValues(alpha: 0.8)),
              ),
            ],
          ),
        );
      },
    );
  }
}
