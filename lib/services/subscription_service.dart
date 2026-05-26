// ════════════════════════════════════════════════════
// services/subscription_service.dart
//
// Управляет статусом подписки MODO.
//
// Архитектура:
//   • Хранит статус локально в SharedPreferences.
//   • При подключении RuStore Billing — вызов verifyWithStore()
//     заменяет локальную проверку серверной.
//   • SubscriptionNotifier — ValueNotifier для реактивного UI.
//
// Планы:
//   free   — базовые лимиты
//   plus   — безлимит + экспорт + все темы
//   (pro убран по требованию — нет ИИ-анализа)
//
// Лимиты бесплатного плана:
//   • Максимум 3 записи в день
//   • Защита стрика: 1 заморозка в месяц (у платных — безлимит)
//   • Дополнительные цвета акцента — только Plus
//   • Экспорт — только Plus
// ════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Перечисление планов ───────────────────────────────────────
enum SubscriptionPlan { free, plus }

extension SubscriptionPlanX on SubscriptionPlan {
  bool get isFree => this == SubscriptionPlan.free;
  bool get isPlus => this == SubscriptionPlan.plus;

  String get displayName {
    switch (this) {
      case SubscriptionPlan.free: return 'Базовая';
      case SubscriptionPlan.plus: return 'MODO Плюс';
    }
  }

  String get emoji {
    switch (this) {
      case SubscriptionPlan.free: return '🔓';
      case SubscriptionPlan.plus: return '⭐';
    }
  }
}

// ─── Константы ключей ─────────────────────────────────────────
class _Keys {
  static const plan           = 'subscription_plan';
  static const expiresAt      = 'subscription_expires_at';
  static const purchaseToken  = 'subscription_purchase_token';
  static const productId      = 'subscription_product_id';
  static const freezesUsed    = 'subscription_freezes_used_month';
  static const freezesMonth   = 'subscription_freezes_month';
}

// ─── Продукты РуСтора ─────────────────────────────────────────
class SubscriptionProduct {
  final String id;
  final String title;
  final int priceMonthly;       // ₽/мес
  final int priceYearly;        // ₽/год
  final String idMonthly;       // ID продукта в РуСторе
  final String idYearly;

  const SubscriptionProduct({
    required this.id,
    required this.title,
    required this.priceMonthly,
    required this.priceYearly,
    required this.idMonthly,
    required this.idYearly,
  });
}

const kProductPlus = SubscriptionProduct(
  id:           'plus',
  title:        'MODO Плюс',
  priceMonthly: 149,
  priceYearly:  999,
  idMonthly:    'modo_plus_monthly',
  idYearly:     'modo_plus_yearly',
);

// ─── Notifier для реактивного UI ──────────────────────────────
class SubscriptionNotifier extends ValueNotifier<SubscriptionPlan> {
  SubscriptionNotifier(super.value);
}

