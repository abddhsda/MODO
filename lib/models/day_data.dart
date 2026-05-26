// ════════════════════════════════════════════════════
// models/day_data.dart
//
// A1 FIX: хранилище переведено с 3 отдельных ключей
// ('entries', 'ratings', 'notes') на один ключ 'diary'.
//
// Формат: Map<dateKey, {answers, ratings, note}>
// Атомарная запись — нет рассинхронизации при падении.
//
// Миграция: при первом запуске читаем старые ключи,
// записываем в новый, удаляем старые.
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DayData {
  final List<String> answers;
  final Map<String, int> ratings;
  final String note;
  // Категория цели на момент записи дня.
  // Сохраняется при каждом сохранении дня — вопросы при просмотре
  // берутся из этой категории, а не из текущей настройки профиля.
  // Пустая строка = категория неизвестна (старые записи) → fallback на текущую.
  final String category;
  final List<String> photoPaths;
  // Rich text Delta JSON (flutter_quill). Пустая строка = нет форматирования.
  final String noteJson;

  const DayData({
    this.answers = const [],
    this.ratings = const {},
    this.note    = '',
    this.category = '',
    this.photoPaths = const [],
    this.noteJson   = '',
  });

  DayData copyWith({
    List<String>?    answers,
    Map<String, int>? ratings,
    String?           note,
    String?           category,
    List<String>?     photoPaths,
    String?           noteJson,
  }) =>
      DayData(
        answers:  answers  ?? this.answers,
        ratings:  ratings  ?? this.ratings,
        note:     note     ?? this.note,
        category:   category   ?? this.category,
        photoPaths: photoPaths ?? this.photoPaths,
        noteJson:   noteJson   ?? this.noteJson,
      );

  // ── JSON ──────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'answers':  answers,
    'ratings':  ratings,
    'note':     note,
    'category':   category,
    'photoPaths': photoPaths,
    'noteJson':   noteJson,
  };

  factory DayData.fromJson(Map<dynamic, dynamic> j) => DayData(
    answers:  List<String>.from(j['answers'] as List? ?? []),
    ratings:  Map<String, int>.from(
        (j['ratings'] as Map? ?? {}).map((k, v) => MapEntry(k as String, (v as num).toInt()))),
    note:     j['note']     as String? ?? '',
    category:   j['category']   as String? ?? '',
    photoPaths: List<String>.from(j['photoPaths'] as List? ?? []),
    noteJson:   j['noteJson']   as String? ?? '',
  );

  // ── Загрузка ──────────────────────────────────────

  static Map<String, DayData> loadFromPrefs(SharedPreferences prefs) {
    // Сначала проверяем новый ключ
    final newRaw = prefs.getString('diary');
    if (newRaw != null) {
      try {
        final map = jsonDecode(newRaw) as Map;
        return {
          for (final e in map.entries)
            e.key as String: DayData.fromJson(e.value as Map),
        };
      } catch (_) {
        // повреждён — читаем старые ключи как fallback
      }
    }

    // Миграция со старых ключей
    return _migrateFromOldKeys(prefs);
  }

  static Map<String, DayData> _migrateFromOldKeys(SharedPreferences prefs) {
    final rawEntries = _decodeMap(prefs.getString('entries'));
    final rawRatings = _decodeMap(prefs.getString('ratings'));
    final rawNotes   = _decodeMap(prefs.getString('notes'));

    final allKeys = <String>{
      ...rawEntries.keys.cast<String>(),
      ...rawRatings.keys.cast<String>(),
      ...rawNotes.keys.cast<String>(),
    };

    return {
      for (final key in allKeys)
        key: DayData(
          answers: List<String>.from(rawEntries[key] as List? ?? []),
          ratings: Map<String, int>.from(
              (rawRatings[key] as Map? ?? {}).map(
                  (k, v) => MapEntry(k as String, (v as num).toInt()))),
          note: rawNotes[key] as String? ?? '',
        ),
    };
  }

  static Map _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try { return jsonDecode(raw) as Map; } catch (_) { return {}; }
  }

  // ── Сохранение ────────────────────────────────────

  static Future<void> saveToPrefs(
    SharedPreferences prefs,
    Map<String, DayData> diary,
  ) async {
    // Атомарная запись в один ключ
    await prefs.setString('diary', jsonEncode({
      for (final e in diary.entries) e.key: e.value.toJson(),
    }));

    // Удаляем старые ключи если они ещё существуют (однократно при миграции)
    if (prefs.containsKey('entries') ||
        prefs.containsKey('ratings') ||
        prefs.containsKey('notes')) {
      await Future.wait([
        prefs.remove('entries'),
        prefs.remove('ratings'),
        prefs.remove('notes'),
      ]);
    }
  }
}
