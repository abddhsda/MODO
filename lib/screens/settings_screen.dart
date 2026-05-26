// ════════════════════════════════════════════════════
// screens/settings_screen.dart — настройки
// Без стрелки назад — навигация через bottom nav
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';
import '../constants/colors.dart';
import '../utils/ui_helpers.dart';
import '../services/export_service.dart';
import '../services/notifications.dart' as notif;
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import '../widgets/subscription_badge.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

class SettingsScreen extends StatelessWidget {
  final Future<void> Function()? onImported;
  final void Function(String)? onNameChanged; // колбэк → HomeScreen обновит _userName

  const SettingsScreen({super.key, this.onImported, this.onNameChanged});

  @override
  Widget build(BuildContext context) {
    final settings  = AppSettings.of(context);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚙️ Настройки',
                    style: TextStyle(fontSize: 24,
                        fontWeight: FontWeight.w900, color: textColor)),

                const SizedBox(height: 32),

                // ── Профиль ───────────────────────────────────
                _sectionLabel('Профиль', textColor),
                const SizedBox(height: 12),
                _ProfileRow(
                  textColor: textColor,
                  onNameChanged: onNameChanged,
                ),

                const SizedBox(height: 32),
                _sectionLabel('Тема', textColor),
                const SizedBox(height: 12),
                _ThemeToggle(themeMode: settings.themeMode, settings: settings),

                const SizedBox(height: 32),

                // ── Акцентный цвет ────────────────────────────
                _sectionLabel('Акцентный цвет', textColor),
                const SizedBox(height: 12),
                ...List.generate(AppColors.accents.length, (i) {
                  final isLast = i == AppColors.accents.length - 1;
                  final locked = !SubscriptionService.instance.canUseAccentAt(i);
                  return _AccentRow(
                    color: AppColors.accents[i],
                    name: AppColors.accentNames[i],
                    isSelected: settings.accent == AppColors.accents[i],
                    isLastItem: isLast,
                    isLocked: locked,
                    onTap: () async {
                      if (locked) {
                        await PaywallScreen.show(context,
                            reason: PaywallReason.accentLocked);
                        return;
                      }
                      hapticLight();
                      settings.setAccent(AppColors.accents[i]);
                    },
                  );
                }),

                const SizedBox(height: 32),

                // ── Подписка ──────────────────────────────────────
                _sectionLabel('Подписка', textColor),
                const SizedBox(height: 12),
                SubscriptionBadge(
                  onUpgraded: () {},
                ),
                const SizedBox(height: 32),

                // ── Premium ───────────────────────────────────

                // ── Экспорт ───────────────────────────────────
                _sectionLabel('Экспорт и импорт', textColor),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    _actionItem(
                      context: context,
                      icon: Icons.description_outlined,
                      label: 'Экспорт в TXT',
                      sublabel: 'Читаемый дневник',
                      textColor: textColor,
                      onTap: () async {
                        hapticLight();
                        if (!SubscriptionService.instance.canExport) {
                          await PaywallScreen.show(context, reason: PaywallReason.exportBlocked);
                          return;
                        }
                        ExportService.exportTxt(context);
                      },
                    ),
                    Divider(height: 1, indent: 56, color: textColor.withValues(alpha: 0.1)),
                    _actionItem(
                      context: context,
                      icon: Icons.table_chart_outlined,
                      label: 'Экспорт в CSV',
                      sublabel: 'Таблица для Excel / Sheets',
                      textColor: textColor,
                      onTap: () async {
                        hapticLight();
                        if (!SubscriptionService.instance.canExport) {
                          await PaywallScreen.show(context, reason: PaywallReason.exportBlocked);
                          return;
                        }
                        ExportService.exportCsv(context);
                      },
                    ),
                    Divider(height: 1, indent: 56, color: textColor.withValues(alpha: 0.1)),
                    _actionItem(
                      context: context,
                      icon: Icons.backup_outlined,
                      label: 'Резервная копия JSON',
                      sublabel: 'Полный бэкап всех данных',
                      textColor: textColor,
                      onTap: () async {
                        hapticLight();
                        if (!SubscriptionService.instance.canExport) {
                          await PaywallScreen.show(context, reason: PaywallReason.exportBlocked);
                          return;
                        }
                        ExportService.exportJson(context);
                      },
                    ),
                    Divider(height: 1, indent: 56, color: textColor.withValues(alpha: 0.1)),
                    _actionItem(
                      context: context,
                      icon: Icons.restore_outlined,
                      label: 'Импорт из JSON',
                      sublabel: 'Восстановить из бэкапа',
                      textColor: textColor,
                      iconColor: Colors.orange,
                      onTap: () { hapticLight(); ExportService.importJson(context, onImported: onImported); },
                    ),
                  ]),
                ),

                const SizedBox(height: 32),

                // ── Уведомления ──────────────────────────────────
                _sectionLabel('Уведомления', textColor),
                const SizedBox(height: 12),
                _NotifTimeSettings(textColor: textColor),

                const SizedBox(height: 32),

                // ── О приложении ──────────────────────────────────
                _sectionLabel('О приложении', textColor),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    _infoItem('📱', 'Версия', '1.0.0', textColor),
                    Divider(height: 1, indent: 56,
                        color: textColor.withValues(alpha: 0.1)),
                    _infoItem('👨‍💻', 'Разработчик', 'Modo Team', textColor),
                    Divider(height: 1, indent: 56,
                        color: textColor.withValues(alpha: 0.1)),
                    _infoItem('🔒', 'Данные', 'Хранятся только на устройстве', textColor),
                  ]),
                ),

                const SizedBox(height: 56), // отступ под навбар

                // ── DEBUG: данные виджета ──────────────────────────
                _sectionLabel('🔧 Debug синхронизации', textColor),
                const SizedBox(height: 12),
                _DebugSyncWidget(textColor: textColor),
                const SizedBox(height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color textColor) => Text(label,
      style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5),
          fontWeight: FontWeight.w600, letterSpacing: 1));

  Widget _actionItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String sublabel,
    required Color textColor,
    required VoidCallback onTap,
    Color? iconColor,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: iconColor ?? textColor.withValues(alpha: 0.7), size: 22),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 16, color: textColor)),
                Text(sublabel, style: TextStyle(fontSize: 12,
                    color: textColor.withValues(alpha: 0.4))),
              ],
            )),
            Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.3)),
          ]),
        ),
      );

  Widget _infoItem(String emoji, String label, String value, Color textColor) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 16, color: textColor)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14,
              color: textColor.withValues(alpha: 0.4))),
        ]),
      );

  Widget _futureItem(BuildContext context, IconData icon, String label, Color textColor) =>
      GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$label — скоро будет доступно'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: textColor.withValues(alpha: 0.4), size: 22),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.4))),
            const Spacer(),
            // Иконка «скоро» вместо шеврона — не намекает на навигацию
            Icon(Icons.access_time_rounded, size: 16, color: textColor.withValues(alpha: 0.2)),
          ]),
        ),
      );
}

