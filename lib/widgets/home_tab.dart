// ════════════════════════════════════════════════════
// widgets/home_tab.dart
// Вкладка 0 — главная страница.
// Содержит: HomeTab, HomeHeader, DateNavigator,
//           DayCardArea, EmptyCard, FutureCard, StatCard
// ════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import '../app.dart';
import '../models/day_data.dart';
import '../logic/daily_logic.dart';
import '../utils/ui_helpers.dart';
import '../utils/date_labels.dart';
import '../services/streak_freeze.dart';
import '../widgets/entry_card.dart';
import '../screens/diary_editor_screen.dart';
import '../services/photo_service.dart';
import '../services/photo_service.dart';
import '../widgets/xp_progress_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════
// HomeTab — вкладка 0
// ════════════════════════════════════════════════════
class HomeTab extends StatelessWidget {
  final String goal;
  final String userName;
  final int streak;
  final int streakRecord;
  final int totalDays;
  final DateTime selectedDate;
  final DayData? selectedDay;
  final String goalCategory;
  final VoidCallback onEditGoal;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onOpenQuestions;
  final Future<void> Function(String) onNoteSaved;
  final Future<void> Function(Map<String, int>) onRatingsSaved;
  final GlobalKey? headerKey;
  final GlobalKey? dateKey_;
  final GlobalKey? cardKey;
  final List<String> photoPaths;
  final String dateKey;
  final Future<void> Function(List<String>) onPhotosSaved;

  const HomeTab({
    super.key,
    required this.goal,
    required this.userName,
    required this.streak,
    required this.streakRecord,
    required this.totalDays,
    required this.selectedDate,
    required this.selectedDay,
    required this.goalCategory,
    required this.onEditGoal,
    required this.onDateChanged,
    required this.onOpenQuestions,
    required this.onNoteSaved,
    required this.onRatingsSaved,
    this.headerKey,
    this.dateKey_,
    this.cardKey,
    required this.photoPaths,
    required this.dateKey,
    required this.onPhotosSaved,
  });

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final isToday   = _isToday(selectedDate);
    final isFuture  = isFutureDate(selectedDate);

