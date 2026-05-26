// ════════════════════════════════════════════════════
// screens/diary_editor_screen.dart
// Текстовый редактор (Quill) + фото поверх текста (float).
// Фото перетаскиваются свободно, меняют размер за углы.
// ════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../app.dart';
import '../services/photo_service.dart';
import '../services/subscription_service.dart';
import '../screens/paywall_screen.dart';

// ─── Модель плавающего фото ───────────────────────────
class _FloatPhoto {
  final String path;
  double x, y, w;
  _FloatPhoto({required this.path, required this.x,
      required this.y, required this.w});

  Map<String, dynamic> toJson() =>
      {'path': path, 'x': x, 'y': y, 'w': w};

  factory _FloatPhoto.fromJson(Map<String, dynamic> j) => _FloatPhoto(
    path: j['path'] as String,
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
    w: (j['w'] as num).toDouble(),
  );
}

// ─── DiaryEditorScreen ────────────────────────────────
class DiaryEditorScreen extends StatefulWidget {
  final String dateLabel, dateKey, initialNoteJson;
  final List<String> initialPhotos;
  final Future<void> Function(String) onNoteSaved;
  final Future<void> Function(List<String>) onPhotosSaved;

  const DiaryEditorScreen({super.key,
    required this.dateLabel, required this.dateKey,
    required this.initialNoteJson, required this.initialPhotos,
    required this.onNoteSaved, required this.onPhotosSaved});

  static Future<void> show(BuildContext context, {
    required String dateLabel, required String dateKey,
    required String initialNoteJson, required List<String> initialPhotos,
    required Future<void> Function(String) onNoteSaved,
    required Future<void> Function(List<String>) onPhotosSaved,
  }) => Navigator.push(context, MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => DiaryEditorScreen(
      dateLabel: dateLabel, dateKey: dateKey,
      initialNoteJson: initialNoteJson, initialPhotos: initialPhotos,
      onNoteSaved: onNoteSaved, onPhotosSaved: onPhotosSaved)));

  @override
  State<DiaryEditorScreen> createState() => _State();
}

class _State extends State<DiaryEditorScreen> {
  late QuillController _qctrl;
  Timer? _debounce;
  bool   _saving     = false;
  bool   _showColors = false;
  Color  _activeColor = Colors.yellowAccent;

  // Плавающие фото
  final List<_FloatPhoto> _floats = [];
  String? _selectedPath;
  final _scrollCtrl = ScrollController();
  final _focusNode  = FocusNode();

  static const _colors = [
    Colors.white, Colors.yellowAccent,
    Color(0xFF80CBFF), Color(0xFF90EE90),
    Color(0xFFFFB347), Color(0xFFFF8080), Color(0xFFDDA0DD),
  ];

  @override
  void initState() {
    super.initState();
    _qctrl = _buildCtrl();
    _qctrl.addListener(_onChange);
    _loadFloats();
  }

