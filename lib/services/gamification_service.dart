// ════════════════════════════════════════════════════
// services/gamification_service.dart
//
// XP, уровни и достижения в стиле Duolingo.
//
// Как работает:
//   • Каждое действие даёт XP (запись, стрик, оценки).
//   • XP накапливаются → уровень растёт каждые 100 XP.
//   • Достижения — одноразовые награды за milestone.
//   • GamificationService.instance.addXP() — главный метод.
//   • Слушать изменения: notifier (ValueNotifier<GamificationState>).
//
// Вызовы из home_screen._goToQuestions() после сохранения:
//   await GamificationService.instance.onDaySaved(streak: _streak, hasRatings: true);
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── XP за действия ───────────────────────────────────────────
class XPReward {
  static const int daySaved      = 20;   // записал день
  static const int hasRatings    = 10;   // добавил оценки
  static const int streak7       = 50;   // 7 дней подряд
  static const int streak30      = 150;  // 30 дней подряд
  static const int streak100     = 500;  // 100 дней подряд
  static const int streakDaily   = 5;    // бонус за каждый день стрика
  static const int noteAdded     = 5;    // добавил заметку
}

// ─── Достижения ───────────────────────────────────────────────
class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final int xpReward;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.xpReward,
  });
}

const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_day',
    emoji: '🌱',
    title: 'Первый шаг',
    description: 'Записал первый день',
    xpReward: 30,
  ),
  Achievement(
    id: 'streak_3',
    emoji: '🔥',
    title: 'Три дня подряд',
    description: '3 дня без пропуска',
    xpReward: 40,
  ),
  Achievement(
    id: 'streak_7',
    emoji: '⭐',
    title: 'Неделя',
    description: '7 дней подряд',
    xpReward: 50,
  ),
  Achievement(
    id: 'streak_30',
    emoji: '🏆',
    title: 'Месяц',
    description: '30 дней подряд',
    xpReward: 150,
  ),
  Achievement(
    id: 'streak_100',
    emoji: '💎',
    title: 'Легенда',
    description: '100 дней подряд',
    xpReward: 500,
  ),
  Achievement(
    id: 'level_5',
    emoji: '🚀',
    title: 'Уровень 5',
    description: 'Достиг 5 уровня',
    xpReward: 60,
  ),
  Achievement(
    id: 'level_10',
    emoji: '🌟',
    title: 'Уровень 10',
    description: 'Достиг 10 уровня',
    xpReward: 100,
  ),
  Achievement(
    id: 'ratings_master',
    emoji: '📊',
    title: 'Аналитик',
    description: 'Добавил оценки 10 раз',
    xpReward: 50,
  ),
  Achievement(
    id: 'days_10',
    emoji: '📅',
    title: '10 записей',
    description: 'Записал 10 дней всего',
    xpReward: 40,
  ),
  Achievement(
    id: 'days_50',
    emoji: '📖',
    title: '50 записей',
    description: 'Записал 50 дней всего',
    xpReward: 100,
  ),
];

// ─── Состояние ────────────────────────────────────────────────
class GamificationState {
  final int totalXP;
  final int level;
  final int xpInLevel;       // XP внутри текущего уровня
  final int xpForNextLevel;  // сколько нужно для следующего
  final List<String> unlockedIds; // ID разблокированных достижений

  const GamificationState({
    required this.totalXP,
    required this.level,
    required this.xpInLevel,
    required this.xpForNextLevel,
    required this.unlockedIds,
  });

  double get levelProgress => xpInLevel / xpForNextLevel;

  bool isUnlocked(String id) => unlockedIds.contains(id);

  GamificationState copyWith({
    int? totalXP,
    int? level,
    int? xpInLevel,
    int? xpForNextLevel,
    List<String>? unlockedIds,
  }) => GamificationState(
    totalXP: totalXP ?? this.totalXP,
    level: level ?? this.level,
    xpInLevel: xpInLevel ?? this.xpInLevel,
    xpForNextLevel: xpForNextLevel ?? this.xpForNextLevel,
    unlockedIds: unlockedIds ?? this.unlockedIds,
  );
}

// ─── Результат добавления XP (для UI) ────────────────────────
class XPResult {
  final int xpGained;
  final bool leveledUp;
  final int newLevel;
  final List<Achievement> newAchievements;

  const XPResult({
    required this.xpGained,
    required this.leveledUp,
    required this.newLevel,
    this.newAchievements = const [],
  });

  bool get hasAnything => xpGained > 0 || leveledUp || newAchievements.isNotEmpty;
}

// ─── Сервис ───────────────────────────────────────────────────
class GamificationService {
  GamificationService._();
  static final GamificationService instance = GamificationService._();

  static const _keyXP           = 'xp_total';
  static const _keyUnlocked     = 'xp_achievements';
  static const _keyRatingsCount = 'xp_ratings_count';
  static const _keyDaysCount    = 'xp_days_count';

  late SharedPreferences _prefs;
  late GamificationState _state;

  final notifier = ValueNotifier<GamificationState>(const GamificationState(
    totalXP: 0, level: 1, xpInLevel: 0, xpForNextLevel: 100, unlockedIds: [],
  ));

  GamificationState get state => _state;

  // ── XP нужно для перехода на уровень N ─────────────────────
  // Каждый уровень чуть сложнее: 100, 120, 144, ...
  static int _xpForLevel(int level) => (100 * (level * 1.2)).round();

