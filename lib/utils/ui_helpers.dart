// ════════════════════════════════════════════════════
// utils/ui_helpers.dart — общие UI утилиты
//
// showAppSnack() — стилизованный Snackbar под дизайн
// Использование:
//   showAppSnack(context, 'Сохранено ✓');
//   showAppSnack(context, 'Ошибка', isError: true);
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app.dart';

void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final accent = AppSettings.of(context).accent;
  final color  = isError ? const Color(0xFFE57373) : accent;

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 3),
        elevation: 0,
      ),
    );
}

// ─── Haptic shortcuts ─────────────────────────────────────────
// Вызывай вместо прямого HapticFeedback — удобнее менять глобально

/// Лёгкий: свайпы, переключения
void hapticLight() => HapticFeedback.lightImpact();

/// Средний: нажатия кнопок, выбор даты
void hapticMedium() => HapticFeedback.mediumImpact();

/// Тяжёлый: сохранение дня, активация Premium
void hapticHeavy() => HapticFeedback.heavyImpact();

/// Успех (iOS: success pattern, Android: medium)
void hapticSuccess() => HapticFeedback.mediumImpact();