  QuillController _buildCtrl() {
    try {
      final s = widget.initialNoteJson;
      // Если JSON начинается с { — это наш формат {text:..., photos:[...]}
      if (s.isNotEmpty && s.trimLeft().startsWith('{')) {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final textJson = map['text'] as List?;
        if (textJson != null) {
          final delta = Delta.fromJson(textJson);
          return QuillController(
            document: Document.fromDelta(delta),
            selection: const TextSelection.collapsed(offset: 0));
        }
      }
      // Legacy: plain delta array
      if (s.isNotEmpty && s.trimLeft().startsWith('[')) {
        final delta = Delta.fromJson(jsonDecode(s) as List);
        return QuillController(
          document: Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0));
      }
    } catch (_) {}
    final s = widget.initialNoteJson;
    if (s.isEmpty) return QuillController.basic();
    final doc = Document()..insert(0, s);
    return QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0));
  }

  void _loadFloats() {
    try {
      final s = widget.initialNoteJson;
      if (s.isNotEmpty && s.trimLeft().startsWith('{')) {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final photos = map['photos'] as List?;
        if (photos != null) {
          for (final p in photos) {
            _floats.add(_FloatPhoto.fromJson(p as Map<String, dynamic>));
          }
        }
      }
    } catch (_) {}
  }

  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    if (!mounted) return;
    setState(() => _saving = true);
    // Сохраняем текст + позиции фото в один JSON
    final textJson = _qctrl.document.toDelta().toJson();
    final photosJson = _floats.map((f) => f.toJson()).toList();
    final combined = jsonEncode({'text': textJson, 'photos': photosJson});
    await widget.onNoteSaved(combined);
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qctrl.removeListener(_onChange);
    _qctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Добавить фото ─────────────────────────────────
  Future<void> _addPhoto() async {
    final photos = widget.initialPhotos;
    final max = PhotoService.instance.maxPhotos;
    if (photos.length >= max) {
      if (SubscriptionService.instance.isFree && mounted)
        await PaywallScreen.show(context, reason: PaywallReason.manual);
      return;
    }
    if (!mounted) return;
    final path = await PhotoService.instance.pick(
        context, dateKey: widget.dateKey, index: photos.length);
    if (path == null || !mounted) return;

    final newPhotos = [...photos, path];
    await widget.onPhotosSaved(newPhotos);

    // Добавляем float по центру экрана
    final sw = MediaQuery.of(context).size.width;
    final w  = sw * 0.6;
    setState(() {
      _floats.add(_FloatPhoto(
        path: path, x: (sw - w) / 2, y: 80, w: w));
      _selectedPath = path;
    });
    _onChange();
    HapticFeedback.lightImpact();
  }

  // ── Форматирование ────────────────────────────────
  void _fmt(Attribute a) {
    _qctrl.formatSelection(a);
    HapticFeedback.selectionClick();
    setState(() {});
  }

  bool get _isBold   => _attrs.containsKey(Attribute.bold.key);
  bool get _isItalic => _attrs.containsKey(Attribute.italic.key);
  bool get _isUnder  => _attrs.containsKey(Attribute.underline.key);
  bool get _isStrike => _attrs.containsKey(Attribute.strikeThrough.key);
  bool get _isBullet => _attrs[Attribute.list.key]?.value == 'bullet';
  Map<String, Attribute> get _attrs =>
      _qctrl.getSelectionStyle().attributes;

  String get _sizeLabel {
    final h = _attrs[Attribute.header.key]?.value;
    if (h == 1) return 'H1';
    if (h == 2) return 'H2';
    return 'Аа';
  }

  void _showSizeSheet(Color accent, Color tc, Color bg) {
    final cur = _sizeLabel;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(color: bg,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20))),
        padding: EdgeInsets.fromLTRB(20, 16, 20,
            20 + MediaQuery.of(context).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(tc), const SizedBox(height: 20),
          _szRow('Заголовок',    28, FontWeight.w900, cur == 'H1', accent, tc,
              onTap: () { Navigator.pop(context); _fmt(Attribute.h1); }),
          _szRow('Подзаголовок', 22, FontWeight.w700, cur == 'H2', accent, tc,
              onTap: () { Navigator.pop(context); _fmt(Attribute.h2); }),
          _szRow('Обычный',      16, FontWeight.w400, cur == 'Аа', accent, tc,
              onTap: () { Navigator.pop(context);
                _fmt(Attribute.clone(Attribute.header, null)); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _applyColor(Color c) {
    final hex = '#${c.value.toRadixString(16).padLeft(8, '0')}';
    _qctrl.formatSelection(ColorAttribute(hex));
    setState(() { _activeColor = c; _showColors = false; });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc     = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent = AppSettings.of(context).accent;
    final bg     = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg, elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: tc),
          onPressed: () async {
            await _save();
            if (mounted) Navigator.pop(context);
          }),
        title: Text(widget.dateLabel, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: tc)),
        centerTitle: true,
        actions: [
          AnimatedOpacity(
            opacity: _saving ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Padding(padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('Сохранение...',
                  style: TextStyle(fontSize: 12,
                      color: tc.withValues(alpha: 0.4)))))),
        ],
      ),
      body: Column(children: [

          // ── Редактор + плавающие фото ──────────────
          Expanded(child: Stack(children: [
            // Тап на редактор снимает выделение фото
            Positioned.fill(child: GestureDetector(
              onTap: () => setState(() => _selectedPath = null),
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            )),
            // Quill Editor
            Positioned.fill(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: QuillEditor(
                controller: _qctrl,
                scrollController: _scrollCtrl,
                focusNode: _focusNode,
                config: const QuillEditorConfig(
                  placeholder: 'Запиши как прошёл день...',
                  padding: EdgeInsets.only(top: 8),
                ),
              ),
            )),

            // Плавающие фото поверх текста
            ..._floats.map((f) => _FloatWidget(
              key: ValueKey(f.path),
              photo: f,
              selected: _selectedPath == f.path,
              accent: accent,
              onTap: () => setState(() =>
                  _selectedPath = _selectedPath == f.path ? null : f.path),
              onMove: (dx, dy) {
                setState(() { f.x += dx; f.y += dy; });
              },
              onMoveEnd: _onChange,
              onResize: (dw) {
                setState(() {
                  f.w = (f.w + dw).clamp(60.0,
                      MediaQuery.of(context).size.width - 32);
                });
              },
              onResizeEnd: _onChange,
              onDelete: () {
                setState(() {
                  _floats.remove(f);
                  _selectedPath = null;
                });
                _onChange();
              },
            )),
          ])),

          // Цвета
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: _showColors ? Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: _colors.map((c) => GestureDetector(
                onTap: () => _applyColor(c),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 34, height: 34,
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                    border: Border.all(
                      color: c == _activeColor ? accent : Colors.transparent,
                      width: 2.5)),
                ),
              )).toList()),
            ) : const SizedBox.shrink(),
          ),

          // Разделитель
          Divider(height: 1, thickness: 0.5,
              color: tc.withValues(alpha: 0.1)),

          // Toolbar
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(top: false, child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(children: [
                _tTxt(_sizeLabel, _sizeLabel != 'Аа', accent, tc,
                    () => _showSizeSheet(accent, tc, bg)),
                _div(isDark),
                _tBtn(Icons.format_bold,          _isBold,   accent, tc, () => _fmt(Attribute.bold)),
                _tBtn(Icons.format_italic,        _isItalic, accent, tc, () => _fmt(Attribute.italic)),
                _tBtn(Icons.format_underline,     _isUnder,  accent, tc, () => _fmt(Attribute.underline)),
                _tBtn(Icons.format_strikethrough, _isStrike, accent, tc, () => _fmt(Attribute.strikeThrough)),
                _tBtn(Icons.format_list_bulleted, _isBullet, accent, tc, () =>
                  _fmt(_isBullet ? Attribute.clone(Attribute.list, null) : Attribute.ul)),
                _div(isDark),
                GestureDetector(
                  onTap: () => setState(() => _showColors = !_showColors),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 48, height: 44,
                    decoration: BoxDecoration(
                      color: _showColors
                          ? accent.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.format_color_text, size: 22,
                            color: tc.withValues(alpha: 0.65)),
                        Container(height: 3, width: 22,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(color: _activeColor,
                                borderRadius: BorderRadius.circular(2))),
                      ]),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _addPhoto,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          size: 20, color: Colors.black),
                      const SizedBox(width: 6),
                      const Text('Добавить фото', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.black)),
                    ]),
                  ),
                ),
                const SizedBox(width: 4),
              ]),
            )),
          ),
        ]),
    );
  }
}