    // Высота навбара: 56px фиксированные + системный отступ снизу
    final navBottom = 56.0 + MediaQuery.of(context).padding.bottom;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.only(bottom: navBottom + 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Шапка ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyedSubtree(
                    key: headerKey,
                    child: UserProfileCard(
                      userName: userName,
                      goal: goal,
                      goalCategory: goalCategory,
                      streak: streak,
                      streakRecord: streakRecord,
                      totalDays: totalDays,
                      accent: accent,
                      textColor: textColor,
                      onEditGoal: onEditGoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const XPProgressBar(),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: dateKey_,
                    child: DateNavigator(
                      selectedDate: selectedDate,
                      hasEntry: selectedDay != null,
                      accent: accent,
                      onChanged: onDateChanged,
                    ),
                  ),
                ],
              ),
            ),

            // ── Карточка — минимум на весь оставшийся экран ──
            LayoutBuilder(
              builder: (context, constraints) {
                final navBottom = 56.0 + MediaQuery.of(context).padding.bottom;
                final screenH = MediaQuery.of(context).size.height;
                final headerH = 24 + 24 + 56 + 24 + 52 + 16.0; // приблиз. высота шапки
                final minH = screenH - headerH - navBottom - 32;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minH),
                    child: KeyedSubtree(
                      key: cardKey,
                      child: DayCardArea(
                  selectedDate: selectedDate,
                  selectedDay: selectedDay,
                  goalCategory: goalCategory,
                  isToday: isToday,
                  isFuture: isFuture,
                  streak: streak,
                  onOpenQuestions: onOpenQuestions,
                  onDateChanged: onDateChanged,
                  onNoteSaved: onNoteSaved,
                  onRatingsSaved: onRatingsSaved,
                  photoPaths: photoPaths,
                  dateKey: dateKey,
                  onPhotosSaved: onPhotosSaved,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


// ── Показать стрик-инфо ──────────────────────────────────────
void _showStreakInfo(
  BuildContext context, {
  required int streak,
  required int streakRecord,
  required int totalDays,
  required Color accent,
  required Color textColor,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;
  final tc     = isDark ? Colors.white : const Color(0xFF1A1A1A);

  showModalBottomSheet(
    context: context,
    backgroundColor: bg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: tc.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),
          Text('🔥 Стрик', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: tc)),
          const SizedBox(height: 20),
          Row(children: [
            StatCard(emoji: '🔥', label: 'Текущий', value: '$streak дн.',
                color: accent, bg: accent.withValues(alpha: 0.1)),
            const SizedBox(width: 12),
            StatCard(emoji: '🏆', label: 'Рекорд', value: '$streakRecord дн.',
                color: const Color(0xFFFFD700),
                bg: const Color(0xFFFFD700).withValues(alpha: 0.1)),
            const SizedBox(width: 12),
            StatCard(emoji: '📅', label: 'Всего дней', value: '$totalDays дн.',
                color: Colors.blueGrey,
                bg: Colors.blueGrey.withValues(alpha: 0.1)),
          ]),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════
// UserProfileCard — карточка профиля вместо приветствия
// По нажатию открывает sheet редактирования имени и цели
// ════════════════════════════════════════════════════
class UserProfileCard extends StatelessWidget {
  final String userName;
  final String goal;
  final String goalCategory;
  final int streak;
  final int streakRecord;
  final int totalDays;
  final Color accent;
  final Color textColor;
  final VoidCallback onEditGoal;

  const UserProfileCard({
    super.key,
    required this.userName,
    required this.goal,
    required this.goalCategory,
    required this.streak,
    required this.streakRecord,
    required this.totalDays,
    required this.accent,
    required this.textColor,
    required this.onEditGoal,
  });

  static const _categories = [
    {'emoji': '💰', 'title': 'Деньги и бизнес', 'key': 'money'},
    {'emoji': '💪', 'title': 'Здоровье и спорт', 'key': 'health'},
    {'emoji': '📚', 'title': 'Обучение и рост',  'key': 'learning'},
    {'emoji': '❤️', 'title': 'Отношения',         'key': 'relations'},
    {'emoji': '🎯', 'title': 'Карьера',           'key': 'career'},
    {'emoji': '🧘', 'title': 'Mindset',           'key': 'mindset'},
  ];

  String get _categoryEmoji {
    final cat = _categories.firstWhere(
      (c) => c['key'] == goalCategory,
      orElse: () => _categories[5],
    );
    return cat['emoji'] as String;
  }

  String get _categoryTitle {
    final cat = _categories.firstWhere(
      (c) => c['key'] == goalCategory,
      orElse: () => _categories[5],
    );
    return cat['title'] as String;
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        userName: userName,
        goal: goal,
        goalCategory: goalCategory,
        accent: accent,
        onSave: (newName, newGoal, newCategory) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', newName);
          await prefs.setString('goal', newGoal);
          await prefs.setString('goalCategory', newCategory);
          onEditGoal(); // триггерим rebuild в home_screen
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = userName.trim().isEmpty ? 'Привет' : userName.trim();

    return GestureDetector(
      onTap: () => _showEditSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Аватар-инициал
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Имя + цель
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(_categoryEmoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          goal.isNotEmpty ? goal : _categoryTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.45),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Стрик справа
            GestureDetector(
              onTap: () => _showStreakInfo(
                context,
                streak: streak,
                streakRecord: streakRecord,
                totalDays: totalDays,
                accent: accent,
                textColor: textColor,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      '$streak',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_outlined, size: 16,
                color: textColor.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }
}

// ── Нижний sheet редактирования профиля ──────────────────────
class _EditProfileSheet extends StatefulWidget {
  final String userName;
  final String goal;
  final String goalCategory;
  final Color accent;
  final Future<void> Function(String name, String goal, String category) onSave;

  const _EditProfileSheet({
    required this.userName,
    required this.goal,
    required this.goalCategory,
    required this.accent,
    required this.onSave,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _goalCtrl;
  late String _selectedCategory;
  bool _saving = false;

  static const _categories = [
    {'emoji': '💰', 'title': 'Деньги и бизнес', 'key': 'money'},
    {'emoji': '💪', 'title': 'Здоровье и спорт', 'key': 'health'},
    {'emoji': '📚', 'title': 'Обучение и рост',  'key': 'learning'},
    {'emoji': '❤️', 'title': 'Отношения',         'key': 'relations'},
    {'emoji': '🎯', 'title': 'Карьера',           'key': 'career'},
    {'emoji': '🧘', 'title': 'Mindset',           'key': 'mindset'},
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userName);
    _goalCtrl = TextEditingController(text: widget.goal);
    _selectedCategory = widget.goalCategory.isEmpty ? 'mindset' : widget.goalCategory;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.onSave(
      _nameCtrl.text.trim(),
      _goalCtrl.text.trim(),
      _selectedCategory,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final bg        = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final bottom    = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ручка
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: textColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Профиль',
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w900, color: textColor)),
            const SizedBox(height: 20),

            // Имя
            Text('Имя', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(fontSize: 16, color: textColor),
              decoration: InputDecoration(
                hintText: 'Как тебя зовут?',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
                filled: true,
                fillColor: textColor.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Цель
            Text('Цель', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            TextField(
              controller: _goalCtrl,
              style: TextStyle(fontSize: 16, color: textColor),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Например: пробежать 5 км без остановки',
                hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3)),
                filled: true,
                fillColor: textColor.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Категория
            Text('Категория', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.5))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final key      = cat['key'] as String;
                final selected = key == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? widget.accent.withValues(alpha: 0.15)
                          : textColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? widget.accent.withValues(alpha: 0.5)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat['emoji'] as String,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(cat['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? widget.accent : textColor.withValues(alpha: 0.6),
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // Кнопка сохранить
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accent,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2.5))
                    : const Text('Сохранить',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// HomeHeader — приветствие + стрик
// ════════════════════════════════════════════════════
class HomeHeader extends StatelessWidget {
  final String goal;
  final String userName;
  final int streak;
  final int streakRecord;
  final int totalDays;
  final Color accent;
  final Color textColor;
  final VoidCallback onEditGoal;

  const HomeHeader({
    super.key,
    required this.goal,
    required this.streak,
    required this.userName,
    required this.streakRecord,
    required this.totalDays,
    required this.accent,
    required this.textColor,
    required this.onEditGoal,
  });

  void _showStreakSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final tc     = isDark ? Colors.white : const Color(0xFF1A1A1A);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: tc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('🔥 Стрик', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: tc)),
            const SizedBox(height: 20),
            Row(children: [
              StatCard(
                emoji: '🔥',
                label: 'Текущий',
                value: '$streak дн.',
                color: accent,
                bg: accent.withValues(alpha: 0.1),
              ),
              const SizedBox(width: 12),
              StatCard(
                emoji: '🏆',
                label: 'Рекорд',
                value: '$streakRecord дн.',
                color: const Color(0xFFFFD700),
                bg: const Color(0xFFFFD700).withValues(alpha: 0.1),
              ),
              const SizedBox(width: 12),
              StatCard(
                emoji: '📅',
                label: 'Всего дней',
                value: '$totalDays дн.',
                color: Colors.blueGrey,
                bg: Colors.blueGrey.withValues(alpha: 0.1),
              ),
            ]),

            const SizedBox(height: 12),

            // ── Freeze badge ──────────────────────────────────
            FutureBuilder<int>(
              future: StreakFreeze.getCount(),
              builder: (context, snap) {
                final count = snap.data ?? 0;
                if (count == 0 && streak == 0) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF42A5F5).withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    Text('🧊', style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Заморозка стрика',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF42A5F5)),
                        ),
                        Text(
                          count > 0
                              ? 'В запасе: $count из 2. Защитит стрик при пропуске.'
                              : 'Нет заморозок. Зарабатывается каждые 7 дней стрика.',
                          style: TextStyle(fontSize: 12,
                              color: tc.withValues(alpha: 0.55), height: 1.3),
                        ),
                      ],
                    )),
                    // Пиктограммы льдинок
                    Row(children: List.generate(2, (i) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.ac_unit_rounded,
                          size: 18,
                          color: i < count
                              ? const Color(0xFF42A5F5)
                              : tc.withValues(alpha: 0.15)),
                    ))),
                  ]),
                );
              },
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                streak == 0
                    ? 'Начни сегодня — первый день стрика ждёт 💪'
                    : streak >= streakRecord
                        ? '🎉 Ты бьёшь свой рекорд прямо сейчас!'
                        : 'До рекорда ещё ${streakRecord - streak} дн. Не останавливайся!',
                style: TextStyle(fontSize: 14, color: tc, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            userName.isNotEmpty ? 'Привет, $userName 👋' : 'MODO',
            style: TextStyle(
              fontSize: userName.isNotEmpty ? 20 : 24,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: userName.isNotEmpty ? 0 : 2,
            ),
          ),
          if (goal.isNotEmpty)
          if (goal.isNotEmpty)
            GestureDetector(
              onTap: onEditGoal,
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: accent.withValues(alpha: 0.25), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🎯', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        goal,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ]),
      ),
      GestureDetector(
        onTap: () => _showStreakSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: streak > 0 ? accent : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text('$streak', style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
        ),
      ),
    ],
  );
}

