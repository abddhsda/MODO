// ════════════════════════════════════════════════════
// constants/colors.dart — все цвета приложения
//
// ПРАВИЛО: нигде в коде не писать Color(0xFF...) напрямую.
// Всегда использовать константы отсюда.
//
// Как добавить новый акцент:
//   1. Добавить const под "Акцентные цвета"
//   2. Добавить в список accents[]
//   3. Добавить имя в accentNames[]
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class AppColors {

  // ─── Акцентные цвета (выбор в настройках) ────────────────────
  // Порядок важен: accentIndex в SharedPreferences = индекс в этом списке
  static const Color accentOrange  = Color(0xFFE8927C); // 🟠 Оранжевый    — index 0
  static const Color accentBlue    = Color(0xFF5B8CDB); // 🔵 Сине-голубой  — index 1
  static const Color accentPurple  = Color(0xFF9B59B6); // 🟣 Фиолетовый   — index 2
  static const Color accentGreen   = Color(0xFF2ECC71); // 🟢 Зелёный      — index 3

  static const List<Color> accents = [
    accentOrange,
    accentBlue,
    accentPurple,
    accentGreen,
  ];

  static const List<String> accentNames = [
    'Оранжевый',
    'Сине-голубой',
    'Фиолетовый',
    'Зелёный',
  ];

  // ─── Фоновые цвета ───────────────────────────────────────────
  static const Color darkBg      = Color(0xFF121212); // тёмный фон (до наложения акцента)
  static const Color lightBg     = Color(0xFFFFFBF8); // светлый фон (тёплый белый)

  static const Color darkSurface  = Color(0xFF1E1E1E); // карточки в тёмной теме
  static const Color lightSurface = Color(0xFFEEEEEE); // карточки в светлой теме

  // ─── Текстовые цвета ─────────────────────────────────────────
  static const Color textDark     = Color(0xFF1A1A1A); // основной текст в светлой теме
  static const Color textLight    = Colors.white;       // основной текст в тёмной теме

  // ─── UI-элементы ─────────────────────────────────────────────
  static const Color gold         = Color(0xFFFFD700); // 🏅 золото — стрик, граница сегодняшнего дня

  // ─── Цвета метрик (графики в StatsScreen) ────────────────────
  // Порядок совпадает с порядком _metrics в StatsScreen
  static const Color metricEnergy       = accentOrange;       // 😴 Энергия
  static const Color metricProductivity = accentBlue;         // 🎯 Продуктивность
  static const Color metricMood         = accentPurple;       // 🧠 Настроение
  static const Color metricFood         = Color(0xFFFFD700);  // 🍎 Еда (золото)
  static const Color metricSleep        = accentGreen;        // 💤 Сон

  static const List<Color> metricColors = [
    metricEnergy,
    metricProductivity,
    metricMood,
    metricFood,
    metricSleep,
  ];

  // ─── iOS-специфичные цвета (если нужно отличие от Android) ───
  // Пока совпадают с общими, но вынесены для гибкости
  // ignore: unused_field
  static const Color _iosAccentFallback = accentOrange;

  // ─── Android-специфичные цвета ────────────────────────────────
  // ignore: unused_field
  static const Color _androidAccentFallback = accentOrange;

  // ─── Вспомогательные ─────────────────────────────────────────
  // Прозрачности задаются через .withValues(alpha: ) в коде,
  // но базовые уровни можно зафиксировать здесь:
  static const double dimLow    = 0.04; // очень слабый оттенок фона
  static const double dimMid    = 0.08; // поверхности/карточки
  static const double dimHigh   = 0.15; // активные элементы без акцента
  static const double dimBorder = 0.25; // рамки
}
