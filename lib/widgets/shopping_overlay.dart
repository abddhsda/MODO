// ════════════════════════════════════════════════════
// widgets/shopping_overlay.dart
//
// Баннер со списком покупок — показывается над карточкой
// дня на главном экране. Тап раскрывает полный список.
// Счётчики ± работают прямо в баннере.
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../app.dart';
import '../utils/ui_helpers.dart';
import '../services/shopping_service.dart';

// ─────────────────────────────────────────────────────
// ShoppingBanner — компактный баннер поверх карточки
// ─────────────────────────────────────────────────────
class ShoppingBanner extends StatelessWidget {
  final List<ShoppingItem> items;
  final VoidCallback onTap;
  final void Function(String id, bool checked) onToggle;
  final void Function(String id, int delta) onCount;

  const ShoppingBanner({
    super.key,
    required this.items,
    required this.onTap,
    required this.onToggle,
    required this.onCount,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final accent   = AppSettings.of(context).accent;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bg       = isDark ? const Color(0xFF1E2A1E) : const Color(0xFFF0FAF0);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final doneCount = items.where((i) => i.checked).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('🛒',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text('Список покупок',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$doneCount/${items.length}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: textColor.withValues(alpha: 0.35), size: 20),
                ],
              ),
            ),

            // Прогресс-бар
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: items.isEmpty ? 0 : doneCount / items.length,
                  minHeight: 4,
                  backgroundColor: accent.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Первые 3 элемента
            ...items.take(3).map((item) => _BannerItem(
                  item: item,
                  accent: accent,
                  textColor: textColor,
                  onToggle: () => onToggle(item.id, !item.checked),
                  onCount: (delta) => onCount(item.id, delta),
                )),

            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Ещё ${items.length - 3} позиций...',
                  style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.4)),
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  final ShoppingItem item;
  final Color accent;
  final Color textColor;
  final VoidCallback onToggle;
  final void Function(int delta) onCount;

  const _BannerItem({
    required this.item,
    required this.accent,
    required this.textColor,
    required this.onToggle,
    required this.onCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          // Чекбокс
          GestureDetector(
            onTap: () { hapticLight(); onToggle(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.checked ? accent : Colors.transparent,
                border: Border.all(
                    color: item.checked
                        ? accent
                        : textColor.withValues(alpha: 0.25),
                    width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: item.checked
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),

          // Название
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                  fontSize: 14,
                  color: item.checked
                      ? textColor.withValues(alpha: 0.35)
                      : textColor,
                  decoration:
                      item.checked ? TextDecoration.lineThrough : null,
                  decorationColor: textColor.withValues(alpha: 0.35)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Счётчик ±
          _CounterRow(
            count: item.count,
            accent: accent,
            textColor: textColor,
            onDelta: onCount,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// ShoppingFullSheet — полный список в bottom sheet
// ─────────────────────────────────────────────────────
class ShoppingFullSheet extends StatefulWidget {
  final List<ShoppingItem> items;
  final void Function(List<ShoppingItem>) onChanged;

  const ShoppingFullSheet({
    super.key,
    required this.items,
    required this.onChanged,
  });

  @override
  State<ShoppingFullSheet> createState() => _ShoppingFullSheetState();
}

class _ShoppingFullSheetState extends State<ShoppingFullSheet> {
  late List<ShoppingItem> _items;
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    hapticMedium();
    setState(() {
      _items.add(ShoppingItem(
        id:      DateTime.now().millisecondsSinceEpoch.toString(),
        name:    name,
        count:   1,
        checked: false,
      ));
      _ctrl.clear();
    });
    widget.onChanged(_items);
  }

  void _toggle(String id) {
    hapticLight();
    setState(() {
      final i = _items.indexWhere((e) => e.id == id);
      if (i < 0) return;
      _items[i] = _items[i].copyWith(checked: !_items[i].checked);
    });
    widget.onChanged(_items);
  }

  void _setCount(String id, int delta) {
    setState(() {
      final i = _items.indexWhere((e) => e.id == id);
      if (i < 0) return;
      final newCount = (_items[i].count + delta).clamp(1, 99);
      _items[i] = _items[i].copyWith(count: newCount);
    });
    widget.onChanged(_items);
  }

  void _delete(String id) {
    hapticMedium();
    setState(() => _items.removeWhere((e) => e.id == id));
    widget.onChanged(_items);
  }

  void _clearDone() {
    hapticMedium();
    setState(() => _items.removeWhere((e) => e.checked));
    widget.onChanged(_items);
  }

  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final surface   = Theme.of(context).colorScheme.surface;
    final doneCount = _items.where((i) => i.checked).length;

    // Сортируем: непомеченные вверху
    final sorted = [..._items.where((e) => !e.checked),
                    ..._items.where((e) => e.checked)];

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Хэндл
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('🛒', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text('Список покупок',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textColor)),
                const Spacer(),
                if (doneCount > 0)
                  GestureDetector(
                    onTap: _clearDone,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Очистить',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Поле ввода
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 15, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Добавить продукт...',
                      hintStyle: TextStyle(
                          color: textColor.withValues(alpha: 0.35),
                          fontSize: 15),
                      filled: true,
                      fillColor: surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _add,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Список
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(children: [
                const Text('🛒', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('Список пуст',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                const SizedBox(height: 4),
                Text('Добавь первый продукт',
                    style: TextStyle(
                        fontSize: 13,
                        color: textColor.withValues(alpha: 0.4))),
              ]),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shrinkWrap: true,
                itemCount: sorted.length,
                itemBuilder: (_, i) {
                  final item = sorted[i];
                  return _FullSheetItem(
                    key: ValueKey(item.id),
                    item: item,
                    accent: accent,
                    textColor: textColor,
                    surface: surface,
                    onToggle: () => _toggle(item.id),
                    onCount: (d) => _setCount(item.id, d),
                    onDelete: () => _delete(item.id),
                  );
                },
              ),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FullSheetItem extends StatelessWidget {
  final ShoppingItem item;
  final Color accent;
  final Color textColor;
  final Color surface;
  final VoidCallback onToggle;
  final void Function(int) onCount;
  final VoidCallback onDelete;

  const _FullSheetItem({
    super.key,
    required this.item,
    required this.accent,
    required this.textColor,
    required this.surface,
    required this.onToggle,
    required this.onCount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: item.checked
            ? Border.all(color: accent.withValues(alpha: 0.15))
            : null,
      ),
      child: Row(children: [
        // Чекбокс
        GestureDetector(
          onTap: onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: item.checked ? accent : Colors.transparent,
              border: Border.all(
                  color: item.checked
                      ? accent
                      : textColor.withValues(alpha: 0.25),
                  width: 1.8),
              borderRadius: BorderRadius.circular(7),
            ),
            child: item.checked
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 12),

        // Название
        Expanded(
          child: Text(
            item.name,
            style: TextStyle(
                fontSize: 15,
                color: item.checked
                    ? textColor.withValues(alpha: 0.35)
                    : textColor,
                decoration:
                    item.checked ? TextDecoration.lineThrough : null,
                decorationColor: textColor.withValues(alpha: 0.35)),
          ),
        ),

        const SizedBox(width: 8),

        // Счётчик
        _CounterRow(
          count: item.count,
          accent: accent,
          textColor: textColor,
          onDelta: onCount,
        ),

        const SizedBox(width: 8),

        // Удалить
        GestureDetector(
          onTap: onDelete,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.delete_outline_rounded,
                size: 18,
                color: textColor.withValues(alpha: 0.2)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────
// _CounterRow — кнопки ± с числом
// ─────────────────────────────────────────────────────
class _CounterRow extends StatelessWidget {
  final int count;
  final Color accent;
  final Color textColor;
  final void Function(int delta) onDelta;

  const _CounterRow({
    required this.count,
    required this.accent,
    required this.textColor,
    required this.onDelta,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CountBtn(
          icon: Icons.remove,
          accent: accent,
          onTap: count > 1 ? () { hapticLight(); onDelta(-1); } : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor),
          ),
        ),
        _CountBtn(
          icon: Icons.add,
          accent: accent,
          onTap: () { hapticLight(); onDelta(1); },
        ),
      ],
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const _CountBtn({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.15)
              : accent.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 14,
            color: active ? accent : accent.withValues(alpha: 0.3)),
      ),
    );
  }
}
