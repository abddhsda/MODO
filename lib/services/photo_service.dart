// ════════════════════════════════════════════════════
// services/photo_service.dart
//
// Управляет фотографиями записей дня.
//
// Логика:
//   • Фото копируется в app documents folder под именем
//     photo_YYYY-MM-DD_N.jpg — не зависит от галереи.
//   • Free: 1 фото на запись. Plus: до 5 фото.
//   • PhotoService.pick() — выбрать из галереи или камеры.
//   • PhotoService.delete() — удалить файл и запись.
//   • Хранение путей: в DayData.photoPaths (List<String>).
//
// Зависимости:
//   image_picker: ^1.1.2
//   path_provider: ^2.1.4
// ════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'subscription_service.dart';

class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();

  final _picker = ImagePicker();

  // ── Лимит фото на запись ──────────────────────────
  int get maxPhotos => SubscriptionService.instance.isPlus ? 5 : 1;

  bool canAddPhoto(int currentCount) => currentCount < maxPhotos;

  // ── Выбрать фото (галерея или камера) ─────────────
  // dateKey: 'YYYY-MM-DD', index: порядковый номер фото
  // Возвращает путь к сохранённому файлу или null при отмене
  Future<String?> pick(
    BuildContext context, {
    required String dateKey,
    required int index,
  }) async {
    final source = await _showSourceSheet(context);
    if (source == null) return null;

    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked == null) return null;

    return _save(picked, dateKey: dateKey, index: index);
  }

  // ── Сохранить файл в documents ────────────────────
  Future<String> _save(
    XFile xfile, {
    required String dateKey,
    required int index,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/photos');
    if (!await photosDir.exists()) await photosDir.create(recursive: true);

    final ext = xfile.path.split('.').last.toLowerCase();
    final fileName = 'photo_${dateKey}_$index.$ext';
    final dest = File('${photosDir.path}/$fileName');

    await File(xfile.path).copy(dest.path);
    return dest.path;
  }

  // ── Удалить фото ──────────────────────────────────
  Future<void> delete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // ── Шторка выбора источника ───────────────────────
  Future<ImageSource?> _showSourceSheet(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSourceSheet(),
    );
  }
}

// ─── Шторка выбора источника ──────────────────────────
class _PhotoSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final bg        = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          _tile(context, Icons.photo_library_outlined, 'Галерея',
              ImageSource.gallery, textColor),
          const SizedBox(height: 8),
          _tile(context, Icons.camera_alt_outlined, 'Камера',
              ImageSource.camera, textColor),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена',
                  style: TextStyle(
                      color: textColor.withValues(alpha: 0.45),
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label,
      ImageSource source, Color textColor) {
    return Material(
      color: textColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, source),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 22, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor)),
          ]),
        ),
      ),
    );
  }
}
