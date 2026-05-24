// ════════════════════════════════════════════════════
// services/export_service.dart
// A1 FIX: читает данные из ключа 'diary' (новый формат)
// Импорт поддерживает старый формат (entries/ratings/notes)
// для обратной совместимости со старыми бэкапами.
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/day_data.dart';
import '../utils/ui_helpers.dart';

class ExportService {

  // ─── Хелпер: загрузить diary из prefs ────────────────────────
  static Map<String, DayData> _loadDiary(SharedPreferences prefs) =>
      DayData.loadFromPrefs(prefs);

  // ─── Экспорт TXT ─────────────────────────────────────────────
  static Future<void> exportTxt(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final diary = _loadDiary(prefs);
      final goal  = prefs.getString('goal') ?? '';

      final buf = StringBuffer();
      buf.writeln('═══════════════════════════════');
      buf.writeln('  MODO — Дневник');
      buf.writeln('  ${DateTime.now().toString().substring(0, 10)}');
      buf.writeln('═══════════════════════════════');
      if (goal.isNotEmpty) { buf.writeln('Цель: $goal'); buf.writeln(); }

      final dates = diary.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final date in dates) {
        final day = diary[date]!;
        buf.writeln('───────────────────────────────');
        buf.writeln('📅 $date');
        buf.writeln();
        for (int i = 0; i < day.answers.length; i++) {
          if (day.answers[i].isNotEmpty) buf.writeln('  ${i + 1}. ${day.answers[i]}');
        }
        if (day.ratings.isNotEmpty) {
          buf.writeln();
          buf.writeln('  📊 Энергия ${day.ratings['energy']} | '
              'Продуктивность ${day.ratings['productivity']} | '
              'Настроение ${day.ratings['mood']} | '
              'Еда ${day.ratings['food']} | Сон ${day.ratings['sleep']}');
        }
        if (day.note.isNotEmpty) {
          buf.writeln();
          buf.writeln('  ✏️ ${day.note}');
        }
        buf.writeln();
      }