// ─── Плавающий виджет фото ────────────────────────────
class _FloatWidget extends StatefulWidget {
  final _FloatPhoto photo;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final void Function(double dx, double dy) onMove;
  final VoidCallback onMoveEnd;
  final void Function(double dw) onResize;
  final VoidCallback onResizeEnd;
  final VoidCallback onDelete;

  const _FloatWidget({super.key,
    required this.photo, required this.selected, required this.accent,
    required this.onTap, required this.onMove, required this.onMoveEnd,
    required this.onResize, required this.onResizeEnd, required this.onDelete});

  @override
  State<_FloatWidget> createState() => _FloatWidgetState();
}

class _FloatWidgetState extends State<_FloatWidget> {

  double _moveStartX = 0, _moveStartY = 0;
  double _resizeStartX = 0, _resizeStartY = 0;
  double _resizeStartW = 0;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.photo;
    final file = File(f.path);
    // Сохраняем пропорции
    double? aspectRatio;
    if (file.existsSync()) {
      // Используем виджет для получения пропорций — пока просто рисуем
    }

    return Positioned(
      left: f.x, top: f.y,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: f.w,
          child: Stack(clipBehavior: Clip.none, children: [
            // Фото
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: file.existsSync()
                  ? Image.file(file, width: f.w, fit: BoxFit.cover)
                  : Container(width: f.w, height: 100,
                      color: Colors.grey.shade800,
                      child: const Icon(Icons.broken_image_outlined,
                          color: Colors.white38)),
            ),

            // Обводка при выборе
            if (widget.selected)
              Positioned.fill(child: IgnorePointer(child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.accent, width: 2)),
              ))),

            // ── Ручка перемещения — левый верхний угол ──
            if (widget.selected)
              Positioned(top: -14, left: -14,
                child: GestureDetector(
                  onPanStart: (d) {
                    _moveStartX = d.globalPosition.dx - f.x;
                    _moveStartY = d.globalPosition.dy - f.y;
                    setState(() => _isDragging = true);
                    HapticFeedback.mediumImpact();
                    FocusScope.of(context).unfocus();
                  },
                  onPanUpdate: (d) {
                    final nx = d.globalPosition.dx - _moveStartX;
                    final ny = d.globalPosition.dy - _moveStartY;
                    widget.onMove(nx - f.x, ny - f.y);
                  },
                  onPanEnd: (_) {
                    setState(() => _isDragging = false);
                    widget.onMoveEnd();
                  },
                  child: _Handle(
                    icon: Icons.open_with_rounded,
                    color: widget.accent,
                    active: _isDragging,
                    size: 32,
                  ),
                ),
              ),

            // ── Крестик удаления — правый верхний угол ──
            if (widget.selected)
              Positioned(top: -14, right: -14,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: _Handle(
                    icon: Icons.close,
                    color: Colors.red,
                    iconColor: Colors.white,
                    active: false,
                    size: 32,
                  ),
                ),
              ),

            // ── Ручка ресайза — правый нижний угол ──
            if (widget.selected)
              Positioned(right: -14, bottom: -14,
                child: GestureDetector(
                  onPanStart: (d) {
                    _resizeStartX = d.globalPosition.dx;
                    _resizeStartY = d.globalPosition.dy;
                    _resizeStartW = f.w;
                    setState(() => _isDragging = true);
                    HapticFeedback.mediumImpact();
                    FocusScope.of(context).unfocus();
                  },
                  onPanUpdate: (d) {
                    final dx = d.globalPosition.dx - _resizeStartX;
                    final dy = d.globalPosition.dy - _resizeStartY;
                    final delta = dx.abs() > dy.abs() ? dx : dy;
                    widget.onResize(_resizeStartW + delta - f.w);
                  },
                  onPanEnd: (_) {
                    setState(() => _isDragging = false);
                    widget.onResizeEnd();
                  },
                  child: _Handle(
                    icon: Icons.open_in_full,
                    color: widget.accent,
                    active: _isDragging,
                    size: 32,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}


// ─── Кнопка-ручка с визуальным откликом ──────────────
class _Handle extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final bool active;
  final double size;

  const _Handle({
    required this.icon,
    required this.color,
    this.iconColor = Colors.black,
    required this.active,
    required this.size,
  });

  @override
  State<_Handle> createState() => _HandleState();
}

class _HandleState extends State<_Handle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 1.3).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_Handle old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _ctrl.forward();
    if (!widget.active && old.active) _ctrl.reverse();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Container(
      width: widget.size, height: widget.size,
      decoration: BoxDecoration(
        color: widget.active
            ? widget.color.withValues(alpha: 0.85)
            : widget.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(
          color: widget.color.withValues(
              alpha: widget.active ? 0.7 : 0.4),
          blurRadius: widget.active ? 12 : 6,
          spreadRadius: widget.active ? 2 : 0)]),
      child: Icon(widget.icon,
          color: widget.iconColor,
          size: widget.size * 0.48),
    ),
  );
}

