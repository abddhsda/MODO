// ════════════════════════════════════════════════════
// screens/planner_screen.dart — планировщик
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';
import '../utils/ui_helpers.dart';
import '../utils/date_labels.dart';
import '../services/notifications.dart' as notif;
import '../services/widget_sync.dart';

class PlannerScreen extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> allPlans;
  final Future<void> Function(String key, List<Map<String, dynamic>> plans) onSave;
  // ── SYNC: новый callback — вызывается при открытии экрана ───────
  // HomeScreen передаёт сюда widgetPull, чтобы подтянуть изменения
  // виджета в момент когда пользователь переключается на планировщик.
  final Future<void> Function()? onSync;
  final bool openAddOnStart;
  final VoidCallback? onClose;

  const PlannerScreen({
    super.key,
    required this.allPlans,
    required this.onSave,
    this.onSync,
    this.openAddOnStart = false,
    this.onClose,
  });

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with WidgetsBindingObserver {  // ── SYNC: добавляем Observer ──

  DateTime _selectedDate = DateTime.now();
  late Map<String, List<Map<String, dynamic>>> _allPlans;
  late ScrollController _calendarController;

  // GESTURE-FIX: убраны _dateDx/_dateDy/_dateDecided/_minDist/_maxAngle —
  // навигация по датам заменена на стандартный GestureDetector.onHorizontalDragEnd.
  // Это устраняет конфликт с iOS edge-swipe и системными жестами.

  static const _alarmChannel = MethodChannel('ru.modo.app/alarm');

  // FIX БАГ-9: глубокая копия — каждый вложенный список копируется отдельно,
  // чтобы локальные мутации не затрагивали Map в HomeScreen._allPlans.
  static Map<String, List<Map<String, dynamic>>> _deepCopy(
      Map<String, List<Map<String, dynamic>>> source) {
    return source.map(
      (k, v) => MapEntry(k, List<Map<String, dynamic>>.from(v)),
    );
  }


  @override
  void initState() {
    super.initState();
    _allPlans = _deepCopy(widget.allPlans);
    final now = DateTime.now();
    final daysFromEpoch = now.difference(DateTime(now.year - 5)).inDays;
    _calendarController = ScrollController(
        initialScrollOffset: (daysFromEpoch * 60.0) - 150);

    WidgetsBinding.instance.addObserver(this);

    // Подписываемся на мгновенные изменения от виджета напрямую —
    // не через onSync/HomeScreen чтобы избежать проблемы с кэшированием.
    // PlannerScreen сам читает SharedPreferences и обновляет свой стейт.
    setupWidgetSyncListener(() async {
      await _pullFromWidget();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pullFromWidget();
      if (widget.openAddOnStart && mounted) _addPlan();
    });
  }

  @override
  void didUpdateWidget(PlannerScreen old) {
    super.didUpdateWidget(old);
    // Когда HomeScreen пересоздаёт PlannerScreen с новым allPlans
    // (например после reload) — обновляем локальную копию
    if (widget.allPlans != old.allPlans) {
      _allPlans = _deepCopy(widget.allPlans); // FIX БАГ-9
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarController.dispose();
    super.dispose();
  }

  // ── SYNC: при возврате приложения на передний план делаем pull ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _pullFromWidget();
    }
  }

  // Вызывает onSync из HomeScreen, который делает widgetPull и
  // Читаем планы напрямую из SharedPreferences.
  // Обновляем локальный стейт PlannerScreen и уведомляем HomeScreen.
  Future<void> _pullFromWidget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString('flutter.plans') ?? prefs.getString('plans') ?? '{}';
    final currentEncoded = jsonEncode(_allPlans);
    if (currentEncoded == raw) return; // ничего не изменилось
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final merged = decoded.map((k, v) => MapEntry(
        k.toString(),
        (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      ));
      if (mounted) setState(() => _allPlans = Map<String, List<Map<String, dynamic>>>.from(merged));
      // Уведомляем HomeScreen чтобы он тоже обновил _allPlans
      await widget.onSync?.call();
    } catch (e) {
      debugPrint('[PlannerScreen] _pullFromWidget error: $e');
    }
  }

  bool _hasPlans(DateTime d) => (_allPlans[dateKey(d)] ?? []).isNotEmpty;

  Map<String, dynamic> _createPlan(String text, TimeOfDay? time) => {
    'id':   DateTime.now().millisecondsSinceEpoch.toString(),
    'text': text,
    'time': time != null
        ? '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}'
        : null,
    'done': false,
  };

  Map<String, dynamic> _createShoppingItem(String name) => {
    'id':   DateTime.now().millisecondsSinceEpoch.toString(),
    'text': name,
    'time': null,
    'done': false,
    'type': 'shopping',
  };

  void _addPlan() {
    hapticLight();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddPlanSheet(
        accent: AppSettings.of(context).accent,
        onSetAlarm: _setAlarm,
        onSubmit: (text, time) {
          final plan  = _createPlan(text, time);
          final k     = dateKey(_selectedDate);
          final plans = List<Map<String, dynamic>>.from(_allPlans[k] ?? [])
            ..add(plan);
          setState(() => _allPlans[k] = plans);
          widget.onSave(k, plans);  // onSave → HomeScreen._save → widgetPush
          _schedulePlanNotification(plan);
        },
      ),
    );
  }

  void _addShoppingItem() {
    hapticLight();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddShoppingSheet(
        accent: AppSettings.of(context).accent,
        onSubmit: (name) {
          final item  = _createShoppingItem(name);
          final k     = dateKey(DateTime.now());
          final plans = List<Map<String, dynamic>>.from(_allPlans[k] ?? [])
            ..add(item);
          setState(() => _allPlans[k] = plans);
          widget.onSave(k, plans);
        },
      ),
    );
  }

  // ── FIX #7: безопасный парсинг времени ───────────────────────────
  Future<void> _schedulePlanNotification(Map<String, dynamic> plan) async {
    final rawTime = plan['time'];
    if (rawTime == null) return;
    try {
      final parts = (rawTime as String).split(':');
      if (parts.length < 2) return;
      final hour   = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return;
      final scheduled = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        hour, minute,
      );
      await notif.schedulePlanReminder(
          plan['id'] as String, plan['text'] as String, scheduled);
    } on FormatException {
      debugPrint('[PlannerScreen] невалидный формат времени: "${plan['time']}"');
    } catch (e) {
      debugPrint('[PlannerScreen] _schedulePlanNotification error: $e');
    }
  }

  Future<void> _setAlarm(String text, TimeOfDay time) async {
    try {
      await _alarmChannel.invokeMethod('setAlarm', {
        'hour': time.hour, 'minute': time.minute, 'message': text,
      });
    } catch (_) {
      if (mounted) showAppSnack(context, 'Не удалось открыть будильник', isError: true);
    }
  }

  void _toggleDoneById(String key, String planId) {
    final plans = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
    final idx = plans.indexWhere((p) => p['id'] == planId);
    if (idx < 0) return;
    final wasDone = plans[idx]['done'] as bool? ?? false;
    plans[idx] = {...plans[idx], 'done': !wasDone};
    wasDone ? hapticLight() : hapticSuccess();
    setState(() => _allPlans[key] = plans);
    widget.onSave(key, plans);  // → HomeScreen._save → widgetPush
  }

  void _deletePlanById(String key, String planId, {bool isShopping = false}) {
    if (isShopping) {
      _confirmDeleteShopping(key, planId);
      return;
    }
    hapticMedium();
    final plans    = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
    final deleted  = plans.firstWhere((p) => p['id'] == planId,
        orElse: () => <String, dynamic>{});
    final delIndex = plans.indexWhere((p) => p['id'] == planId);
    plans.removeWhere((p) => p['id'] == planId);
    setState(() => _allPlans[key] = plans);
    widget.onSave(key, plans);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('План удалён'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 72),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () {
            if (deleted.isEmpty) return;
            final restored = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
            restored.insert(delIndex.clamp(0, restored.length), deleted);
            setState(() => _allPlans[key] = restored);
            widget.onSave(key, restored);
          },
        ),
      ),
    );
  }

  void _confirmDeleteShopping(String key, String planId) {
    final accent = AppSettings.of(context).accent;
    hapticMedium();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить из покупок?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text('Это действие нельзя отменить.',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final plans = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);
              plans.removeWhere((p) => p['id'] == planId);
              setState(() => _allPlans[key] = plans);
              widget.onSave(key, plans);
              hapticMedium();
            },
            child: Text('Удалить',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _scrollCalendarToSelected() {
    final now = DateTime.now();
    final daysFromEpoch = _selectedDate.difference(DateTime(now.year - 5)).inDays;
    final targetOffset  = (daysFromEpoch * 60.0) - 150;
    _calendarController.animateTo(
      targetOffset.clamp(0.0, _calendarController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildDayContent({
    Key? widgetKey,
    required DateTime date,
    required Color textColor,
    required Color accent,
    double bottomPadding = 0,
  }) {
    final key = dateKey(date);
    final raw = List<Map<String, dynamic>>.from(_allPlans[key] ?? []);

    final shopping = raw.where((p) => (p['type'] as String?) == 'shopping').toList();
    final regular  = raw.where((p) => (p['type'] as String?) != 'shopping').toList()
      ..sort((a, b) {
        final aDone = a['done'] as bool? ?? false;
        final bDone = b['done'] as bool? ?? false;
        return aDone == bDone ? 0 : (aDone ? 1 : -1);
      });

    if (raw.isEmpty) {
      return SizedBox.expand(
        key: widgetKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('Нет планов на этот день',
                style: TextStyle(fontSize: 16,
                    color: textColor.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            Text('Нажми + чтобы добавить',
                style: TextStyle(fontSize: 13,
                    color: textColor.withValues(alpha: 0.3))),
          ],
        ),
      );
    }

    return ListView(
      key: widgetKey,
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      children: [
        if (shopping.isNotEmpty)
          _ShoppingAccordion(
            key: ValueKey('shopping_$key'),
            items: shopping,
            accent: accent,
            textColor: textColor,
            onToggle: (planId) => _toggleDoneById(key, planId),
            onDelete: (planId) => _confirmDeleteShopping(key, planId),
            onAdd: _addShoppingItem,
          ),
        ...regular.map((plan) {
          final done   = plan['done'] as bool? ?? false;
          final planId = plan['id'] as String;
          return _PlanItem(
            key: ValueKey(planId),
            plan: plan,
            done: done,
            isShopping: false,
            accent: accent,
            textColor: textColor,
            onToggle: () => _toggleDoneById(key, planId),
            onDelete: () => _deletePlanById(key, planId),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final now       = DateTime.now();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(children: [
                Text('📋 Календарь',
                    style: TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w900, color: textColor)),
                const Spacer(),
              ]),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 76,
              child: ListView.builder(
                controller: _calendarController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 365 * 10,
                itemBuilder: (_, i) {
                  final date        = DateTime(now.year - 5).add(Duration(days: i));
                  final isSelected  = dateKey(date) == dateKey(_selectedDate);
                  final isTodayItem = dateKey(date) == dateKey(now);
                  final hasPlans    = _hasPlans(date);

                  return GestureDetector(
                    onTap: () {
                      hapticLight();
                      setState(() => _selectedDate = date);
                      _scrollCalendarToSelected();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: isTodayItem
                            ? Border.all(color: const Color(0xFFFFD700), width: 2)
                            : isSelected && !isTodayItem
                                ? Border.all(color: accent, width: 2)
                                : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(weekdayShort[date.weekday - 1],
                              style: TextStyle(fontSize: 10,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : textColor.withValues(alpha: 0.45))),
                          const SizedBox(height: 3),
                          Text('${date.day}',
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : textColor)),
                          Container(
                            width: 4, height: 4,
                            margin: const EdgeInsets.only(top: 3),
                            decoration: BoxDecoration(
                              color: hasPlans
                                  ? (isSelected
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : accent)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              // GESTURE-FIX: стандартный GestureDetector вместо Listener+angle math.
              // onHorizontalDragEnd — Flutter сам определяет горизонтальность жеста
              // и не конфликтует с iOS edge-swipe (системный жест имеет приоритет
              // по протоколу UIGestureRecognizer и никогда не попадёт сюда).
              // velocity-порог 200 px/s отсекает случайные микросдвиги при скролле.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final vx = details.primaryVelocity ?? 0;
                  if (vx.abs() < 200) return; // слишком медленно — игнорируем
                  final goingBack = vx > 0;
                  final next    = _selectedDate.add(const Duration(days: 1));
                  final maxDate = DateTime.now().add(const Duration(days: 365));
                  final newDate = goingBack
                      ? _selectedDate.subtract(const Duration(days: 1))
                      : (next.isBefore(maxDate) ? next : _selectedDate);
                  if (newDate == _selectedDate) return;
                  hapticLight();
                  setState(() => _selectedDate = newDate);
                  _scrollCalendarToSelected();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _buildDayContent(
                    widgetKey: ValueKey(dateKey(_selectedDate)),
                    date: _selectedDate,
                    textColor: textColor,
                    accent: accent,
                    bottomPadding: 80,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _PlannerFab(
        accent: accent,
        onAddTask: _addPlan,
        onAddShopping: _addShoppingItem,
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Остальные виджеты (_PlanItem, _AddPlanSheet,
// _ShoppingAccordion, _ShoppingRow, _AddShoppingSheet,
// _PlannerFab) — без изменений относительно оригинала.
// Приведены полностью ниже.
// ════════════════════════════════════════════════════

class _PlanItem extends StatefulWidget {
  final Map<String, dynamic> plan;
  final bool done;
  final bool isShopping;
  final Color accent;
  final Color textColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _PlanItem({
    super.key,
    required this.plan,
    required this.done,
    required this.isShopping,
    required this.accent,
    required this.textColor,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  State<_PlanItem> createState() => _PlanItemState();
}

class _PlanItemState extends State<_PlanItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double>  _fade;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<Offset>(begin: Offset.zero, end: const Offset(0, 0.25))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInCubic));
    _fade  = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _handleToggle() async {
    if (_animating) return;
    if (!widget.done) {
      setState(() => _animating = true);
      await _ctrl.forward();
      widget.onToggle();
      if (mounted) { _ctrl.reset(); setState(() => _animating = false); }
    } else {
      widget.onToggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan   = widget.plan;
    final done   = widget.done;
    final accent = widget.accent;
    final tc     = widget.textColor;
    final isShop = widget.isShopping;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isShop && !done
            ? Border.all(color: accent.withValues(alpha: 0.3), width: 1)
            : done
                ? Border.all(color: accent.withValues(alpha: 0.15))
                : null,
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _handleToggle,
          child: isShop
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: done ? accent : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.shopping_cart_outlined,
                    size: 14,
                    color: done ? Colors.white : accent,
                  ),
                )
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: done ? accent : Colors.transparent,
                    border: Border.all(
                        color: done ? accent : tc.withValues(alpha: 0.3),
                        width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan['text'] as String,
                  style: TextStyle(
                      fontSize: 15,
                      color: done ? tc.withValues(alpha: 0.35) : tc,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: tc.withValues(alpha: 0.35))),
              if (plan['time'] != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.access_time_rounded,
                      size: 12, color: accent.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(plan['time'] as String,
                      style: TextStyle(fontSize: 12,
                          color: accent.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600)),
                ]),
              ],
            ],
          ),
        ),
        GestureDetector(
          onTap: widget.onDelete,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.delete_outline_rounded,
                size: 20, color: tc.withValues(alpha: 0.25)),
          ),
        ),
      ]),
    );

    if (_animating) {
      return SlideTransition(
          position: _slide,
          child: FadeTransition(opacity: _fade, child: card));
    }
    return card;
  }
}

class _AddPlanSheet extends StatefulWidget {
  final Color accent;
  final Future<void> Function(String text, TimeOfDay time) onSetAlarm;
  final void Function(String text, TimeOfDay? time) onSubmit;

  const _AddPlanSheet({
    required this.accent,
    required this.onSetAlarm,
    required this.onSubmit,
  });

  @override
  State<_AddPlanSheet> createState() => _AddPlanSheetState();
}

class _AddPlanSheetState extends State<_AddPlanSheet> {
  final _ctrl = TextEditingController();
  TimeOfDay? _time;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String? get _timeLabel => _time == null ? null
      : '${_time!.hour.toString().padLeft(2, '0')}:'
        '${_time!.minute.toString().padLeft(2, '0')}';

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    hapticMedium();
    Navigator.pop(context);
    widget.onSubmit(text, _time);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface   = Theme.of(context).colorScheme.surface;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Новый план',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: onSurface)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 16, color: onSurface),
            decoration: InputDecoration(
              hintText: 'Что планируешь?',
              hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.4)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true, fillColor: surface,
              contentPadding: const EdgeInsets.all(14),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              hapticLight();
              final picked = await showTimePicker(
                  context: context, initialTime: TimeOfDay.now());
              if (picked != null) { hapticMedium(); setState(() => _time = picked); }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: surface, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.access_time,
                    color: _time != null
                        ? widget.accent : onSurface.withValues(alpha: 0.4),
                    size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _timeLabel ?? 'Добавить время (необязательно)',
                    style: TextStyle(fontSize: 15,
                        color: _time != null
                            ? onSurface : onSurface.withValues(alpha: 0.4)),
                  ),
                ),
                if (_time != null)
                  GestureDetector(
                    onTap: () { hapticLight(); setState(() => _time = null); },
                    child: Icon(Icons.close, size: 16,
                        color: onSurface.withValues(alpha: 0.4)),
                  ),
              ]),
            ),
          ),
          if (_time != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                final text = _ctrl.text.trim();
                if (text.isNotEmpty) { hapticMedium(); widget.onSetAlarm(text, _time!); }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: surface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.alarm, color: widget.accent, size: 20),
                  const SizedBox(width: 10),
                  Text('Добавить в будильник',
                      style: TextStyle(fontSize: 15,
                          color: widget.accent, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Добавить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingAccordion extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final Color accent;
  final Color textColor;
  final void Function(String planId) onToggle;
  final void Function(String planId) onDelete;
  final VoidCallback onAdd;

  const _ShoppingAccordion({
    super.key,
    required this.items,
    required this.accent,
    required this.textColor,
    required this.onToggle,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  State<_ShoppingAccordion> createState() => _ShoppingAccordionState();
}

class _ShoppingAccordionState extends State<_ShoppingAccordion>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _ctrl;
  late Animation<double> _rotate;
  late Animation<double>  _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _rotate = Tween<double>(begin: 0, end: 0.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    hapticLight();
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final accent    = widget.accent;
    final textColor = widget.textColor;
    final items     = widget.items;
    final doneCount = items.where((e) => e['done'] as bool? ?? false).length;
    final surface   = Theme.of(context).colorScheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(bottom: _expanded ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shopping_cart_outlined, size: 14, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Список покупок',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: textColor)),
              ),
              if (items.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$doneCount/${items.length}',
                      style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: accent)),
                ),
              RotationTransition(
                turns: _rotate,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: textColor.withValues(alpha: 0.4), size: 22),
              ),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border.all(color: accent.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(children: [
                    Divider(height: 1, color: accent.withValues(alpha: 0.1)),
                    ...items.map((item) {
                      final done   = item['done'] as bool? ?? false;
                      final planId = item['id'] as String;
                      return _ShoppingRow(
                        key: ValueKey(planId),
                        text: item['text'] as String,
                        done: done,
                        accent: accent,
                        textColor: textColor,
                        onToggle: () => widget.onToggle(planId),
                        onDelete: () => widget.onDelete(planId),
                      );
                    }),
                    GestureDetector(
                      onTap: widget.onAdd,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(children: [
                          Icon(Icons.add_circle_outline,
                              size: 18, color: accent.withValues(alpha: 0.6)),
                          const SizedBox(width: 10),
                          Text('Добавить позицию',
                              style: TextStyle(fontSize: 14,
                                  color: accent.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                    ),
                  ]),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  final String text;
  final bool done;
  final Color accent;
  final Color textColor;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ShoppingRow({
    super.key,
    required this.text,
    required this.done,
    required this.accent,
    required this.textColor,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        GestureDetector(
          onTap: () { hapticLight(); onToggle(); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: done ? accent : Colors.transparent,
              border: Border.all(
                  color: done ? accent : textColor.withValues(alpha: 0.25),
                  width: 1.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: done ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 15,
                  color: done ? textColor.withValues(alpha: 0.35) : textColor,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: textColor.withValues(alpha: 0.35))),
        ),
        GestureDetector(
          onTap: onDelete,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.delete_outline_rounded,
                size: 18, color: textColor.withValues(alpha: 0.2)),
          ),
        ),
      ]),
    );
  }
}

class _AddShoppingSheet extends StatefulWidget {
  final Color accent;
  final void Function(String name) onSubmit;

  const _AddShoppingSheet({required this.accent, required this.onSubmit});

  @override
  State<_AddShoppingSheet> createState() => _AddShoppingSheetState();
}

class _AddShoppingSheetState extends State<_AddShoppingSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _submit() {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    hapticMedium();
    Navigator.pop(context);
    widget.onSubmit(name);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface   = Theme.of(context).colorScheme.surface;

    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.shopping_cart_outlined, color: widget.accent, size: 22),
            const SizedBox(width: 10),
            Text('Добавить в покупки',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: onSurface)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 16, color: onSurface),
            decoration: InputDecoration(
              hintText: 'Что купить?',
              hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.4)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              filled: true, fillColor: surface,
              contentPadding: const EdgeInsets.all(14),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Добавить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerFab extends StatefulWidget {
  final Color accent;
  final VoidCallback onAddTask;
  final VoidCallback onAddShopping;

  const _PlannerFab({
    required this.accent,
    required this.onAddTask,
    required this.onAddShopping,
  });

  @override
  State<_PlannerFab> createState() => _PlannerFabState();
}

class _PlannerFabState extends State<_PlannerFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _showMenu() {
    hapticMedium();
    _ctrl.forward();
    final box  = context.findRenderObject() as RenderBox;
    final pos  = box.localToGlobal(Offset.zero);
    final size = box.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx - 160, pos.dy - 100,
        pos.dx + size.width, pos.dy + size.height,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).scaffoldBackgroundColor,
      items: [
        PopupMenuItem(
          value: 'task',
          child: Row(children: [
            Icon(Icons.check_box_outline_blank_rounded, color: widget.accent, size: 20),
            const SizedBox(width: 12),
            const Text('Задача', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'shopping',
          child: Row(children: [
            Icon(Icons.shopping_cart_outlined, color: widget.accent, size: 20),
            const SizedBox(width: 12),
            const Text('В список покупок', style: TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    ).then((val) {
      _ctrl.reverse();
      if (!mounted) return;
      if (val == 'task')     widget.onAddTask();
      if (val == 'shopping') widget.onAddShopping();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: widget.onAddTask,
        onLongPress: _showMenu,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: widget.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

