// ════════════════════════════════════════════════════
// services/rustore_billing_service.dart
// RuStore Pay SDK 10.3.1 — финальный правильный API
// ════════════════════════════════════════════════════

import 'package:flutter_rustore_pay/api/flutter_rustore_pay_client.dart';
import 'package:flutter_rustore_pay/model/purchase.dart';
import 'package:flutter_rustore_pay/model/product_type.dart';
import 'package:flutter_rustore_pay/model/purchase_availability.dart';
import 'subscription_service.dart';

class RuStoreBillingService {
  RuStoreBillingService._();
  static final RuStoreBillingService instance = RuStoreBillingService._();

  bool _available = false;

  // ── Инициализация ─────────────────────────────────
  Future<void> init() async {
    try {
      final result = await RuStorePayClient.instance
          .purchaseInteractor
          .getPurchaseAvailability();
      // PurchaseAvailabilityResult — sealed class: Available или Unavailable
      _available = result is Available;
      if (_available) await verifyOnLaunch();
    } catch (_) {
      _available = false;
    }
  }

  // ── Покупка подписки ───────────────────────────────
  Future<bool> purchaseSubscription(String productId) async {
    if (!_available) {
      // Dev-режим — активируем без оплаты
      await SubscriptionService.instance.activatePlus(
        purchaseToken: 'dev_${DateTime.now().millisecondsSinceEpoch}',
        productId: productId,
        expiresAt: productId.contains('yearly')
            ? DateTime.now().add(const Duration(days: 365))
            : DateTime.now().add(const Duration(days: 30)),
      );
      return true;
    }

    try {
      final result = await RuStorePayClient.instance
          .purchaseInteractor
          .purchase(productId);

      await SubscriptionService.instance.activatePlus(
        purchaseToken: result.purchaseId,
        productId: result.productId,
      );
      return true;
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancel') || msg.contains('cancelled')) return false;
      rethrow;
    }
  }

  // ── Восстановление покупок ─────────────────────────
  Future<bool> restorePurchases() async {
    if (!_available) return SubscriptionService.instance.isPlus;
    try {
      final purchases = await RuStorePayClient.instance
          .purchaseInteractor
          .getPurchases(productType: ProductType.subscription);

      final activeSub = purchases
          .whereType<SubscriptionPurchase>()
          .where((p) {
            final s = p.status;
            return s is SubscriptionPurchaseStatus &&
                (s == SubscriptionPurchaseStatus.active ||
                 s == SubscriptionPurchaseStatus.paused);
          })
          .firstOrNull;

      if (activeSub != null) {
        await SubscriptionService.instance.activatePlus(
          purchaseToken: activeSub.purchaseId,
          productId: activeSub.productId,
        );
        return true;
      }
      await SubscriptionService.instance.deactivate();
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Проверка при запуске ───────────────────────────
  Future<void> verifyOnLaunch() async {
    if (!_available) return;
    try {
      final purchases = await RuStorePayClient.instance
          .purchaseInteractor
          .getPurchases(productType: ProductType.subscription);

      final hasActive = purchases
          .whereType<SubscriptionPurchase>()
          .any((p) {
            final s = p.status;
            return s is SubscriptionPurchaseStatus &&
                (s == SubscriptionPurchaseStatus.active ||
                 s == SubscriptionPurchaseStatus.paused);
          });

      if (!hasActive && SubscriptionService.instance.isPlus) {
        await SubscriptionService.instance.deactivate();
      }
    } catch (_) {}
  }
}