class _ThemeToggle extends StatelessWidget {
  final ThemeMode themeMode;
  final AppSettings settings;
  const _ThemeToggle({required this.themeMode, required this.settings});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    Widget btn(String label, ThemeMode mode) {
      final isActive = themeMode == mode;
      return Expanded(child: GestureDetector(
        onTap: () { hapticLight(); settings.setTheme(mode); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? settings.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(child: Text(label,
              style: TextStyle(fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : textColor))),
        ),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        btn('☀️ Светлая', ThemeMode.light),
        btn('🌙 Тёмная',  ThemeMode.dark),
      ]),
    );
  }
}

class _AccentRow extends StatelessWidget {
  final Color color;
  final String name;
  final bool isSelected;
  final bool isLastItem;
  final bool isLocked;
  final VoidCallback onTap;
  const _AccentRow({required this.color, required this.name,
      required this.isSelected, required this.onTap,
      this.isLastItem = false, this.isLocked = false});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isLocked ? 0.45 : 1.0,
        child: Container(
          margin: EdgeInsets.only(bottom: isLastItem ? 0 : 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: color, width: 2) : null,
          ),
          child: Row(children: [
            Container(width: 24, height: 24,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 16),
            Text(name, style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w600, color: textColor)),
            const Spacer(),
            if (isLocked) const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey),
            if (isSelected && !isLocked) Icon(Icons.check_circle, color: color),
          ]),
        ),
      ),
    );
  }
}