// ════════════════════════════════════════════════════
// StatCard — карточка внутри боттом-шита стрика
// ════════════════════════════════════════════════════
class StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  const StatCard({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = isDark ? Colors.white : const Color(0xFF1A1A1A);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
              fontSize: 11, color: tc.withValues(alpha: 0.5))),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// DateNavigator — навигатор по датам
// ════════════════════════════════════════════════════
class DateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final bool hasEntry;
  final Color accent;
  final ValueChanged<DateTime> onChanged;

  const DateNavigator({
    super.key,
    required this.selectedDate,
    required this.hasEntry,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isToday  = dateKey(selectedDate) == dateKey(DateTime.now());
    final isFuture = isFutureDate(selectedDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            hapticLight();
            onChanged(selectedDate.subtract(const Duration(days: 1)));
          },
          icon: Icon(Icons.chevron_left, size: 32, color: accent),
        ),
        GestureDetector(
          onTap: () async {
            hapticLight();
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2099),
              locale: const Locale('ru'),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.fromSeed(seedColor: accent)),
                child: child!),
            );
            if (picked != null) { hapticMedium(); onChanged(picked); }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isToday
                  ? const Color(0xFFFFD700)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isToday
                  ? [BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                      blurRadius: 12, spreadRadius: 2)]
                  : [],
            ),
            child: Row(children: [
              Icon(Icons.calendar_today, size: 16,
                  color: isToday ? const Color(0xFF1A1A1A) : accent),
              const SizedBox(width: 8),
              Text(
                '${selectedDate.day} '
                '${monthGen[selectedDate.month - 1]} '
                '${selectedDate.year}',
                style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: isToday
                      ? const Color(0xFF1A1A1A)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (hasEntry) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: isToday ? const Color(0xFF1A1A1A) : accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ]),
          ),
        ),
        IconButton(
          onPressed: !isFuture ? () {
            hapticLight();
            onChanged(selectedDate.add(const Duration(days: 1)));
          } : null,
          icon: Icon(Icons.chevron_right, size: 32,
              color: !isFuture ? accent : Colors.grey.shade300),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════
// DayCardArea — область карточки дня со свайпом
// ════════════════════════════════════════════════════
class DayCardArea extends StatefulWidget {
  final DateTime selectedDate;
  final DayData? selectedDay;
  final String goalCategory;
  final bool isToday;
  final bool isFuture;
  final int streak;
  final VoidCallback onOpenQuestions;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function(String) onNoteSaved;
  final Future<void> Function(Map<String, int>) onRatingsSaved;
  final List<String> photoPaths;
  final String dateKey;
  final Future<void> Function(List<String>) onPhotosSaved;

  const DayCardArea({
    super.key,
    required this.selectedDate,
    required this.selectedDay,
    required this.goalCategory,
    required this.isToday,
    required this.isFuture,
    required this.streak,
    required this.onOpenQuestions,
    required this.onDateChanged,
    required this.onNoteSaved,
    required this.onRatingsSaved,
    required this.photoPaths,
    required this.dateKey,
    required this.onPhotosSaved,
  });

  @override
  State<DayCardArea> createState() => _DayCardAreaState();
}

class _DayCardAreaState extends State<DayCardArea> {
  bool _didSwipe        = false;
  bool _metricEditActive = false;
  DateTime _lastSwipe   = DateTime(0);

  double _dx = 0, _dy = 0;
  bool _decided = false;

  static const _cooldown   = Duration(milliseconds: 350);
  static const double _min = 28;

  void _onDown(PointerDownEvent e) {
    _dx = 0; _dy = 0; _decided = false; _didSwipe = false;
  }

  void _onMove(PointerMoveEvent e) {
    if (_decided || _metricEditActive) return;
    _dx += e.delta.dx;
    _dy += e.delta.dy;
    if (_dx.abs() < _min && _dy.abs() < _min) return;
    _decided = true;
    if (_dx.abs() < _dy.abs() * 0.7) return;
    final now = DateTime.now();
    if (now.difference(_lastSwipe) < _cooldown) return;
    _lastSwipe = now;
    _didSwipe  = true;
    if (_dx > 0) {
      hapticLight();
      widget.onDateChanged(widget.selectedDate.subtract(const Duration(days: 1)));
    } else {
      if (!isFutureDate(widget.selectedDate)) {
        final next = widget.selectedDate.add(const Duration(days: 1));
        if (!isFutureDate(next)) { hapticLight(); widget.onDateChanged(next); }
      }
    }
  }

  void _onUp(PointerUpEvent e) {
    Future.delayed(const Duration(milliseconds: 80),
        () { if (mounted) setState(() => _didSwipe = false); });
  }

  @override
  Widget build(BuildContext context) {
    final accent   = AppSettings.of(context).accent;
    final hasEntry = widget.selectedDay != null;

    return Listener(
      onPointerDown:   _onDown,
      onPointerMove:   _onMove,
      onPointerUp:     _onUp,
      onPointerCancel: (_) { _decided = false; _didSwipe = false; },
      child: GestureDetector(
        onTap: (widget.isFuture || _didSwipe || hasEntry) ? null
            : () { hapticMedium(); widget.onOpenQuestions(); },
        child: widget.isFuture
            ? const FutureCard()
            : hasEntry
                ? Column(
                    children: [
                      // ── Верхняя сетка: фото + вопросы ──────────
                      _DayPreviewGrid(
                        selectedDay: widget.selectedDay!,
                        selectedDate: widget.selectedDate,
                        goalCategory: widget.goalCategory,
                        photoPaths: widget.photoPaths,
                        dateKey: widget.dateKey,
                        accent: accent,
                        isToday: widget.isToday,
                        onOpenQuestions: widget.onOpenQuestions,
                        onNoteSaved: widget.onNoteSaved,
                        onPhotosSaved: widget.onPhotosSaved,
                      ),
                      const SizedBox(height: 10),
                      // ── Детали: оценки + заметки ────────────────
                      EntryCard(
                        onSliderActiveChanged: (active) {
                          _metricEditActive = active;
                          if (active) { _decided = true; _didSwipe = false; }
                        },
                        ratings: widget.selectedDay!.ratings.isEmpty
                            ? null
                            : widget.selectedDay!.ratings,
                        onRatingsSaved: widget.onRatingsSaved,
                        isToday: widget.isToday,
                      ),
                    ],
                  )
                : EmptyCard(isToday: widget.isToday, accent: accent, streak: widget.streak),
      ),
    );
  }
}


// ════════════════════════════════════════════════════
// _DayPreviewGrid — две плитки: Дневник + Вопросы
// ════════════════════════════════════════════════════
class _DayPreviewGrid extends StatelessWidget {
  final DayData selectedDay;
  final DateTime selectedDate;
  final String goalCategory;
  final List<String> photoPaths;
  final String dateKey;
  final Color accent;
  final bool isToday;
  final VoidCallback onOpenQuestions;
  final Future<void> Function(String) onNoteSaved;
  final Future<void> Function(List<String>) onPhotosSaved;

  const _DayPreviewGrid({
    required this.selectedDay,
    required this.selectedDate,
    required this.goalCategory,
    required this.photoPaths,
    required this.dateKey,
    required this.accent,
    required this.isToday,
    required this.onOpenQuestions,
    required this.onNoteSaved,
    required this.onPhotosSaved,
  });

  String get _dateLabel {
    const months = [
      'января','февраля','марта','апреля','мая','июня',
      'июля','августа','сентября','октября','ноября','декабря'
    ];
    return '${selectedDate.day} ${months[selectedDate.month - 1]} ${selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final surface   = Theme.of(context).colorScheme.surface;

    final questions = getDailyQuestions(selectedDate, category: goalCategory);
    final surveyPack = getDailySurveyPack(selectedDate, category: goalCategory);
    final surveyQs = List<String>.from(surveyPack['questions'] as List? ?? []);
    final totalQ    = questions.length + surveyQs.length;
    final filled    = selectedDay.answers
        .take(totalQ).where((a) => a.isNotEmpty).length;

    final hasNote   = selectedDay.note.isNotEmpty;
    final hasPhoto  = photoPaths.isNotEmpty;

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Левая плитка: ЗАПИСЬ ДНЯ ────────────────
          Expanded(
            child: GestureDetector(
              onTap: () => DiaryEditorScreen.show(
                context,
                dateLabel: _dateLabel,
                dateKey: dateKey,
                initialNoteJson: selectedDay.noteJson.isNotEmpty
                    ? selectedDay.noteJson
                    : selectedDay.note,
                initialPhotos: photoPaths,
                onNoteSaved: onNoteSaved,
                onPhotosSaved: onPhotosSaved,
              ),
              child: Container(
                // Внешний контейнер — border + glow (не clip!)
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: isToday ? Border.all(
                      color: const Color(0xFFFFD700), width: 2) : null,
                  boxShadow: isToday ? [BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                      blurRadius: 12, spreadRadius: 2)] : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isToday ? 18 : 20),
                  child: Container(
                    color: surface,
                    child: Stack(fit: StackFit.expand, children: [
                  // Фото фоном если есть
                  if (hasPhoto)
                    Image.file(File(photoPaths.first),
                        fit: BoxFit.cover),
                  // Затемнение поверх фото
                  if (hasPhoto)
                    Container(color: Colors.black.withValues(alpha: 0.35)),
                  // Содержимое
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.edit_note_rounded,
                              size: 16,
                              color: hasPhoto
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : textColor.withValues(alpha: 0.5)),
                          const SizedBox(width: 6),
                          Text('Дневник',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: hasPhoto
                                      ? Colors.white.withValues(alpha: 0.7)
                                      : textColor.withValues(alpha: 0.5))),
                          if (hasPhoto) ...[
                            const Spacer(),
                            Text('📷 ${photoPaths.length}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.white70)),
                          ],
                        ]),
                        const Spacer(),
                        // Превью текста
                        if (hasNote)
                          Text(
                            selectedDay.note.length > 80
                                ? '${selectedDay.note.substring(0, 80)}...'
                                : selectedDay.note,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasPhoto
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : textColor.withValues(alpha: 0.6),
                              height: 1.4,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          Text('Нажми чтобы записать...',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: hasPhoto
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : textColor.withValues(alpha: 0.2))),
                      ],
                    ),
                  ),
                ]),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Правая плитка: ВОПРОСЫ ──────────────────
          Expanded(
            child: GestureDetector(
              onTap: onOpenQuestions,
              child: Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: isToday ? Border.all(
                      color: const Color(0xFFFFD700), width: 2) : null,
                  boxShadow: isToday ? [BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                      blurRadius: 10, spreadRadius: 1)] : null,
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 16, color: accent),
                      const SizedBox(width: 6),
                      Text('Вопросы дня',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textColor.withValues(alpha: 0.5))),
                    ]),
                    const Spacer(),
                    // Большой счётчик
                    Text(
                      '$filled/$totalQ',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: filled == totalQ ? accent : textColor,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      filled == totalQ ? 'отвечено ✓' : 'ответов',
                      style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.4)),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: totalQ > 0 ? filled / totalQ : 0,
                        minHeight: 4,
                        backgroundColor: textColor.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// FutureCard — заглушка для будущих дат
