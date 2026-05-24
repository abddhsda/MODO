// ════════════════════════════════════════════════════
// screens/onboarding_screen.dart
//
// SplashOnboarding  — тур по приложению (6 шагов, Overlay)
// OnboardingScreen  — первый запуск: имя → цель → уведомления
// ════════════════════════════════════════════════════

// FIX БАГ-3: убран 'dart:io' — импортировался только для _buildWidgetStep,
// который был мёртвым кодом после удаления шага виджета (O1 FIX).
import 'package:flutter/material.dart';
import '../app.dart';
import '../services/notifications.dart' as notif;
import '../services/analytics.dart';

// ════════════════════════════════════════════════════
// SplashOnboarding — полупрозрачный тур поверх UI
// ════════════════════════════════════════════════════
class SplashOnboarding extends StatefulWidget {
  final GlobalKey? headerKey;
  final GlobalKey? dateKey;
  final GlobalKey? cardKey;
  final GlobalKey? navKey;
  final GlobalKey? statsKey;
  final GlobalKey? plannerKey;
  final Color accent;
  final VoidCallback onDone;
  final VoidCallback? onOpenQuestions;
  final void Function(int tabIndex)? onSwitchTab;

  const SplashOnboarding({
    super.key,
    this.headerKey,
    this.dateKey,
    this.cardKey,
    this.navKey,
    this.statsKey,
    this.plannerKey,
    required this.accent,
    required this.onDone,
    this.onOpenQuestions,
    this.onSwitchTab,
  });

  @override
  State<SplashOnboarding> createState() => _SplashOnboardingState();
}

class _SplashOnboardingState extends State<SplashOnboarding> {
  int _step = 0;

  static const _steps = [
    {
      'key':   'header',
      'emoji': '🔥',
      'title': 'Твоя цель и стрик',
      'sub':   'Стрик — сколько дней подряд ты заполняешь дневник. Нажми на 🔥 чтобы увидеть статистику.',
    },
    {
      'key':   'date',
      'emoji': '📅',
      'title': 'Навигация по дням',
      'sub':   'Свайпай влево и вправо по карточке чтобы переходить между днями.',
    },
    {
      'key':   'card',
      'emoji': '💬',
      'title': 'Вопросы и оценки дня',
      'sub':   'Нажми на карточку чтобы ответить на вопросы дня.\nОценивай энергию, настроение и продуктивность.',
    },
    {
      'key':   'card',
      'emoji': '🎚️',
      'title': 'Быстрая правка оценок',
      'sub':   'Зажми строку метрики на секунду — появится ползунок. Тяни влево или вправо чтобы изменить значение.',
    },
    {
      'key':   'stats',
      'emoji': '📊',
      'title': 'Статистика',
      'sub':   'Графики по дням — смотри свой прогресс, тренды настроения и энергии.',
    },
    {
      'key':   'planner',
      'emoji': '📋',
      'title': 'Планировщик',
      'sub':   'Добавляй задачи на день — они появятся прямо на виджете рабочего стола.',
    },
    {
      'key':   'done',
      'emoji': '🚀',
      'title': 'Готово! Заполни первый день',
      'sub':   'Нажми «Начать» — и сразу запишем сегодняшний день.\nЗаймёт меньше 3 минут.',
    },
  ];

