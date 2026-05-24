// ════════════════════════════════════════════════════
// services/streak_freeze.dart — Streak Freeze механика
//
// Логика:
//   • Пользователь получает 1 freeze каждые 7 дней стрика.
//   • Максимум 2 freeze в запасе (не копится больше).
//   • При пропуске дня freeze тратится автоматически
//     (проверяется при старте приложения).
//   • Freeze не тратится если пользователь заполнил день.
// ════════════════════════════════════════════════════

import 'package:shared_preferences/shared_preferences.dart';

class StreakFreeze {
  static const _keyCount     = 'freeze_count';
  static const _keyLastEarned = 'freeze_last_earned_streak'; // streak при котором выдали

  static const int maxFreezes = 2;

  /// Текущее количество freeze
  static Future<int> getCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCount) ?? 0;
  }

  /// Начислить freeze если заработан (вызывается после каждого сохранения)
  /// Логика: каждые 7 дней стрика — +1 freeze (не более maxFreezes)
  static Future<void> maybeEarn(int currentStreak) async {
    if (currentStreak <= 0) return;
    final prefs     = await SharedPreferences.getInstance();
    final count     = prefs.getInt(_keyCount) ?? 0;
    final lastEarned = prefs.getInt(_keyLastEarned) ?? 0;

    // Новый рубеж кратный 7 которого ещё не было
    final earned = (currentStreak ~/ 7) * 7;
    if (earned > lastEarned && count < maxFreezes) {
      await prefs.setInt(_keyCount, count + 1);
      await prefs.setInt(_keyLastEarned, earned);
    }
  }

  /// Проверить и применить freeze при пропуске дня.
  /// Возвращает true если freeze был использован (стрик сохранён).
  /// Вызывается из _calcStreak при обнаружении разрыва в 1 день.
  static Future<bool> tryApply() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyCount) ?? 0;
    if (count <= 0) return false;
    await prefs.setInt(_keyCount, count - 1);
    return true;
  }

  /// Сброс при потере стрика (разрыв > 1 дня, freeze не хватило)
  static Future<void> resetOnStreakLost() async {
    final prefs = await SharedPreferences.getInstance();
    // Сбрасываем lastEarned чтобы новый стрик мог начать зарабатывать freeze
    await prefs.setInt(_keyLastEarned, 0);
    // Freeze не сбрасываем — пользователь сохраняет их для следующего стрика
  }
}