// ════════════════════════════════════════════════════
class FutureCard extends StatelessWidget {
  const FutureCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
    ),
    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('⏳', style: TextStyle(fontSize: 56)),
      SizedBox(height: 16),
      Text('Этот день ещё впереди',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      SizedBox(height: 8),
      Text('Сначала проживи его 💪', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

// ════════════════════════════════════════════════════
// EmptyCard — пустая карточка (запись не сделана)
// Если streak > 0 и isToday — показывает таймер
// обратного отсчёта до полуночи: «стрик сгорит через X ч Y мин»
// Психологическое давление → D2 retention.
// ════════════════════════════════════════════════════
class EmptyCard extends StatefulWidget {
  final bool isToday;
  final Color accent;
  final int streak;

  const EmptyCard({
    super.key,
    required this.isToday,
    required this.accent,
    this.streak = 0,
  });

  @override
  State<EmptyCard> createState() => _EmptyCardState();
}

class _EmptyCardState extends State<EmptyCard> {
  late Duration _remaining;
  late final Stopwatch _sw;

  @override
  void initState() {
    super.initState();
    _sw = Stopwatch()..start();
    _remaining = _calcRemaining();
    // Обновляем каждые 30 секунд — достаточно для отсчёта ч/мин
    _tick();
  }

  Duration _calcRemaining() {
    final now  = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  void _tick() {
    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted) return;
      setState(() => _remaining = _calcRemaining());
      _tick();
    });
  }

  @override
  void dispose() {
    _sw.stop();
    super.dispose();
  }

  String _formatRemaining() {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    if (h > 0) return '$h ч $m мин';
    return '$m мин';
  }

  // Цвет таймера: зелёный → жёлтый → красный
  Color _timerColor() {
    final h = _remaining.inHours;
    if (h >= 4) return const Color(0xFF4CAF50);
    if (h >= 1) return const Color(0xFFFFB300);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final showTimer = widget.isToday && widget.streak > 0;
    final timerColor = _timerColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: widget.isToday
            ? Border.all(
                color: showTimer ? timerColor : const Color(0xFFFFD700),
                width: 2)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.isToday ? '🔥' : '📭',
              style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            widget.isToday ? 'Как прошёл день?' : 'Запись не сделана',
            style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w800, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            widget.isToday ? 'Нажми чтобы начать' : 'Нажми чтобы заполнить',
            style: TextStyle(
                color: textColor.withValues(alpha: 0.45), fontSize: 13),
          ),

          // ── Таймер сгорания стрика ──────────────────────────
          if (showTimer) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: timerColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: timerColor.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        color: timerColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Стрик ${widget.streak} ${_dayWord(widget.streak)} сгорит через',
                      style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRemaining(),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: timerColor,
                      letterSpacing: -0.5),
                ),
              ]),
            ),
          ] else if (widget.isToday) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.accent.withValues(alpha: 0.3)),
              ),
              child: Text('Займёт меньше 3 минут',
                  style: TextStyle(fontSize: 12,
                      color: widget.accent, fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  String _dayWord(int n) {
    if (n % 100 >= 11 && n % 100 <= 14) return 'дней';
    switch (n % 10) {
      case 1:  return 'день';
      case 2:
      case 3:
      case 4:  return 'дня';
      default: return 'дней';
    }
  }
}