// ─── Сервис ───────────────────────────────────────────────────
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  late SharedPreferences _prefs;
  final notifier = SubscriptionNotifier(SubscriptionPlan.free);

  SubscriptionPlan get plan => notifier.value;
  bool get isPlus => plan.isPlus;
  bool get isFree => plan.isFree;

  // ── Инициализация (вызвать в main до runApp) ───────────────
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _syncFromPrefs();
  }

  // ── Читаем статус из prefs ─────────────────────────────────
  void _syncFromPrefs() {
    final stored = _prefs.getString(_Keys.plan) ?? 'free';
    final expiresRaw = _prefs.getString(_Keys.expiresAt);

    SubscriptionPlan resolved;
    if (stored == 'plus') {
      // Проверяем срок действия (если есть)
      if (expiresRaw != null) {
        final expires = DateTime.tryParse(expiresRaw);
        if (expires != null && expires.isAfter(DateTime.now())) {
          resolved = SubscriptionPlan.plus;
        } else {
          // Подписка истекла
          resolved = SubscriptionPlan.free;
          _prefs.setString(_Keys.plan, 'free');
        }
      } else {
        // Нет срока — считаем активной (тестовый режим)
        resolved = SubscriptionPlan.plus;
      }
    } else {
      resolved = SubscriptionPlan.free;
    }

    notifier.value = resolved;
  }

  // ── Активировать Plus (вызывается после успешной покупки) ──
  Future<void> activatePlus({
    required String purchaseToken,
    required String productId,
    DateTime? expiresAt,
  }) async {
    await _prefs.setString(_Keys.plan, 'plus');
    await _prefs.setString(_Keys.purchaseToken, purchaseToken);
    await _prefs.setString(_Keys.productId, productId);
    if (expiresAt != null) {
      await _prefs.setString(_Keys.expiresAt, expiresAt.toIso8601String());
    }
    notifier.value = SubscriptionPlan.plus;
  }

  // ── Деактивировать (при отмене / истечении) ───────────────
  Future<void> deactivate() async {
    await _prefs.setString(_Keys.plan, 'free');
    await _prefs.remove(_Keys.expiresAt);
    await _prefs.remove(_Keys.purchaseToken);
    await _prefs.remove(_Keys.productId);
    notifier.value = SubscriptionPlan.free;
  }

  // ── Восстановление покупок (заглушка → вызов RuStore API) ─
  // TODO: заменить тело на вызов RuStore Billing после подключения SDK
  Future<bool> restorePurchases() async {
    // Здесь будет: final purchases = await RuStoreBillingClient.getPurchases();
    // Пока просто перечитываем prefs (работает в тестовом режиме)
    _syncFromPrefs();
    return isPlus;
  }

  // ─────────────────────────────────────────────────────────
  // ЛИМИТЫ БЕСПЛАТНОГО ПЛАНА
  // ─────────────────────────────────────────────────────────

  /// Можно ли добавить ещё одну запись сегодня?
  /// Free: максимум 3 записи в день.
  /// Plus: безлимит.
  bool canAddEntry(int todayEntriesCount) {
    if (isPlus) return true;
    return todayEntriesCount < 3;
  }

  /// Доступен ли экспорт?
  bool get canExport => isPlus;

  /// Доступны ли дополнительные акцентные цвета (сверх первых двух)?
  bool canUseAccentAt(int index) {
    if (isPlus) return true;
    return index < 2; // первые два цвета — бесплатно
  }

  /// Сколько заморозок стрика доступно в этом месяце?
  int get freezesAvailableThisMonth {
    if (isPlus) return 999; // безлимит
    // Free: 1 заморозка в месяц
    final now = DateTime.now();
    final storedMonth = _prefs.getString(_Keys.freezesMonth);
    final thisMonth = '${now.year}-${now.month}';
    if (storedMonth != thisMonth) {
      // Новый месяц — счётчик сбрасывается
      _prefs.setString(_Keys.freezesMonth, thisMonth);
      _prefs.setInt(_Keys.freezesUsed, 0);
      return 1;
    }
    final used = _prefs.getInt(_Keys.freezesUsed) ?? 0;
    return (1 - used).clamp(0, 1);
  }

  Future<void> recordFreezeUsed() async {
    final now = DateTime.now();
    final thisMonth = '${now.year}-${now.month}';
    await _prefs.setString(_Keys.freezesMonth, thisMonth);
    final used = _prefs.getInt(_Keys.freezesUsed) ?? 0;
    await _prefs.setInt(_Keys.freezesUsed, used + 1);
  }

  // ── Диагностика (убрать перед релизом) ────────────────────
  Map<String, dynamic> debugInfo() => {
    'plan':           plan.displayName,
    'isPlus':         isPlus,
    'expiresAt':      _prefs.getString(_Keys.expiresAt) ?? '—',
    'productId':      _prefs.getString(_Keys.productId) ?? '—',
    'freezesLeft':    freezesAvailableThisMonth,
  };
}
