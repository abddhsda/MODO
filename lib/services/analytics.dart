// ════════════════════════════════════════════════════
// services/analytics.dart — обёртка над Firebase Analytics
//
// Все ивенты приложения в одном месте.
// Если Firebase не инициализирован — молча игнорируем.
// ════════════════════════════════════════════════════

import 'package:firebase_analytics/firebase_analytics.dart';

class Analytics {
  static final _fa = FirebaseAnalytics.instance;

  // ── Онбординг ─────────────────────────────────────────────────
  /// Пользователь завершил онбординг — ввёл имя и цель
  static Future<void> onboardingComplete({
    required String category,
  }) => _safe(() => _fa.logEvent(
        name: 'onboarding_complete',
        parameters: {'goal_category': category},
      ));

  // ── Основное действие ─────────────────────────────────────────
  /// День сохранён (вопросы + оценки)
  static Future<void> daySaved({
    required int streak,
    required bool isToday,
    required bool hasRatings,
  }) => _safe(() => _fa.logEvent(
        name: 'day_saved',
        parameters: {
          'streak':      streak,
          'is_today':    isToday ? 1 : 0,
          'has_ratings': hasRatings ? 1 : 0,
        },
      ));

  // ── Статистика ────────────────────────────────────────────────
  /// Пользователь открыл экран статистики
  static Future<void> statsOpened() => _safe(() => _fa.logEvent(
        name: 'stats_opened',
      ));

  /// Пользователь выбрал метрику на графике
  static Future<void> metricFocused({required String metric}) =>
      _safe(() => _fa.logEvent(
            name: 'metric_focused',
            parameters: {'metric': metric},
          ));

  // ── Стрик ────────────────────────────────────────────────────
  /// Достигнут milestone стрика
  static Future<void> streakMilestone({required int days}) =>
      _safe(() => _fa.logEvent(
            name: 'streak_milestone',
            parameters: {'days': days},
          ));

  /// Активирован freeze стрика
  static Future<void> streakFreezeUsed({required int streak}) =>
      _safe(() => _fa.logEvent(
            name: 'streak_freeze_used',
            parameters: {'streak_at_use': streak},
          ));

  // ── Вспомогательное ──────────────────────────────────────────
  static Future<void> _safe(Future<void> Function() fn) async {
    try { await fn(); } catch (_) { /* не роняем приложение */ }
  }
}