  // ── Считаем уровень из суммарного XP ───────────────────────
  static ({int level, int xpIn, int xpFor}) _calcLevel(int totalXP) {
    int level = 1;
    int remaining = totalXP;
    while (true) {
      final needed = _xpForLevel(level);
      if (remaining < needed) {
        return (level: level, xpIn: remaining, xpFor: needed);
      }
      remaining -= needed;
      level++;
    }
  }

  // ── Инициализация ──────────────────────────────────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    final totalXP = _prefs.getInt(_keyXP) ?? 0;
    final unlockedRaw = _prefs.getString(_keyUnlocked) ?? '[]';
    final unlocked = List<String>.from(jsonDecode(unlockedRaw) as List);
    final lvl = _calcLevel(totalXP);
    _state = GamificationState(
      totalXP: totalXP,
      level: lvl.level,
      xpInLevel: lvl.xpIn,
      xpForNextLevel: lvl.xpFor,
      unlockedIds: unlocked,
    );
    notifier.value = _state;
  }

  // ── Добавить XP ─────────────────────────────────────────────
  Future<XPResult> addXP(int amount, {List<String> checkAchievements = const []}) async {
    if (amount <= 0 && checkAchievements.isEmpty) {
      return const XPResult(xpGained: 0, leveledUp: false, newLevel: 1);
    }

    final oldLevel = _state.level;
    final newTotal = _state.totalXP + amount;
    await _prefs.setInt(_keyXP, newTotal);

    // Проверяем новые достижения
    final newAchievements = <Achievement>[];
    final unlocked = List<String>.from(_state.unlockedIds);
    int bonusXP = 0;

    for (final id in checkAchievements) {
      if (!unlocked.contains(id)) {
        final ach = kAchievements.firstWhere((a) => a.id == id,
            orElse: () => const Achievement(
                id: '', emoji: '', title: '', description: '', xpReward: 0));
        if (ach.id.isNotEmpty) {
          unlocked.add(id);
          newAchievements.add(ach);
          bonusXP += ach.xpReward;
        }
      }
    }

    // Сохраняем достижения
    if (newAchievements.isNotEmpty) {
      await _prefs.setString(_keyUnlocked, jsonEncode(unlocked));
    }

    // Финальный XP с бонусами
    final finalTotal = newTotal + bonusXP;
    if (bonusXP > 0) await _prefs.setInt(_keyXP, finalTotal);

    final lvl = _calcLevel(finalTotal);
    _state = GamificationState(
      totalXP: finalTotal,
      level: lvl.level,
      xpInLevel: lvl.xpIn,
      xpForNextLevel: lvl.xpFor,
      unlockedIds: unlocked,
    );
    notifier.value = _state;

    return XPResult(
      xpGained: amount + bonusXP,
      leveledUp: lvl.level > oldLevel,
      newLevel: lvl.level,
      newAchievements: newAchievements,
    );
  }

  // ── Главный метод: вызывать после сохранения дня ──────────
  Future<XPResult> onDaySaved({
    required int streak,
    required bool hasRatings,
    required int totalDays,
  }) async {
    int xp = XPReward.daySaved;
    if (hasRatings) xp += XPReward.hasRatings;

    // Бонус за длину стрика (каждый день)
    if (streak > 1) xp += XPReward.streakDaily;

    // Счётчики для достижений
    final ratingsCount = (_prefs.getInt(_keyRatingsCount) ?? 0) + (hasRatings ? 1 : 0);
    if (hasRatings) await _prefs.setInt(_keyRatingsCount, ratingsCount);
    await _prefs.setInt(_keyDaysCount, totalDays);

    // Определяем какие достижения проверить
    final toCheck = <String>[];
    if (totalDays == 1)       toCheck.add('first_day');
    if (totalDays >= 10)      toCheck.add('days_10');
    if (totalDays >= 50)      toCheck.add('days_50');
    if (streak >= 3)          toCheck.add('streak_3');
    if (streak >= 7)          toCheck.add('streak_7');
    if (streak >= 30)         toCheck.add('streak_30');
    if (streak >= 100)        toCheck.add('streak_100');
    if (ratingsCount >= 10)   toCheck.add('ratings_master');

    final result = await addXP(xp, checkAchievements: toCheck);

    // Проверяем достижения за уровень
    final levelAchievements = <String>[];
    if (result.newLevel >= 5)  levelAchievements.add('level_5');
    if (result.newLevel >= 10) levelAchievements.add('level_10');
    if (levelAchievements.isNotEmpty) {
      return await addXP(0, checkAchievements: levelAchievements);
    }

    return result;
  }

  // ── Добавить XP за заметку ─────────────────────────────────
  Future<XPResult> onNoteAdded() => addXP(XPReward.noteAdded);

  // ── Все достижения с флагом разблокировки ─────────────────
  List<({Achievement achievement, bool unlocked})> getAllAchievements() =>
      kAchievements.map((a) => (
        achievement: a,
        unlocked: _state.isUnlocked(a.id),
      )).toList();

  // ── Сброс (для debug) ──────────────────────────────────────
  Future<void> reset() async {
    await _prefs.remove(_keyXP);
    await _prefs.remove(_keyUnlocked);
    await _prefs.remove(_keyRatingsCount);
    await _prefs.remove(_keyDaysCount);
    _load();
  }
}
