// ════════════════════════════════════════════════════
// widgets/subscription_badge.dart
//
// Карточка статуса подписки для SettingsScreen.
// Вставить в settings_screen.dart прямо над секцией «Экспорт».
//
// Использование:
//   SubscriptionBadge(onUpgrade: () { ... })
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';
import '../utils/ui_helpers.dart';

class SubscriptionBadge extends StatelessWidget {
  final VoidCallback? onUpgraded;

  const SubscriptionBadge({super.key, this.onUpgraded});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubscriptionPlan>(
      valueListenable: SubscriptionService.instance.notifier,
      builder: (context, plan, _) {
        return plan.isPlus
            ? _PlusBadge()
            : _FreeBanner(onUpgraded: onUpgraded);
      },
    );
  }
}

// ── Бейдж для активного Plus ─────────────────────────────────
class _PlusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final accent     = AppSettings.of(context).accent;
    final textColor  = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⭐', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MODO Плюс активен',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                Text('Все функции разблокированы',
                    style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.45))),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: accent, size: 22),
        ],
      ),
    );
  }
}

// ── Баннер-призыв для бесплатного плана ─────────────────────
class _FreeBanner extends StatelessWidget {
  final VoidCallback? onUpgraded;

  const _FreeBanner({this.onUpgraded});

  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: () {
        hapticLight();
        PaywallScreen.show(
          context,
          reason: PaywallReason.manual,
          onPurchased: onUpgraded,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('⭐', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('MODO Плюс',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('от 83 ₽/мес',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent)),
                      ),
                    ],
                  ),
                  Text('Безлимит, экспорт, защита стрика',
                      style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.45))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: textColor.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
