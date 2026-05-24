// ════════════════════════════════════════════════════
// logic/daily_logic.dart — логика ежедневного контента
//
// Три функции:
//   getDailyQuestions()   → 6 вопросов (3 тематических + 3 глубоких)
//   getDailySurveyPack()  → 1 пак с 5 вопросами на тему
//   getDailyQuote()       → 1 цитата дня
//
// Алгоритм: детерминированный через seed = год*10000+месяц*100+день
// Один и тот же день = один и тот же контент (воспроизводимо)
// ════════════════════════════════════════════════════

import '../constants/question_bank.dart';
import '../constants/survey_packs.dart';
import '../constants/quotes.dart';

// ─── Веса категорий по цели пользователя ─────────────────────
// Ключ = goalCategory, значение = {категория вопроса: вес}
// Чем выше вес — тем чаще выбирается эта категория
const Map<String, Map<String, int>> _categoryWeights = {
  'money':     {'money': 3, 'productivity': 2, 'mindset': 1},
  'health':    {'mindset': 3, 'productivity': 2, 'money': 1},
  'learning':  {'productivity': 3, 'mindset': 2, 'money': 1},
  'relations': {'mindset': 3, 'money': 1, 'productivity': 2},
  'career':    {'productivity': 3, 'money': 2, 'mindset': 1},
  'mindset':   {'mindset': 3, 'productivity': 2, 'money': 1},
};

// ─── Паки опросов по категориям ──────────────────────────────
const Map<String, List<String>> _categoryPacks = {
  'money':     ['Деньги сегодня', 'Траты и контроль', 'Финансовые цели', 'Карьера и рост',
                'Финансовая безопасность', 'Бизнес-мышление', 'Риск и возможности',
                'Ценообразование себя', 'Долги и обязательства', 'Деньги работают',
                'Итоги недели по деньгам', 'Переговоры', 'Страх и деньги'],
  'health':    ['Здоровье и тело', 'Режим и сон', 'Энергия и состояние', 'Стресс и тревога',
                'Привычки', 'Зависимости', 'Комфорт и рост'],
  'learning':  ['Обучение', 'Глубокая работа', 'Результат дня', 'Приоритеты',
                'Фокус', 'Прокрастинация', 'Планирование'],
  'relations': ['Отношения', 'Нетворкинг', 'Влияние и вклад', 'Благодарность',
                'Честность с собой', 'Тишина и одиночество'],
  'career':    ['Карьера и рост', 'Профессиональная репутация', 'Результат дня',
                'Приоритеты', 'Делегирование', 'Скорость решений', 'Многозадачность'],
  'mindset':   ['Честность с собой', 'Уроки прошлого', 'Будущее и планы', 'Дисциплина',
                'Ответственность', 'Сравнение с собой', 'Комфорт и рост',
                'Стресс и тревога', 'Цель и смысл'],
};

// ─── 6 вопросов дня: 3 тематических + 3 глубоких ────────────
List<Map<String, String>> getDailyQuestions(
  DateTime date, {
  String category = 'money',
}) {
  final seed = date.year * 10000 + date.month * 100 + date.day;
  final weights = _categoryWeights[category] ?? _categoryWeights['money']!;

  // Строим pool с повторами по весу: money×3, productivity×2, mindset×1
  final pool = <String>[];
  weights.forEach((key, weight) {
    for (int i = 0; i < weight; i++) pool.add(key);
  });

  // Выбираем 3 уникальных категории.
  // Множители 13 и 37 — простые числа, обеспечивают равномерное распределение
  // при обходе массива pool через модуль (избегаем циклических повторений).
  const int stepA = 13;
  const int stepB = 37;
  final result = <Map<String, String>>[];
  final usedCategories = <String>{};
  int attempts = 0;
  while (result.length < 3 && attempts < 100) {
    final pickedCategory = pool[(seed + attempts * stepA) % pool.length];
    if (!usedCategories.contains(pickedCategory)) {
      usedCategories.add(pickedCategory);
      final questions = questionBank[pickedCategory]!;
      result.add(questions[(seed + attempts * stepB) % questions.length]);
    }
    attempts++;
  }

  // Добираем из оставшихся если не хватило
  for (final key in questionBank.keys) {
    if (result.length >= 3) break;
    if (!usedCategories.contains(key)) {
      result.add(questionBank[key]![seed % questionBank[key]!.length]);
    }
  }

  // 3 глубоких вопроса (emoji = 🔍).
  // Множители 7 и 41 — простые числа, аналогично выше.
  final deepQuestions = deepQuestionBank[category] ?? deepQuestionBank['money']!;
  final deep = <Map<String, String>>[];
  final usedDeep = <int>{};
  int di = 0;
  while (deep.length < 3 && di < 100) {
    final idx = (seed * 7 + di * 41) % deepQuestions.length;
    if (!usedDeep.contains(idx)) {
      usedDeep.add(idx);
      deep.add({'emoji': '🔍', 'q': deepQuestions[idx]});
    }
    di++;
  }

  return [...result, ...deep];
}

// ─── Пак опроса дня ──────────────────────────────────────────
Map<String, dynamic> getDailySurveyPack(
  DateTime date, {
  String category = 'money',
}) {
  final seed = date.year * 10000 + date.month * 100 + date.day;
  final preferredTitles = _categoryPacks[category] ?? _categoryPacks['money']!;

  // Ищем паки из приоритетных для категории
  final preferred = surveyPacks
      .where((p) => preferredTitles.contains(p['title']))
      .toList();

  if (preferred.isNotEmpty) {
    return preferred[(seed * 31) % preferred.length];
  }

  // Фолбэк — любой пак
  return surveyPacks[(seed * 31) % surveyPacks.length];
}

// ─── Цитата дня ──────────────────────────────────────────────
Map<String, String> getDailyQuote(DateTime date) {
  final seed = date.year * 10000 + date.month * 100 + date.day;
  return quotes[(seed * 17) % quotes.length];
}
