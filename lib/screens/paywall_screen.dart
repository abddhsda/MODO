// ════════════════════════════════════════════════════
// screens/paywall_screen.dart — экран подписки MODO Плюс
//
// Показывается когда пользователь упирается в лимит
// бесплатного плана или заходит в раздел Premium.
//
// Механика:
//   • Переключатель Месяц / Год (год со скидкой)
//   • Список фич с чекбоксами
//   • Кнопка "Начать бесплатный триал" (7 дней)
//   • Восстановить покупку
//   • Мелкий текст с условиями
//
// Интеграция:
//   onPurchased — вызывается из home_screen после успешной покупки.
//   Пока покупка — заглушка: вызываем SubscriptionService.activatePlus()
//   с тестовыми данными. Заменить на RuStore Billing вызов.
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../services/subscription_service.dart';
import '../services/rustore_billing_service.dart';
import '../utils/ui_helpers.dart';

// Причина показа paywall — для заголовка и подзаголовка
enum PaywallReason {
  entryLimit,     // лимит записей
  exportBlocked,  // попытка экспорта
  accentLocked,   // заблокированный цвет
  freezeLimit,    // кончились заморозки
  manual,         // пользователь сам открыл
}

class PaywallScreen extends StatefulWidget {
  final PaywallReason reason;
  final VoidCallback? onPurchased;

  const PaywallScreen({
    super.key,
    this.reason = PaywallReason.manual,
    this.onPurchased,
  });

  // Удобный метод показа поверх текущего экрана
  static Future<bool> show(
    BuildContext context, {
    PaywallReason reason = PaywallReason.manual,
    VoidCallback? onPurchased,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaywallScreen(reason: reason, onPurchased: onPurchased),
      ),
    );
    return result ?? false;
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  bool _yearlySelected = true; // по умолчанию год — выгоднее
  bool _loading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Тексты в зависимости от причины ───────────────────────
  String get _title {
    switch (widget.reason) {
      case PaywallReason.entryLimit:   return 'Лимит на сегодня';
      case PaywallReason.exportBlocked: return 'Экспорт — в Плюсе';
      case PaywallReason.accentLocked: return 'Цвет заблокирован';
      case PaywallReason.freezeLimit:  return 'Заморозки кончились';
      case PaywallReason.manual:       return 'MODO Плюс';
    }
  }

  String get _subtitle {
    switch (widget.reason) {
      case PaywallReason.entryLimit:
        return 'Бесплатный план — 3 записи в день.\nПерейди в Плюс — без ограничений.';
      case PaywallReason.exportBlocked:
        return 'Экспорт дневника в TXT, CSV и JSON\nдоступен в MODO Плюс.';
      case PaywallReason.accentLocked:
        return 'Дополнительные цвета оформления\nдоступны в MODO Плюс.';
      case PaywallReason.freezeLimit:
        return 'Бесплатный план: 1 заморозка в месяц.\nВ Плюсе — стрик защищён всегда.';
      case PaywallReason.manual:
        return 'Разблокируй всё и поддержи\nразработку приложения.';
    }
  }

  // ── Цена ──────────────────────────────────────────────────
  String get _priceLabel {
    if (_yearlySelected) {
      // 999 ÷ 12 = 83.25 → показываем ~83 ₽/мес
      return '83 ₽ / мес';
    }
    return '149 ₽ / мес';
  }

  String get _totalLabel {
    if (_yearlySelected) return 'Списывается 999 ₽ в год';
    return 'Списывается 149 ₽ в месяц';
  }

