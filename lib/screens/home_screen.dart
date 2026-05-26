// ════════════════════════════════════════════════════
// screens/home_screen.dart — точка сборки приложения
// Содержит: HomeScreen (стейт + навигация), BottomNav
// Вкладка 0 и все карточки → widgets/home_tab.dart
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../app.dart';
import '../models/day_data.dart';
import '../logic/daily_logic.dart';
import '../utils/ui_helpers.dart';
import '../utils/date_labels.dart';
import '../services/widget_sync.dart';
import '../widgets/home_tab.dart';
import '../widgets/streak_fire_overlay.dart';
import 'question_screen.dart';
import 'planner_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'onboarding_screen.dart';
import 'day_complete_screen.dart';
import '../services/notifications.dart' as notif;
import '../services/analytics.dart';
import '../services/streak_freeze.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import 'weekly_review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _navIndex = 0;
  int _streak = 0;
  DateTime _selectedDate = DateTime.now();
  Map<String, DayData> _diary = {};
  Map<String, List<Map<String, dynamic>>> _allPlans = {};
  String _goal = '';
  String _goalCategory = 'money';
  String _userName = '';
  int _streakRecord = 0;
  bool _loading = true;
  bool _showOnboarding = false;
  bool _showSplash = false;

  SharedPreferences? _prefs;
  OverlayEntry? _splashEntry;

  final _headerKey  = GlobalKey();
  final _dateKey    = GlobalKey();
  final _cardKey    = GlobalKey();
  final _navKey     = GlobalKey();
  final _statsKey   = GlobalKey();
  final _plannerKey = GlobalKey();

  static const _widgetChannel =
      MethodChannel('ru.modo.app/widget');

  @override
  void initState() {
    super.initState();
    _load();
    _checkWidgetTap();
    WidgetsBinding.instance.addObserver(this);
    // Синхронизация обрабатывается в PlannerScreen напрямую.
    // HomeScreen обновляется через didChangeAppLifecycleState.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncFromWidget();
  }

  Future<void> _syncFromWidget() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final merged = await widgetPull(prefs, current: _allPlans);
    if (merged != null && mounted) setState(() => _allPlans = merged);
    try { await _widgetChannel.invokeMethod('updateWidget'); } catch (_) {}
  }

  Future<void> _checkWidgetTap() async {
    try {
      final open = await _widgetChannel.invokeMethod<bool>('checkOpenPlanner') ?? false;
      final add  = await _widgetChannel.invokeMethod<bool>('checkAddPlan') ?? false;
      if ((open || add) && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _navIndex = 2);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final mergedPlans = await widgetPull(prefs, current: _allPlans) ?? _decodePlansFromPrefs(prefs);

    // FIX: загружаем дневник ДО расчёта стрика и применения freeze,
    // иначе _calcStreak видит старые данные без учёта freeze-флага.
    _diary = DayData.loadFromPrefs(prefs);

    // Применяем freeze ПЕРЕД расчётом стрика — сохраняет флаг в prefs,
    // который _calcStreak использует чтобы не обнулить стрик при пропуске.
    await _applyFreezeIfNeeded();

    setState(() {
      _allPlans     = mergedPlans;
      _streak       = _calcStreak();
      _streakRecord = _calcStreakRecord();
      _goal         = prefs.getString('goal') ?? '';
      _goalCategory = prefs.getString('goalCategory') ?? 'money';
      _userName     = prefs.getString('userName') ?? '';
      final splashSeen  = prefs.getBool('splashSeen') ?? false;
      _showOnboarding   = _goal.isEmpty;
      _showSplash       = _goal.isNotEmpty && !splashSeen;
      _loading          = false;
    });

    if (_showSplash) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSplashOverlay());
    } else {
      // Проверяем нужен ли Weekly Review (воскресенье + ещё не показан сегодня)
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowWeeklyReview());
    }
  }

  // ── Weekly Review ───────────────────────────────────────────
  Future<void> _maybeShowWeeklyReview() async {
    if (!mounted) return;
    final now = DateTime.now();
    if (now.weekday != DateTime.sunday) return; // только воскресенье

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final shownKey = 'weekly_review_shown_$todayKey';
    if (prefs.getBool(shownKey) ?? false) return; // уже показали сегодня
    await prefs.setBool(shownKey, true);

    // Данные за последние 7 дней
    final weekRatings = _getWeekRatings(7);
    final filled = weekRatings.length;

    if (!mounted) return;
    await Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => WeeklyReviewScreen(
        weekRatings: weekRatings,
        streak: _streak,
        daysFilledThisWeek: filled,
        userName: _userName,
      ),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
    ));
  }

  Map<String, Map<String, int>> _getWeekRatings(int days) {
    final result = <String, Map<String, int>>{};
    for (int i = 1; i <= days; i++) {
      final d   = DateTime.now().subtract(Duration(days: i));
      final key = dateKey(d);
      final r   = _diary[key]?.ratings;
      if (r != null && r.isNotEmpty) result[key] = r;
    }
    return result;
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await DayData.saveToPrefs(prefs, _diary);
    await widgetPush(prefs, _allPlans);
  }

  Future<void> _saveGoal(String goal, String category, String name,
      {bool isEdit = false}) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('goal', goal);
    await prefs.setString('goalCategory', category);
    if (name.isNotEmpty) await prefs.setString('userName', name);
    setState(() {
      _goal         = goal;
      _goalCategory = category;
      if (name.isNotEmpty) _userName = name;
      _showOnboarding = false;
      if (!isEdit) _showSplash = true;
    });
    if (!isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showSplashOverlay());
    }
  }

  void _showSplashOverlay() {
    if (!mounted || !_showSplash) return;
    _splashEntry?.remove();
    _splashEntry = null;
    final accent = AppSettings.of(context).accent;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => SplashOnboarding(
        headerKey:  _headerKey,
        dateKey:    _dateKey,
        cardKey:    _cardKey,
        navKey:     _navKey,
        statsKey:   _statsKey,
        plannerKey: _plannerKey,
        accent: accent,
        onSwitchTab: (tab) {
          if (mounted) setState(() => _navIndex = tab);
          _splashEntry?.markNeedsBuild();
        },
        onDone: () {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try { entry.remove(); } catch (_) {}
            _splashEntry = null;
          });
          _prefs?.setBool('splashSeen', true);
          if (mounted) setState(() => _showSplash = false);
        },
        onOpenQuestions: _goToQuestions,
      ),
    );
    _splashEntry = entry;
    Overlay.of(context).insert(entry);
  }

  // FIX: _calcStreak учитывает флаг '_freeze_applied_today', который
  // _applyFreezeIfNeeded() записывает в prefs перед вызовом этого метода.
  // Если freeze закрыл вчерашний пропуск — цепочка не рвётся.
  int _calcStreak() {
    int streak = 0;
    DateTime day = DateTime.now().toLocal();

    if (!_diary.containsKey(dateKey(day))) {
      // Сегодня нет записи — смотрим вчера
      day = day.subtract(const Duration(days: 1));

      if (!_diary.containsKey(dateKey(day))) {
        // Вчера тоже нет — проверяем не закрыл ли freeze этот пропуск
        final freezeApplied =
            _prefs?.getBool('_freeze_applied_today') ?? false;
        final twoDaysAgo = day.subtract(const Duration(days: 1));
        if (freezeApplied && _diary.containsKey(dateKey(twoDaysAgo))) {
          // Freeze покрыл вчерашний день — считаем с позавчера
          day = twoDaysAgo;
        } else {
          return 0;
        }
      }
    }

    while (_diary.containsKey(dateKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // Streak Freeze: проверяем при загрузке есть ли пропуск в 1 день
  // и если да — тратим freeze чтобы сохранить стрик визуально.
  // FIX: вызывается ДО _calcStreak() — записывает флаг который тот читает.
  Future<void> _applyFreezeIfNeeded() async {
    final now        = DateTime.now();
    final today      = dateKey(now);
    final yesterday  = dateKey(now.subtract(const Duration(days: 1)));
    final twoDaysAgo = dateKey(now.subtract(const Duration(days: 2)));

    // Условие: сегодня нет записи, вчера нет, позавчера есть
    // → пропущен ровно 1 день → пробуем freeze
    if (!_diary.containsKey(today) &&
        !_diary.containsKey(yesterday) &&
        _diary.containsKey(twoDaysAgo)) {
      final used = await StreakFreeze.tryApply();
      if (used) {
        // Сохраняем флаг: _calcStreak увидит его и не обнулит стрик
        await _prefs?.setBool('_freeze_applied_today', true);
        Analytics.streakFreezeUsed(streak: _streak);
        if (mounted) setState(() {});
      }
    } else {
      // Стрик не прерван или прерван на >1 день — флаг не нужен
      await _prefs?.remove('_freeze_applied_today');
    }
  }

  int _calcStreakRecord() {
    if (_diary.isEmpty) return 0;
    final days = _diary.keys.toList()..sort();
    int record = 0, current = 1;
    for (int i = 1; i < days.length; i++) {
      final prev = DateTime.parse(days[i - 1]);
      final curr = DateTime.parse(days[i]);
      if (curr.difference(prev).inDays == 1) {
        current++;
      } else {
        if (current > record) record = current;
        current = 1;
      }
    }
    if (current > record) record = current;
    return record;
  }

  /// Средние оценки за последние [days] дней (для Insight карточки).
  Map<String, double> _calcRecentAverages(int days) {
    final result = <String, double>{};
    const metrics = ['energy', 'productivity', 'mood', 'food', 'sleep'];
    for (final m in metrics) {
      final values = <int>[];
      for (int i = 1; i <= days; i++) {
        final d   = DateTime.now().subtract(Duration(days: i));
        final key = dateKey(d);
        final r   = _diary[key]?.ratings;
        if (r != null && r.containsKey(m)) values.add(r[m]!);
      }
      if (values.isNotEmpty) {
        result[m] = values.reduce((a, b) => a + b) / values.length;
      }
    }
    return result;
  }

  // Проверяет достигнут ли milestone впервые.
  // Сохраняет флаг в prefs чтобы не показывать повторно.
  // Работает корректно даже при заполнении задним числом:
  // если стрик перепрыгнул через 7 (стал сразу 8) —
  // milestone всё равно сработает при следующем сохранении.
  Future<bool> _checkAndMarkMilestone(int streak) async {
    final prefs = _prefs;
    if (prefs == null) return false;
    for (final threshold in [7, 30, 100]) {
      if (streak >= threshold &&
          !(prefs.getBool('milestone_$threshold') ?? false)) {
        await prefs.setBool('milestone_$threshold', true);
        Analytics.streakMilestone(days: threshold);
        return true; // показываем milestone
      }
    }
    return false;
  }

  DayData? get _selectedDay => _diary[dateKey(_selectedDate)];

  void _onNavTap(int index) {
    if (index == _navIndex) return;
    hapticLight();
    if (index == 1) Analytics.statsOpened(); // вкладка Статистика
    setState(() => _navIndex = index);
  }

  void _goToQuestions() async {
    final daysDiff = DateTime.now().difference(_selectedDate).inDays;
    if (daysDiff > 3 && !AppSettings.of(context).isPremium) {
      hapticMedium();
      _showPremiumDialog();
      return;
    }
    hapticMedium();
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      PageRouteBuilder<Map<String, dynamic>>(
        pageBuilder: (_, __, ___) => QuestionScreen(
          existing: _selectedDay?.answers,
          questions: getDailyQuestions(_selectedDate,
              // Для уже заполненных дней — используем категорию на момент записи
              category: (_selectedDay?.category.isNotEmpty == true
                  ? _selectedDay!.category : _goalCategory)),
          surveyPack: getDailySurveyPack(_selectedDate,
              category: (_selectedDay?.category.isNotEmpty == true
                  ? _selectedDay!.category : _goalCategory)),
          // FIX БАГ-5: передаём выбранный день для корректного ключа черновика
          selectedDate: _selectedDate,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child),
      ),
    );

    // FIX БАГ-2: проверяем mounted сразу после первого await
    if (!mounted) return;

    if (result != null) {
      setState(() {
        final key      = dateKey(_selectedDate);
        final existing = _diary[key] ?? const DayData();
        final r        = result['ratings'] as Map<String, dynamic>?;
        _diary[key] = existing.copyWith(
          // FIX БАГ-7: безопасный каст вместо прямого as List<String>
          answers: List<String>.from(result['answers'] as List),
          ratings: r == null ? null : {
            'energy':       r['energy']       as int,
            'productivity': r['productivity'] as int,
            'mood':         r['mood']         as int,
            'food':         r['food']         as int,
            'sleep':        r['sleep']        as int,
          },
          // Сохраняем категорию на момент записи — при просмотре вопросы
          // будут показаны из той же категории, даже если пользователь
          // потом сменил категорию профиля
          category: existing.category.isNotEmpty
              ? existing.category  // редактирование — не меняем категорию
              : _goalCategory,     // новая запись — берём текущую
        );
        _streak       = _calcStreak();
        _streakRecord = _calcStreakRecord();
      });
      await _save();
      if (!mounted) return;
      // Analytics: основное действие
      Analytics.daySaved(
        streak: _streak,
        isToday: dateKey(_selectedDate) == dateKey(DateTime.now()),
        hasRatings: (_diary[dateKey(_selectedDate)]?.ratings.isNotEmpty) ?? false,
      );
      // Streak Freeze: начисляем если заработан
      await StreakFreeze.maybeEarn(_streak);
      await notif.scheduleNotifications();
      // ВОЛНА 3: записываем час сохранения для адаптивных нотификаций
      await notif.recordEntryTime();
      if (!mounted) return;
      hapticSuccess();
      // Вычисляем средние за последние 7 дней для Insight карточки
      final recentAverages = _calcRecentAverages(7);
      final savedRatings = _diary[dateKey(_selectedDate)]?.ratings;
      // Проверяем milestone — сохраняем флаг чтобы не показывать повторно
      final isMilestone = await _checkAndMarkMilestone(_streak);
      if (!mounted) return;
      await Navigator.push(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => DayCompleteScreen(
          date: _selectedDate,
          userName: _userName,
          streak: _streak,
          ratings: savedRatings?.isEmpty == true ? null : savedRatings,
          recentAverages: recentAverages,
          isMilestoneReached: isMilestone,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ));
      if (mounted) StreakFireOverlay.show(context, _streak);
    }
  }

  // ПРАВКА 3: paywall-диалог с ценностью вместо блокировки
  void _showPremiumDialog() {
    final accent    = AppSettings.of(context).accent;
    final textColor = Theme.of(context).colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(children: [
          const Text('⭐', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('MODO Premium',
              style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 18, color: textColor)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Редактирование прошлых дней и многое другое:',
                style: TextStyle(fontSize: 14,
                    color: textColor.withValues(alpha: 0.55), height: 1.4)),
            const SizedBox(height: 16),
            _premiumRow(accent, textColor, '✏️',
                'Редактировать любые прошлые дни'),
            const SizedBox(height: 10),
            _premiumRow(accent, textColor, '📈',
                'Расширенная статистика — тренды и паттерны'),
            const SizedBox(height: 10),
            _premiumRow(accent, textColor, '📄',
                'Экспорт дневника в PDF'),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Не сейчас',
                  style: TextStyle(
                      color: textColor.withValues(alpha: 0.4)))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _navIndex = 3);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Попробовать Premium',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _premiumRow(
      Color accent, Color textColor, String emoji, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 15))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(text,
                style: TextStyle(fontSize: 13,
                    color: textColor, height: 1.3)),
          ),
        ),
      ],
    );
  }

  // Вызывается из UserProfileCard после сохранения профиля
  void _editGoal() {
    // Оставляем как no-op — реальное сохранение идёт через onSave в _EditProfileSheet
    // который напрямую пишет в SharedPreferences и вызывает _reloadProfile()
    _reloadProfile();
  }

  Future<void> _reloadProfile() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    setState(() {
      _goal         = prefs.getString('goal')         ?? _goal;
      _goalCategory = prefs.getString('goalCategory') ?? _goalCategory;
      _userName     = prefs.getString('userName')     ?? _userName;
    });
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    await _load();
  }

  PlannerScreen _buildPlannerScreen() {
    // Не кэшируем — каждый раз передаём актуальный _allPlans.
    // PlannerScreen.didUpdateWidget обновит локальную копию если данные изменились.
    return PlannerScreen(
      allPlans: _allPlans,
      onSave: (key, plans) async {
        setState(() => _allPlans[key] = plans);
        await _save();
      },
      onSync: () async {
        // PlannerScreen уже обновил свой стейт напрямую.
        // Здесь просто синхронизируем _allPlans HomeScreen из prefs.
        final prefs = _prefs;
        if (prefs == null) return;
        await prefs.reload();
        final raw = prefs.getString('flutter.plans') ?? prefs.getString('plans') ?? '{}';
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map && mounted) {
            setState(() => _allPlans = decoded.map((k, v) => MapEntry(
              k.toString(),
              (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
            )));
          }
        } catch (_) {}
      },
      onClose: () => setState(() => _navIndex = 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showOnboarding) return OnboardingScreen(onDone: _saveGoal);

    final accent = AppSettings.of(context).accent;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // bottomNavigationBar: Flutter сам вычитает высоту из body.
      // Expanded в HomeTab получает правильную высоту — без костылей.
      bottomNavigationBar: KeyedSubtree(
        key: _navKey,
        child: BottomNav(
          currentIndex: _navIndex,
          accent: accent,
          onTap: _onNavTap,
        ),
      ),
      body: IndexedStack(
        index: _navIndex,
        children: [

          // 0 — Главная
          HomeTab(
            goal: _goal,
            userName: _userName,
            streak: _streak,
            streakRecord: _streakRecord,
            totalDays: _diary.length,
            selectedDate: _selectedDate,
            selectedDay: _selectedDay,
            // При просмотре заполненного дня — используем категорию из записи
            goalCategory: (_diary[dateKey(_selectedDate)]?.category.isNotEmpty == true
                ? _diary[dateKey(_selectedDate)]!.category
                : _goalCategory),
            onEditGoal: _editGoal,
            onDateChanged: (d) => setState(() => _selectedDate = d),
            onOpenQuestions: _goToQuestions,
            headerKey: _headerKey,
            dateKey_: _dateKey,
            cardKey: _cardKey,
            onNoteSaved: (json) async {
              final k = dateKey(_selectedDate);
              setState(() => _diary[k] =
                  (_diary[k] ?? const DayData()).copyWith(noteJson: json));
              await _save();
            },
            onRatingsSaved: (r) async {
              final k = dateKey(_selectedDate);
              setState(() => _diary[k] =
                  (_diary[k] ?? const DayData()).copyWith(ratings: r));
              await _save();
            },
            photoPaths: _diary[dateKey(_selectedDate)]?.photoPaths ?? const [],
            dateKey: dateKey(_selectedDate),
            onPhotosSaved: (paths) async {
              final k = dateKey(_selectedDate);
              setState(() => _diary[k] =
                  (_diary[k] ?? const DayData()).copyWith(photoPaths: paths));
              await _save();
            },
          ),

          // 1 — Статистика
          // FIX: e.value.ratings может быть null (день записан без оценок).
          // Передаём только дни где ratings непустой.
          KeyedSubtree(
            key: _statsKey,
            child: StatsScreen(allRatings: {
              for (final e in _diary.entries)
                if (e.value.ratings.isNotEmpty) e.key: e.value.ratings,
            }),
          ),

          // 2 — Планировщик
          KeyedSubtree(
            key: _plannerKey,
            child: _buildPlannerScreen(),
          ),

          // 3 — Настройки
          SettingsScreen(
            onImported: _reload,
            onNameChanged: (name) => setState(() => _userName = name),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Читаем планы из prefs когда widgetPull вернул null.
// FIX: читаем 'flutter.plans' — тот же ключ что пишет widgetPush
// (_kFlutterKey = 'flutter.plans'). Старый ключ 'plans' как fallback
// для обратной совместимости с данными предыдущих версий.
// ════════════════════════════════════════════════════
Map<String, List<Map<String, dynamic>>> _decodePlansFromPrefs(
    SharedPreferences prefs) {
  final raw = prefs.getString('flutter.plans') ?? prefs.getString('plans') ?? '{}';
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry(
      k.toString(),
      (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    ));
  } catch (_) {
    return {};
  }
}

// ════════════════════════════════════════════════════
// BottomNav — нижняя навигация
// ════════════════════════════════════════════════════
class BottomNav extends StatelessWidget {
  final int currentIndex;
  final Color accent;
  final void Function(int) onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final bottom    = MediaQuery.of(context).padding.bottom;

    const items = [
      (Icons.home_outlined,           Icons.home_rounded,           'Главная'),
      (Icons.bar_chart_outlined,      Icons.bar_chart_rounded,      'Статистика'),
      (Icons.calendar_month_outlined, Icons.calendar_month,         'Планы'),
      (Icons.settings_outlined,       Icons.settings_rounded,       'Настройки'),
    ];

    return Container(
      color: bg,
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: 56,
        child: Row(
          children: List.generate(items.length, (i) {
            final isActive = i == currentIndex;
            final (iconOff, iconOn, label) = items[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        isActive ? iconOn : iconOff,
                        key: ValueKey(isActive),
                        size: 22,
                        color: isActive
                            ? accent
                            : textColor.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isActive
                            ? accent
                            : textColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