  Rect? _getRect(GlobalKey? key) {
    if (key == null) return null;
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  bool _done = false;

  // FIX БАГ-4: onOpenQuestions откладывается на следующий кадр,
  // чтобы OverlayEntry успела удалиться из дерева до открытия QuestionScreen.
  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone(); // планирует удаление entry через addPostFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOpenQuestions?.call();
    });
  }

  void _goToStep(int next) {
    setState(() => _step = next);
    final zone = _steps[next]['key'];
    if (zone == 'stats')   widget.onSwitchTab?.call(1);
    if (zone == 'planner') widget.onSwitchTab?.call(2);
    if (zone == 'header' || zone == 'date' ||
        zone == 'card' || zone == 'done') {
      widget.onSwitchTab?.call(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent  = widget.accent;
    final step    = _steps[_step];
    final zone    = step['key']!;
    final isFirst = _step == 0;
    final isLast  = _step == _steps.length - 1;
    final bottom  = MediaQuery.of(context).padding.bottom;

    Rect? highlightRect;
    if (zone == 'header')  highlightRect = _getRect(widget.headerKey);
    if (zone == 'date')    highlightRect = _getRect(widget.dateKey);
    if (zone == 'card')    highlightRect = _getRect(widget.cardKey);
    if (zone == 'nav')     highlightRect = _getRect(widget.navKey);
    if (zone == 'stats')   highlightRect = _getRect(widget.statsKey);
    if (zone == 'planner') highlightRect = _getRect(widget.plannerKey);

    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _finish,
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.black.withValues(alpha: 0.5)),
              ),
            ),

            if (highlightRect != null)
              Positioned(
                left:   highlightRect.left   - 6,
                top:    highlightRect.top    - 6,
                width:  highlightRect.width  + 12,
                height: highlightRect.height + 12,
                child: IgnorePointer(
                  child: _GlowBorder(accent: accent),
                ),
              ),

            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _TourCard(
                step:          _step,
                total:         _steps.length,
                emoji:         step['emoji']!,
                title:         step['title']!,
                sub:           step['sub']!,
                accent:        accent,
                isFirst:       isFirst,
                isLast:        isLast,
                onNext: () {
                  if (_step < _steps.length - 1) {
                    _goToStep(_step + 1);
                  } else {
                    _finish();
                  }
                },
                onPrev: () { if (_step > 0) _goToStep(_step - 1); },
                onSkip: _finish,
                bottomPadding: bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBorder extends StatelessWidget {
  final Color accent;
  const _GlowBorder({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  final int step, total;
  final String emoji, title, sub;
  final Color accent;
  final bool isFirst, isLast;
  final VoidCallback onNext, onPrev, onSkip;
  final double bottomPadding;

  const _TourCard({
    required this.step, required this.total,
    required this.emoji, required this.title, required this.sub,
    required this.accent, required this.isFirst, required this.isLast,
    required this.onNext, required this.onPrev, required this.onSkip,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    final maxCardHeight = MediaQuery.of(context).size.height * 0.65;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxCardHeight),
      child: Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(total, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 6),
              width:  i == step ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == step ? accent : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
          const SizedBox(height: 20),

          Flexible(
            child: SingleChildScrollView(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey(step),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(height: 10),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.6),
                            height: 1.5)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isFirst)
                TextButton(
                  onPressed: onPrev,
                  child: Text('← Назад',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                )
              else
                TextButton(
                  onPressed: onSkip,
                  child: Text('Пропустить',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                ),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    isLast ? 'Понятно ✓' : 'Далее →',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

// ════════════════════════════════════════════════════
// OnboardingScreen — имя → цель → категория → уведомления
// ════════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  final Future<void> Function(String goal, String category, String name) onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  String? _selectedCategory;
  int _step = 0; // 0=имя, 1=цель+категория, 2=уведомления

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double>  _fadeAnim;

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
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _goalCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // FIX БАГ-1: добавлен mounted guard после await slideCtrl.reverse()
  Future<void> _goTo(int step) async {
    await _slideCtrl.reverse();
    if (!mounted) return;
    setState(() => _step = step);
    _slideCtrl.forward();
  }

  bool get _canProceed {
    switch (_step) {
      case 0: return _nameCtrl.text.trim().isNotEmpty;
      case 1: return _goalCtrl.text.trim().isNotEmpty && _selectedCategory != null;
      default: return true;
    }
  }

  Future<void> _next() async {
    if (_step == 0) { await _goTo(1); return; }
    if (_step == 1) { await _goTo(2); return; }
    if (_step == 2) {
      final notifGranted = await notif.requestNotificationPermission();
      if (mounted) {
        final msg = notifGranted
            ? '🔔 Уведомления включены!'
            : '🔕 Можно включить позже в настройках';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      Analytics.onboardingComplete(
        category: _selectedCategory ?? 'mindset',
      );
      await widget.onDone(
        _goalCtrl.text.trim(),
        _selectedCategory ?? 'mindset',
        _nameCtrl.text.trim(),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent    = AppSettings.of(context).accent;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final bg        = Theme.of(context).scaffoldBackgroundColor;
    final bottom    = MediaQuery.of(context).viewInsets.bottom;
    final safePad   = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Прогресс ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: List.generate(4, (i) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 3,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? accent
                          : textColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),

            // ── Контент ─────────────────────────────────────────
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        24, 32, 24,
                        bottom > 0 ? bottom + 16 : safePad + 120),
                    child: _buildStep(textColor, accent),
                  ),
                ),
              ),
            ),

            // ── Кнопка — всегда над клавиатурой и навбаром ──────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24,
                  bottom > 0 ? bottom + 8 : safePad + 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => _goTo(_step - 1),
                      child: Text('← Назад',
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.4))),
                    )
                  else
                    const SizedBox(width: 80),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _canProceed ? _next : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: accent.withValues(alpha: 0.25),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _step == 2 ? 'Начать →' : 'Далее →',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
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

  Widget _buildStep(Color textColor, Color accent) {
    switch (_step) {
      case 0: return _buildNameStep(textColor, accent);
      case 1: return _buildGoalStep(textColor, accent);
      case 2: return _buildNotifStep(textColor, accent);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildNameStep(Color textColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('👋', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text('Как тебя зовут?',
            style: TextStyle(fontSize: 26,
                fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 8),
        Text('Modo будет обращаться к тебе по имени.',
            style: TextStyle(fontSize: 14,
                color: textColor.withValues(alpha: 0.5))),
        const SizedBox(height: 32),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: 24,
              fontWeight: FontWeight.w700, color: textColor),
          decoration: InputDecoration(
            hintText: 'Имя...',
            hintStyle: TextStyle(
                color: textColor.withValues(alpha: 0.3), fontSize: 22),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildGoalStep(Color textColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🎯', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text('Над чем работаешь?',
            style: TextStyle(fontSize: 26,
                fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 8),
        Text('Вопросы дня будут подстраиваться под твою цель.',
            style: TextStyle(fontSize: 14,
                color: textColor.withValues(alpha: 0.5))),

        const SizedBox(height: 28),
        Text('Направление',
            style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.6))),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat['key'];
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat['key']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? accent : accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? accent : accent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Text('${cat['emoji']} ${cat['title']}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : textColor)),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        Text('Твоя цель',
            style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.6))),
        const SizedBox(height: 4),
        TextField(
          controller: _goalCtrl,
          style: TextStyle(fontSize: 20,
              fontWeight: FontWeight.w700, color: textColor),
          decoration: InputDecoration(
            hintText: 'Например: похудеть на 10 кг',
            hintStyle: TextStyle(
                color: textColor.withValues(alpha: 0.3), fontSize: 16),
            border: InputBorder.none,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildNotifStep(Color textColor, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🔔', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text('Разреши уведомления',
            style: TextStyle(fontSize: 26,
                fontWeight: FontWeight.w900, color: textColor)),
        const SizedBox(height: 8),
        Text('Modo напомнит заполнить дневник и пришлёт уведомление\n'
             'когда наступит время задачи из планировщика.',
            style: TextStyle(fontSize: 15,
                color: textColor.withValues(alpha: 0.6), height: 1.5)),
        const SizedBox(height: 32),
        _InfoRow(
          icon: Icons.edit_calendar_outlined,
          accent: accent,
          text: 'Напоминание заполнить дневник',
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.alarm_rounded,
          accent: accent,
          text: 'Уведомления о задачах из планировщика',
        ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.notifications_off_outlined,
          accent: accent,
          text: 'Можно отключить в любой момент в настройках',
        ),
      ],
    );
  }
  // FIX БАГ-3: метод _buildWidgetStep удалён вместе с импортом dart:io —
  // шаг виджета был убран из онбординга (O1 FIX), метод стал мёртвым кодом.
}

// ─── Вспомогательные виджеты ─────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String text;
  const _InfoRow({required this.icon, required this.accent, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.8)
                      : const Color(0xFF1A1A1A).withValues(alpha: 0.8))),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number, text;
  final Color accent, textColor;
  const _StepRow({required this.number, required this.text,
      required this.accent, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: accent, shape: BoxShape.circle),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text,
                style: TextStyle(fontSize: 15, color: textColor)),
          ),
        ),
      ],
    );
  }
}