  // ── Покупка (заглушка → RuStore Billing) ─────────────────
  Future<void> _purchase() async {
    if (_loading) return;
    hapticMedium();
    setState(() => _loading = true);

    try {
      final productId = _yearlySelected
          ? kProductPlus.idYearly
          : kProductPlus.idMonthly;

      final success = await RuStoreBillingService.instance
          .purchaseSubscription(productId);

      if (success && mounted) {
        hapticSuccess();
        widget.onPurchased?.call();
        _showSuccessAndClose();
      }
    } on Exception catch (e) {
      if (mounted) {
        final msg = e.toString().contains('CANCELLED')
            ? 'Покупка отменена'
            : 'Ошибка покупки. Попробуй ещё раз.';
        showAppSnack(context, msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Восстановить покупку ───────────────────────────────────
  Future<void> _restore() async {
    hapticLight();
    setState(() => _loading = true);
    try {
      final restored = await RuStoreBillingService.instance.restorePurchases();
      if (mounted) {
        if (restored) {
          widget.onPurchased?.call();
          _showSuccessAndClose();
        } else {
          showAppSnack(context, 'Активных подписок не найдено');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessAndClose() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text('⭐', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              'Добро пожаловать\nв MODO Плюс!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Все ограничения сняты.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);  // закрыть диалог
                  Navigator.pop(context, true); // закрыть paywall
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppSettings.of(context).accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Отлично!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent     = AppSettings.of(context).accent;
    final bgColor    = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Шапка ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.4)),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  TextButton(
                    onPressed: _restore,
                    child: Text(
                      'Восстановить',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Прокручиваемое тело ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Иконка
                    Center(
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('⭐', style: TextStyle(fontSize: 40)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Заголовок
                    Center(
                      child: Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor.withValues(alpha: 0.55),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Переключатель Месяц / Год ────────────────
                    _PeriodToggle(
                      yearlySelected: _yearlySelected,
                      accent: accent,
                      textColor: textColor,
                      onChanged: (yearly) {
                        hapticLight();
                        setState(() => _yearlySelected = yearly);
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Цена ─────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _priceLabel,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: accent,
                            ),
                          ),
                          Text(
                            _totalLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: textColor.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Фичи ─────────────────────────────────────
                    _FeatureList(textColor: textColor, accent: accent),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Кнопка (прилипает к низу) ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _purchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: accent.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              _yearlySelected
                                  ? 'Оформить за 999 ₽ / год'
                                  : 'Оформить за 149 ₽ / мес',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Отмени в любой момент. Без скрытых платежей.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Переключатель периода ────────────────────────────────────
class _PeriodToggle extends StatelessWidget {
  final bool yearlySelected;
  final Color accent;
  final Color textColor;
  final ValueChanged<bool> onChanged;

  const _PeriodToggle({
    required this.yearlySelected,
    required this.accent,
    required this.textColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _tab('Месяц', !yearlySelected, null),
          _tab('Год', yearlySelected, '−44%'),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, String? badge) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(label == 'Год'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : textColor.withValues(alpha: 0.5),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Список фич ───────────────────────────────────────────────
class _FeatureList extends StatelessWidget {
  final Color textColor;
  final Color accent;

  const _FeatureList({required this.textColor, required this.accent});

  static const _features = [
    ('🔥', 'Безлимитный дневник', 'Записей сколько угодно каждый день'),
    ('❄️', 'Защита стрика',       'Заморозки стрика без ограничений'),
    ('📊', 'Вся статистика',      'История за всё время, не только 7 дней'),
    ('🎨', 'Все цвета оформления','Полная палитра акцентных цветов'),
    ('📤', 'Экспорт дневника',    'TXT, CSV, JSON в любой момент'),
    ('🔔', 'Гибкие напоминания',  'Настрой столько уведомлений сколько нужно'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _features.map((f) {
          final isLast = f == _features.last;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.$1, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.$2,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor)),
                        const SizedBox(height: 2),
                        Text(f.$3,
                            style: TextStyle(
                                fontSize: 13,
                                color: textColor.withValues(alpha: 0.45))),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded,
                      color: accent, size: 20),
                ],
              ),
              if (!isLast) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: textColor.withValues(alpha: 0.06)),
                const SizedBox(height: 12),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }
}