// ── Профиль: строка с текущим именем и кнопкой редактирования ──
class _ProfileRow extends StatefulWidget {
  final Color textColor;
  final void Function(String)? onNameChanged;
  const _ProfileRow({required this.textColor, this.onNameChanged});

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _name = prefs.getString('userName') ?? '');
  }

  Future<void> _editName() async {
    final accent = AppSettings.of(context).accent;
    final controller = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text('Твоё имя',
            style: TextStyle(fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Введи имя...',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: accent, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', result);
      if (mounted) setState(() => _name = result);
      widget.onNameChanged?.call(result);
      hapticLight();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc     = widget.textColor;
    final accent = AppSettings.of(context).accent;
    return GestureDetector(
      onTap: _editName,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: accent),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name.isNotEmpty ? _name : 'Не указано',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                      color: _name.isNotEmpty ? tc : tc.withValues(alpha: 0.4))),
              Text('Нажми чтобы изменить',
                  style: TextStyle(fontSize: 12, color: tc.withValues(alpha: 0.35))),
            ]),
          ),
          Icon(Icons.edit_outlined, size: 18, color: tc.withValues(alpha: 0.35)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// _NotifTimeSettings — настройка времени уведомлений
// TimePicker для утреннего и вечернего времени.
// Сохраняет в SharedPreferences, вызывает forceReschedule.
// ════════════════════════════════════════════════════
class _NotifTimeSettings extends StatefulWidget {
  final Color textColor;
  const _NotifTimeSettings({required this.textColor});

  @override
  State<_NotifTimeSettings> createState() => _NotifTimeSettingsState();
}

class _NotifTimeSettingsState extends State<_NotifTimeSettings> {
  TimeOfDay _morning = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _evening = const TimeOfDay(hour: 20, minute: 0);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _morning = TimeOfDay(
        hour:   prefs.getInt('notif_morning_hour')   ?? 8,
        minute: prefs.getInt('notif_morning_minute') ?? 30,
      );
      _evening = TimeOfDay(
        hour:   prefs.getInt('notif_evening_hour')   ?? 20,
        minute: prefs.getInt('notif_evening_minute') ?? 0,
      );
      _loaded = true;
    });
  }

  Future<void> _pickTime(bool isMorning) async {
    final initial = isMorning ? _morning : _evening;
    final picked  = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isMorning ? 'Утреннее напоминание' : 'Вечернее напоминание',
    );
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (isMorning) {
      await prefs.setInt('notif_morning_hour',   picked.hour);
      await prefs.setInt('notif_morning_minute', picked.minute);
      setState(() => _morning = picked);
    } else {
      await prefs.setInt('notif_evening_hour',   picked.hour);
      await prefs.setInt('notif_evening_minute', picked.minute);
      setState(() => _evening = picked);
    }
    await notif.forceReschedule();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Напоминание обновлено'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  String _fmt(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final tc      = widget.textColor;
    final accent  = AppSettings.of(context).accent;
    final surface = Theme.of(context).colorScheme.surface;

    if (!_loaded) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        _timeRow(
          emoji: '🌅',
          label: 'Утреннее',
          sublabel: 'Напоминание начать день',
          time: _morning,
          tc: tc,
          accent: accent,
          onTap: () => _pickTime(true),
        ),
        Divider(height: 1, indent: 56, color: tc.withValues(alpha: 0.1)),
        _timeRow(
          emoji: '🌙',
          label: 'Вечернее',
          sublabel: 'Напоминание записать день',
          time: _evening,
          tc: tc,
          accent: accent,
          onTap: () => _pickTime(false),
        ),
      ]),
    );
  }

  Widget _timeRow({
    required String emoji,
    required String label,
    required String sublabel,
    required TimeOfDay time,
    required Color tc,
    required Color accent,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 16, color: tc)),
                Text(sublabel, style: TextStyle(fontSize: 12,
                    color: tc.withValues(alpha: 0.4))),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Text(_fmt(time),
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w700, color: accent)),
            ),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════
// Debug виджет — показывает что реально лежит в prefs
// ════════════════════════════════════════════════════
class _DebugSyncWidget extends StatefulWidget {
  final Color textColor;
  const _DebugSyncWidget({required this.textColor});
  @override
  State<_DebugSyncWidget> createState() => _DebugSyncWidgetState();
}

class _DebugSyncWidgetState extends State<_DebugSyncWidget> {
  String _flutterPlans = '...';
  String _plans = '...';
  bool _loading = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final fp = prefs.getString('flutter.plans') ?? '(пусто)';
    final p  = prefs.getString('plans') ?? '(пусто)';

    // Считаем кол-во планов на сегодня
    String countFP = '?', countP = '?';
    try {
      final today = DateTime.now();
      final key = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
      final import_convert = (String s) {
        try {
          final m = (jsonDecode(s) as Map);
          final arr = m[key] as List?;
          return '${arr?.length ?? 0} планов на сегодня';
        } catch(_) { return 'ошибка парсинга'; }
      };
      countFP = import_convert(fp);
      countP  = import_convert(p);
    } catch (_) {}

    setState(() {
      _flutterPlans = countFP;
      _plans = countP;
      _loading = false;
    });
  }

  Future<void> _clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('flutter.plans');
    await prefs.remove('plans');
    await _load();
    if (mounted) showAppSnack(context, 'Планы очищены');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tc = widget.textColor;
    final accent = AppSettings.of(context).accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('flutter.plans:', style: TextStyle(fontSize: 12, color: tc.withValues(alpha: 0.5)))),
            Text(_loading ? '...' : _flutterPlans,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('plans (нативный):', style: TextStyle(fontSize: 12, color: tc.withValues(alpha: 0.5)))),
            Text(_loading ? '...' : _plans,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _plans == _flutterPlans ? Colors.green : Colors.orange)),
          ]),
          const SizedBox(height: 4),
          if (!_loading && _plans != _flutterPlans)
            Text('⚠️ Ключи расходятся!',
                style: TextStyle(fontSize: 12, color: Colors.orange)),
          if (!_loading && _plans == _flutterPlans)
            Text('✓ Ключи совпадают',
                style: TextStyle(fontSize: 12, color: Colors.green)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: _load,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Обновить', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: accent, fontWeight: FontWeight.w600)),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Очистить все планы?'),
                    content: const Text('Это удалит все планы из SharedPreferences. Действие необратимо.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                    ],
                  ));
                if (ok == true) _clear();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Очистить prefs', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            )),
          ]),
        ],
      ),
    );
  }
}
