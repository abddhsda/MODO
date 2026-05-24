// ════════════════════════════════════════════════════
// services/widget_sync.dart
//
// FIX SYNC: виджет теперь пишет ТОЛЬКО в 'flutter.plans'.
// widgetPull больше не сравнивает два ключа — он просто
// читает актуальные данные и возвращает их Flutter.
// Это устраняет баг когда новый план из виджета не
// появлялся в приложении (ключи были равны → null).
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kFlutterKey = 'flutter.plans';
const _kNativeKey  = 'plans';
const _widgetChannel = MethodChannel('ru.modo.app/widget');
const _syncChannel   = MethodChannel('ru.modo.app/sync');

// ── push: Flutter → Виджет ───────────────────────────────────────
// Вызывать после каждого изменения планов в Flutter.
// Пишет в оба ключа (нативный виджет читает 'plans' напрямую
// если flutter.plans недоступен), затем триггерит updateWidget.
Future<void> widgetPush(
  SharedPreferences prefs,
  Map<String, List<Map<String, dynamic>>> allPlans,
) async {
  final encoded = jsonEncode(allPlans);
  await Future.wait([
    prefs.setString(_kFlutterKey, encoded),
    prefs.setString(_kNativeKey,  encoded),
  ]);
  try {
    await _widgetChannel.invokeMethod('updateWidget');
  } catch (_) {
    // Канал недоступен если приложение в фоне — не критично
  }
}

// ── pull: Виджет → Flutter ────────────────────────────────────────
// Вызывается при:
//   1. resume приложения (didChangeAppLifecycleState)
//   2. получении onPlansChanged через syncChannel (мгновенно)
//
// FIX: не сравниваем два ключа — просто читаем flutter.plans
// и возвращаем актуальные данные. Если данные не изменились
// относительно того что уже есть в Flutter — вернём null.
Future<Map<String, List<Map<String, dynamic>>>?> widgetPull(
  SharedPreferences prefs, {
  Map<String, List<Map<String, dynamic>>>? current,
}) async {
  await prefs.reload();

  final raw = prefs.getString(_kFlutterKey) ?? prefs.getString(_kNativeKey) ?? '{}';

  // Если передан текущий стейт — сравниваем чтобы не делать лишний setState
  if (current != null) {
    final currentEncoded = jsonEncode(current);
    if (currentEncoded == raw) return null;
  }

  return _decodePlans(raw);
}

// ── Подписка на мгновенные уведомления от виджета ────────────────
// Вызывай один раз в initState PlannerScreen или HomeScreen.
// onChanged вызывается когда виджет изменил flutter.plans
// (toggle или добавление плана через AddPlanActivity).
void setupWidgetSyncListener(Future<void> Function() onChanged) {
  _syncChannel.setMethodCallHandler((call) async {
    if (call.method == 'onPlansChanged') {
      await onChanged();
    }
  });
}

// ── Вспомогательные ──────────────────────────────────────────────
Map<String, List<Map<String, dynamic>>> _decodePlans(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((k, v) => MapEntry(
      k.toString(),
      (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    ));
  } catch (e) {
    debugPrint('[WidgetSync] decode error: $e');
    return {};
  }
}
