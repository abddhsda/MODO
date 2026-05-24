// ════════════════════════════════════════════════════
// screens/question_screen.dart — экран ввода ответов
//
// ИСПРАВЛЕНИЕ DRAFT-1: автосохранение черновика
//   • При каждом _next() / _prev() и onChange текстового поля
//     ответы сохраняются в SharedPreferences под ключом
//     draft_answers_YYYY-MM-DD (дата выбранного дня, не сегодня).
//   • При initState черновик восстанавливается, если есть.
//     Переданный existing имеет приоритет над черновиком
//     (редактирование уже сохранённого дня).
//   • При успешном завершении (Navigator.pop с ratings)
//     черновик удаляется.
//   • При выходе через «Выйти» в диалоге черновик остаётся —
//     пользователь продолжит позже.
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';
import '../utils/ui_helpers.dart';
import 'ratings_screen.dart';

class QuestionScreen extends StatefulWidget {
  final List<String>? existing;
  final List<Map<String, String>> questions;
  final Map<String, dynamic> surveyPack;
  // FIX БАГ-5: дата выбранного дня передаётся явно,
  // чтобы ключ черновика не был жёстко привязан к сегодня.
  final DateTime selectedDate;

  const QuestionScreen({
    super.key,
    this.existing,
    required this.questions,
    required this.surveyPack,
    required this.selectedDate,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int _current = 0;
  late List<TextEditingController> _textControllers;
  late List<TextEditingController> _surveyControllers;

  SharedPreferences? _prefs;

  // FIX БАГ-5: ключ черновика привязан к выбранному дню, а не к DateTime.now()
  String _draftKey() {
    final d = widget.selectedDate;
    return 'draft_answers_${d.year}'
        '-${d.month.toString().padLeft(2, '0')}'
        '-${d.day.toString().padLeft(2, '0')}';
  }

  List<String> get _surveyQuestions =>
      List<String>.from(widget.surveyPack['questions'] as List);

  int  get _totalSteps  => widget.questions.length + _surveyQuestions.length;
  bool get _inSurvey    => _current >= widget.questions.length;
  int  get _surveyIndex => _current - widget.questions.length;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing ?? [];
    _textControllers = List.generate(widget.questions.length,
        (i) => TextEditingController(
            text: i < existing.length ? existing[i] : ''));
    _surveyControllers = List.generate(_surveyQuestions.length, (i) {
      final idx = widget.questions.length + i;
      return TextEditingController(
          text: idx < existing.length ? existing[idx] : '');
    });

    for (final c in _textControllers)   c.addListener(_saveDraft);
    for (final c in _surveyControllers) c.addListener(_saveDraft);

    if (existing.isEmpty) {
      SharedPreferences.getInstance().then((prefs) {
        _prefs = prefs;
        _restoreDraft(prefs);
      });
    } else {
      SharedPreferences.getInstance().then((p) => _prefs = p);
    }
  }

  void _restoreDraft(SharedPreferences prefs) {
    final raw = prefs.getString(_draftKey());
    if (raw == null) return;
    try {
      final list = List<String>.from(jsonDecode(raw) as List);
      for (int i = 0; i < _textControllers.length; i++) {
        if (i < list.length && _textControllers[i].text.isEmpty) {
          _textControllers[i].text = list[i];
        }
      }
      for (int i = 0; i < _surveyControllers.length; i++) {
        final idx = widget.questions.length + i;
        if (idx < list.length && _surveyControllers[i].text.isEmpty) {
          _surveyControllers[i].text = list[idx];
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Повреждённый черновик — молча игнорируем
    }
  }

  void _saveDraft() {
    final prefs = _prefs;
    if (prefs == null) return;
    final all = [
      ..._textControllers.map((c) => c.text),
      ..._surveyControllers.map((c) => c.text),
    ];
    prefs.setString(_draftKey(), jsonEncode(all));
  }

  void _clearDraft() => _prefs?.remove(_draftKey());

  @override
  void dispose() {
    for (final c in _textControllers)   c.dispose();
    for (final c in _surveyControllers) c.dispose();
    super.dispose();
  }

  void _next() async {
    _saveDraft();
    if (_current < _totalSteps - 1) {
      hapticLight();
      setState(() => _current++);
    } else {
      hapticMedium();
      final allAnswers = [
        ..._textControllers.map((c) => c.text),
        ..._surveyControllers.map((c) => c.text),
      ];
      final ratings = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => RatingsScreen(answers: allAnswers)),
      );
      if (ratings != null) {
        _clearDraft();
      }
      if (context.mounted) Navigator.pop(context, ratings);
    }
  }

  void _prev() {
    if (_current > 0) {
      _saveDraft();
      hapticLight();
      setState(() => _current--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final textColor  = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final accent     = AppSettings.of(context).accent;
    final controller = _inSurvey
        ? _surveyControllers[_surveyIndex]
        : _textControllers[_current];
    final isLast = _current == _totalSteps - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final hasAnyAnswer = [
          ..._textControllers,
          ..._surveyControllers,
        ].any((c) => c.text.isNotEmpty);
        if (!hasAnyAnswer) {
          _clearDraft();
          Navigator.pop(context);
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text('Выйти?',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface)),
            content: Text(
                'Черновик сохранён — вернёшься и продолжишь с того же места.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Остаться',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(elevation: 0),
                child: const Text('Выйти'),
              ),
            ],
          ),
        );
        // Черновик остаётся — пользователь продолжит позже
        if ((leave ?? false) && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Прогресс ──────────────────────────────────
                Row(
                  children: List.generate(_totalSteps, (i) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i <= _current
                            ? accent
                            : textColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 16),

                // ── Лейбл пака ────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _inSurvey
                      ? Container(
                          key: const ValueKey('survey_label'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${widget.surveyPack['emoji']} ${widget.surveyPack['title']}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: accent),
                          ),
                        )
                      : const SizedBox(key: ValueKey('empty_label')),
                ),
                const SizedBox(height: 24),

                // ── Вопрос ────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero)
                          .animate(anim),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_current),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_inSurvey) ...[
                        Text(widget.questions[_current]['emoji']!,
                            style: const TextStyle(fontSize: 56)),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        _inSurvey
                            ? _surveyQuestions[_surveyIndex]
                            : widget.questions[_current]['q']!,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: textColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Поле ввода ────────────────────────────────
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    expands: true,
                    autofocus: true,
                    style: TextStyle(
                        fontSize: 18, color: textColor, height: 1.5),
                    decoration: InputDecoration(
                      hintText: 'Пиши честно...',
                      hintStyle: TextStyle(
                          color: textColor.withValues(alpha: 0.3)),
                      border: InputBorder.none,
                    ),
                  ),
                ),

                // ── Навигация ─────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_current > 0)
                      TextButton(
                        onPressed: _prev,
                        child: Text('← Назад',
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.4),
                                fontSize: 15)),
                      )
                    else
                      const SizedBox(),
                    ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isLast ? accent : const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        isLast ? 'Готово ✓' : 'Далее →',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
