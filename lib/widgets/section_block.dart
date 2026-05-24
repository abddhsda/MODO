// ════════════════════════════════════════════════════
// widgets/section_block.dart — коллапсируемый блок
// Тап по заголовку → expand / collapse с анимацией
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../utils/ui_helpers.dart';

class SectionBlock extends StatefulWidget {
  final String emoji;
  final String title;
  final Color labelColor;
  final List<Widget> children;
  final bool initiallyExpanded;
  final void Function(bool)? onToggle;
  final String? emptyHint;

  const SectionBlock({
    super.key,
    required this.emoji,
    required this.title,
    required this.labelColor,
    required this.children,
    this.initiallyExpanded = true, // ← открыт по умолчанию
    this.onToggle,
    this.emptyHint,
  });

  @override
  State<SectionBlock> createState() => _SectionBlockState();
}

class _SectionBlockState extends State<SectionBlock>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    hapticLight();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onToggle?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final bg = isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.04), surface)
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.03), surface);

    return Container(
      clipBehavior: Clip.none, // bubble метрик может выходить за верхний край
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.labelColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок ────────────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title,
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.labelColor)),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.expand_more,
                      color: widget.labelColor, size: 20),
                ),
              ]),
            ),
          ),

          // ── Превью (свёрнуто) ─────────────────────────────────
          if (!_expanded && widget.emptyHint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(widget.emptyHint!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13,
                      color: widget.labelColor.withValues(alpha: 0.6),
                      height: 1.4)),
            ),

          // ── Содержимое с анимацией ────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: widget.labelColor.withValues(alpha: 0.1)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.children,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
