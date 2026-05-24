// ════════════════════════════════════════════════════
// services/shopping_service.dart
//
// Список покупок — хранится под ключом 'flutter.shopping'
// Структура: List<{id, name, count, checked}>
// Синхронизируется с виджетом через SharedPreferences.
// ════════════════════════════════════════════════════

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _kShoppingKey = 'flutter.shopping';

class ShoppingItem {
  final String id;
  final String name;
  final int count;
  final bool checked;

  const ShoppingItem({
    required this.id,
    required this.name,
    required this.count,
    required this.checked,
  });

  ShoppingItem copyWith({String? name, int? count, bool? checked}) =>
      ShoppingItem(
        id:      id,
        name:    name      ?? this.name,
        count:   count     ?? this.count,
        checked: checked   ?? this.checked,
      );

  Map<String, dynamic> toJson() => {
    'id':      id,
    'name':    name,
    'count':   count,
    'checked': checked,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
    id:      j['id']      as String,
    name:    j['name']    as String,
    count:   (j['count']  as num).toInt(),
    checked: j['checked'] as bool,
  );
}

Future<List<ShoppingItem>> loadShopping(SharedPreferences prefs) async {
  final raw = prefs.getString(_kShoppingKey);
  if (raw == null || raw.isEmpty) return [];
  try {
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ShoppingItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveShopping(
    SharedPreferences prefs, List<ShoppingItem> items) async {
  final json = jsonEncode(items.map((e) => e.toJson()).toList());
  await prefs.setString(_kShoppingKey, json);
}