      await _shareText(buf.toString(), 'modo_diary.txt', 'text/plain');
      if (context.mounted) showAppSnack(context, 'Экспорт TXT готов');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Ошибка: $e', isError: true);
    }
  }

  // ─── Экспорт JSON (полный бэкап) ─────────────────────────────
  static Future<void> exportJson(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final diary = _loadDiary(prefs);

      // Экспортируем в новом формате (diary) + старом (entries/ratings/notes)
      // для обратной совместимости если пользователь восстановит на старой версии
      final entries = <String, dynamic>{};
      final ratings = <String, dynamic>{};
      final notes   = <String, dynamic>{};
      for (final e in diary.entries) {
        entries[e.key] = e.value.answers;
        ratings[e.key] = e.value.ratings;
        notes[e.key]   = e.value.note;
      }

      final data = {
        'version':      3,
        'exported_at':  DateTime.now().toIso8601String(),
        'app':          'modo',
        'goal':         prefs.getString('goal')         ?? '',
        'goalCategory': prefs.getString('goalCategory') ?? '',
        'isPremium':    prefs.getBool('isPremium')      ?? false,
        'accentIndex':  prefs.getInt('accentIndex')     ?? 0,
        'themeIndex':   prefs.getInt('themeIndex')      ?? 0,
        // Новый формат
        'diary':        {for (final e in diary.entries) e.key: e.value.toJson()},
        // Старый формат — для совместимости
        'entries':      entries,
        'ratings':      ratings,
        'notes':        notes,
        'plans':        jsonDecode(prefs.getString('flutter.plans') ?? '{}'),
      };
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      final date   = DateTime.now().toString().substring(0, 10);
      await _shareText(pretty, 'modo_backup_$date.json', 'application/json');
      if (context.mounted) showAppSnack(context, 'Бэкап JSON готов');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Ошибка: $e', isError: true);
    }
  }

  // ─── Экспорт CSV ─────────────────────────────────────────────
  static Future<void> exportCsv(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final diary = _loadDiary(prefs);

      final buf = StringBuffer();
      buf.writeln('Дата,Энергия,Продуктивность,Настроение,Еда,Сон,Ответов,Заметка');

      final dates = diary.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final date in dates) {
        final day    = diary[date]!;
        final r      = day.ratings;
        final filled = day.answers.where((a) => a.isNotEmpty).length;
        final note   = day.note
            .replaceAll('"', '""') // RFC 4180
            .replaceAll('\n', ' ');
        buf.writeln([
          date,
          r['energy']       ?? '',
          r['productivity'] ?? '',
          r['mood']         ?? '',
          r['food']         ?? '',
          r['sleep']        ?? '',
          filled,
          '"$note"',
        ].join(','));
      }

      final date = DateTime.now().toString().substring(0, 10);
      await _shareText(buf.toString(), 'modo_stats_$date.csv', 'text/csv');
      if (context.mounted) showAppSnack(context, 'Экспорт CSV готов');
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Ошибка: $e', isError: true);
    }
  }

  // ─── Импорт JSON ─────────────────────────────────────────────
  static Future<void> importJson(
    BuildContext context, {
    Future<void> Function()? onImported,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Выбери бэкап Modo',
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.first.path;
      if (path == null) return;

      final content = await File(path).readAsString();
      final data    = jsonDecode(content) as Map<String, dynamic>;

      if (data['app'] != 'modo' && !data.containsKey('entries') &&
          !data.containsKey('diary')) {
        if (context.mounted) showAppSnack(context, 'Это не бэкап Modo', isError: true);
        return;
      }

      if (context.mounted) {
        final exportedAt = data['exported_at'] as String? ?? 'неизвестно';
        final date = exportedAt.length >= 10 ? exportedAt.substring(0, 10) : exportedAt;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text('Восстановить данные?',
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface)),
            content: Text(
              'Бэкап от $date будет загружен.\n\nТекущие данные будут заменены.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white, elevation: 0),
                child: const Text('Восстановить'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      final prefs  = await SharedPreferences.getInstance();
      final writes = <Future>[];

      // Приоритет: новый формат diary → старый entries/ratings/notes
      if (data.containsKey('diary')) {
        writes.add(prefs.setString('diary', jsonEncode(data['diary'])));
        // Удаляем старые ключи если есть
        writes.addAll([prefs.remove('entries'), prefs.remove('ratings'), prefs.remove('notes')]);
      } else {
        // Старый бэкап — пишем в старые ключи, миграция произойдёт при следующей загрузке
        if (data['entries'] != null) writes.add(prefs.setString('entries', jsonEncode(data['entries'])));
        if (data['ratings'] != null) writes.add(prefs.setString('ratings', jsonEncode(data['ratings'])));
        if (data['notes']   != null) writes.add(prefs.setString('notes',   jsonEncode(data['notes'])));
      }

      if (data['plans'] != null) {
        writes.add(prefs.setString('flutter.plans', jsonEncode(data['plans'])));
        writes.add(prefs.setString('plans',         jsonEncode(data['plans'])));
      }
      if (data['goal']         != null) writes.add(prefs.setString('goal',         data['goal'] as String));
      if (data['goalCategory'] != null) writes.add(prefs.setString('goalCategory', data['goalCategory'] as String));
      if (data['isPremium']    != null) writes.add(prefs.setBool('isPremium',      data['isPremium'] as bool));
      if (data['accentIndex']  != null) writes.add(prefs.setInt('accentIndex',     data['accentIndex'] as int));
      if (data['themeIndex']   != null) writes.add(prefs.setInt('themeIndex',      data['themeIndex'] as int));

      await Future.wait(writes);

      if (context.mounted) {
        hapticSuccess();
        if (onImported != null) {
          await onImported();
          if (context.mounted) showAppSnack(context, '✅ Данные восстановлены');
        } else {
          showAppSnack(context, '✅ Данные восстановлены. Перезапусти приложение.');
        }
      }
    } on FileSystemException {
      if (context.mounted) showAppSnack(context, 'Не удалось прочитать файл', isError: true);
    } on FormatException {
      if (context.mounted) showAppSnack(context, 'Файл повреждён', isError: true);
    } catch (e) {
      if (context.mounted) showAppSnack(context, 'Ошибка: $e', isError: true);
    }
  }

  // ─── Вспомогательные ─────────────────────────────────────────
  static Future<void> _shareText(
      String content, String filename, String mimeType) async {
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content, encoding: utf8);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: 'Modo — $filename',
    );
  }
}