// ─── Утилиты ──────────────────────────────────────────
Widget _handle(Color tc) => Center(child: Container(
  width: 36, height: 4,
  decoration: BoxDecoration(color: tc.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(2))));

Widget _tBtn(IconData icon, bool active, Color accent, Color tc,
    VoidCallback onTap) => GestureDetector(onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    margin: const EdgeInsets.symmetric(horizontal: 3),
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: active ? accent.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, size: 22,
        color: active ? accent : tc.withValues(alpha: 0.55))));

Widget _tTxt(String label, bool active, Color accent, Color tc,
    VoidCallback onTap) => GestureDetector(onTap: onTap,
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    margin: const EdgeInsets.symmetric(horizontal: 3),
    height: 44, padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: active ? accent.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(10)),
    child: Center(child: Text(label, style: TextStyle(fontSize: 14,
        fontWeight: FontWeight.w700,
        color: active ? accent : tc.withValues(alpha: 0.55))))));

Widget _div(bool isDark) => Container(
  width: 1, height: 26,
  margin: const EdgeInsets.symmetric(horizontal: 6),
  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1));

Widget _szRow(String label, double sz, FontWeight w, bool cur,
    Color accent, Color tc, {required VoidCallback onTap}) =>
  GestureDetector(onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cur ? accent.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cur ? accent.withValues(alpha: 0.35) : Colors.transparent,
          width: 1.5)),
      child: Row(children: [
        Text(label, style: TextStyle(fontSize: sz, fontWeight: w,
            color: cur ? accent : tc)),
        const Spacer(),
        if (cur) Icon(Icons.check_rounded, color: accent, size: 20),
      ])));
