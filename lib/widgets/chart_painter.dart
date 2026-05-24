// ════════════════════════════════════════════════════
// widgets/chart_painter.dart
//
// ВОЛНА 1: vPad, shouldRepaint, halo, opacity
// ВОЛНА 2: Catmull-Rom, gradient fill, крест-фикс
// ВОЛНА 3: Ось X каждые 7 дней
// ВОЛНА 4 (по ТЗ):
//   • Ось X: метки каждые 3 дня + воскресенья
//     с пунктирной вертикальной линией
//   • Ось Y: метки 2/4/6/8/10 слева
//   • Default state: все линии opacity 0.30
//   • Скраббинг: вертикальная направляющая
//   • Хитбокс точек 24dp (снаружи)
// ════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

class ChartPainter extends CustomPainter {
  final Map<String, Map<String, int>> allRatings;
  final int year;
  final int month;
  final int daysInMonth;
  final List<String> metrics;
  final List<Color> colors;
  final String? selectedMetric;
  final bool isDark;
  final int? highlightedDay;   // день под пальцем (скраббинг / тап)
  final Color accentColor;

  const ChartPainter({
    required this.allRatings,
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.metrics,
    required this.colors,
    this.selectedMetric,
    this.isDark = false,
    this.highlightedDay,
    this.accentColor = const Color(0xFFFF9800),
  });

  static const double _xAxisHeight = 20.0; // место под ось X снизу
  static const double _yAxisWidth  = 20.0; // место под метки Y слева
  static const double _vPad        = 8.0;  // отступ сверху/снизу для точек

  // Y-координата значения в рабочей области
  double _yFor(double value, double chartH, double topOffset) =>
      topOffset + chartH - (value / 10) * chartH;

  // X-координата дня с учётом отступа под ось Y
  double _xFor(int day, double plotW) => daysInMonth > 1
      ? _yAxisWidth + (day - 1) / (daysInMonth - 1) * plotW
      : _yAxisWidth + plotW / 2;

  // Воскресенье ли этот день месяца?
  bool _isSunday(int day) {
    final dt = DateTime(year, month, day);
    return dt.weekday == DateTime.sunday;
  }

  // ─── Catmull-Rom сглаживание ──────────────────────────────────
  Path _catmullRomPath(List<Offset> pts) {
    if (pts.length < 2) return Path();
    if (pts.length == 2) {
      return Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy);
    }
    final path     = Path()..moveTo(pts[0].dx, pts[0].dy);
    final extended = [pts[0], ...pts, pts.last];
    const t        = 0.4;
    for (int i = 1; i < extended.length - 2; i++) {
      final p0 = extended[i - 1];
      final p1 = extended[i];
      final p2 = extended[i + 1];
      final p3 = extended[i + 2];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) * t / 2,
                         p1.dy + (p2.dy - p0.dy) * t / 2);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) * t / 2,
                         p2.dy - (p3.dy - p1.dy) * t / 2);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bool   finite      = size.height.isFinite;
    final double totalH      = finite ? size.height : 178.0;
    final double plotHeight  = totalH - _xAxisHeight; // рабочая высота
    final double plotWidth   = size.width - _yAxisWidth;
    final double topOffset   = _vPad;
    final double chartHeight = plotHeight - _vPad * 2;

    // ─── Цвета ────────────────────────────────────────────────
    // Default: 30% opacity. Фокус: 100% выбранная, 15% остальные.
    final effectiveColors = List.generate(metrics.length, (i) {
      if (selectedMetric == null) return colors[i].withValues(alpha: 0.30);
      return metrics[i] == selectedMetric
          ? colors[i]
          : colors[i].withValues(alpha: 0.15);
    });
    // Полный цвет выбранной (для fill, halo)
    final selectedColor = selectedMetric != null
        ? colors[metrics.indexOf(selectedMetric!)]
        : accentColor;

    // ─── Ось Y: горизонтальные линии сетки + метки слева ──────
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: isDark ? 0.12 : 0.20)
      ..strokeWidth = 0.5;
    final gridTextStyle = TextStyle(
      fontSize: 8,
      color: Colors.grey.withValues(alpha: isDark ? 0.45 : 0.40),
      fontWeight: FontWeight.w400,
    );

    for (int v = 0; v <= 10; v += 2) {
      final y = _yFor(v.toDouble(), chartHeight, topOffset);
      // Линия сетки (от yAxisWidth до конца)
      canvas.drawLine(
          Offset(_yAxisWidth, y), Offset(size.width, y), gridPaint);
      // Метка слева
      final tp = _makeTextPainter('$v', style: gridTextStyle);
      tp.layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // ─── Ось X: метки каждые 3 дня + воскресенья ─────────────
    final xAxisY   = plotHeight + 3;
    final tickPaint = Paint()
      ..color = Colors.grey.withValues(alpha: isDark ? 0.25 : 0.30)
      ..strokeWidth = 1;
    final sundayLinePaint = Paint()
      ..color = Colors.grey.withValues(alpha: isDark ? 0.18 : 0.22)
      ..strokeWidth = 0.8;

    final normalLabelStyle = TextStyle(
      fontSize: 8,
      color: Colors.grey.withValues(alpha: isDark ? 0.55 : 0.50),
    );
    final sundayLabelStyle = TextStyle(
      fontSize: 8,
      color: Colors.grey.withValues(alpha: isDark ? 0.80 : 0.70),
      fontWeight: FontWeight.w600,
    );
    final highlightLabelStyle = TextStyle(
      fontSize: 9,
      color: accentColor,
      fontWeight: FontWeight.w700,
    );

    // Пунктир для воскресений
    const dashW = 3.0, gapW = 3.0;

    for (int d = 1; d <= daysInMonth; d++) {
      final isSun  = _isSunday(d);
      final isHigh = highlightedDay == d;
      final show3  = d % 2 != 0 || d == daysInMonth; // все нечётные + последний

      if (!show3 && !isSun && !isHigh) continue;

      final x = _xFor(d, plotWidth);

      // Воскресенье — пунктирная вертикальная линия через весь граф
      if (isSun) {
        double dy = topOffset;
        while (dy < plotHeight) {
          canvas.drawLine(
            Offset(x, dy),
            Offset(x, math.min(dy + dashW, plotHeight)),
            sundayLinePaint,
          );
          dy += dashW + gapW;
        }
      }

      // Риска на оси
      canvas.drawLine(
        Offset(x, plotHeight - 3),
        Offset(x, plotHeight + 1),
        isHigh
            ? (Paint()..color = accentColor..strokeWidth = 1.5)
            : tickPaint,
      );

      // Подпись
      if (show3 || isSun || isHigh) {
        final style = isHigh
            ? highlightLabelStyle
            : isSun
                ? sundayLabelStyle
                : normalLabelStyle;
        final tp = _makeTextPainter('$d', style: style);
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, xAxisY));
      }
    }

    // Подсветка дня не из show3/sun
    if (highlightedDay != null &&
        highlightedDay! >= 1 &&
        highlightedDay! <= daysInMonth) {
      final d   = highlightedDay!;
      final x   = _xFor(d, plotWidth);
      final isSun = _isSunday(d);
      final show3 = d % 3 == 0 || d == 1 || d == daysInMonth;
      if (!show3 && !isSun) {
        // Уже не нарисовали выше — рисуем сейчас
        canvas.drawLine(Offset(x, plotHeight - 3), Offset(x, plotHeight + 1),
            Paint()..color = accentColor..strokeWidth = 1.5);
        final tp = _makeTextPainter('$d', style: highlightLabelStyle);
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, xAxisY));
      }

      // Вертикальная направляющая линия скраббинга
      canvas.drawLine(
        Offset(x, topOffset),
        Offset(x, plotHeight),
        Paint()
          ..color = accentColor.withValues(alpha: 0.4)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    // ─── Координаты точек ─────────────────────────────────────
    final metricPoints = <int, List<Offset>>{};
    for (int mi = 0; mi < metrics.length; mi++) {
      final pts = <Offset>[];
      for (int d = 1; d <= daysInMonth; d++) {
        final key =
            '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
        final rating = allRatings[key]?[metrics[mi]];
        if (rating != null) {
          final x = _xFor(d, plotWidth);
          final y = _yFor(rating.toDouble(), chartHeight, topOffset);
          pts.add(Offset(x, y));
        }
      }
      metricPoints[mi] = pts;
    }

    // ─── Линии невыбранных метрик ─────────────────────────────
    for (int mi = 0; mi < metrics.length; mi++) {
      if (selectedMetric != null && metrics[mi] == selectedMetric) continue;
      final pts = metricPoints[mi]!;
      if (pts.length < 2) continue;
      canvas.drawPath(_catmullRomPath(pts), Paint()
        ..color      = effectiveColors[mi]
        ..strokeWidth = selectedMetric == null ? 1.5 : 1.0
        ..style      = PaintingStyle.stroke
        ..strokeCap  = StrokeCap.round
        ..strokeJoin = StrokeJoin.round);
    }

    // ─── Выбранная метрика: gradient fill + жирная кривая ─────
    if (selectedMetric != null) {
      final selIdx = metrics.indexOf(selectedMetric!);
      if (selIdx >= 0) {
        final pts   = metricPoints[selIdx]!;
        final color = selectedColor;

        if (pts.length >= 2) {
          final curve = _catmullRomPath(pts);

          // Fill — клипаем до рабочей области
          canvas.save();
          canvas.clipRect(Rect.fromLTWH(0, 0, size.width, plotHeight));
          final fillPath = Path.from(curve)
            ..lineTo(pts.last.dx, plotHeight)
            ..lineTo(pts.first.dx, plotHeight)
            ..close();
          canvas.drawPath(fillPath, Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, topOffset),
              Offset(0, plotHeight),
              [color.withValues(alpha: 0.20), color.withValues(alpha: 0.0)],
            )
            ..style = PaintingStyle.fill);
          canvas.restore();

          // Кривая
          canvas.drawPath(curve, Paint()
            ..color      = color
            ..strokeWidth = 3
            ..style      = PaintingStyle.stroke
            ..strokeCap  = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
        }
      }
    }

    // ─── Точки невыбранных (пицца) ────────────────────────────
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (int mi = 0; mi < metrics.length; mi++) {
      for (final pt in metricPoints[mi]!) {
        final k = '${pt.dx.toStringAsFixed(1)}_${pt.dy.toStringAsFixed(1)}';
        grouped.putIfAbsent(k, () => []);
        grouped[k]!.add({
          'x': pt.dx, 'y': pt.dy,
          'color': effectiveColors[mi], 'metric': metrics[mi],
        });
      }
    }

    const double r = 3.5;
    for (final pts in grouped.values) {
      final hasSelected = selectedMetric != null &&
          pts.any((p) => p['metric'] == selectedMetric);
      if (hasSelected) continue;
      final x      = pts[0]['x'] as double;
      final y      = pts[0]['y'] as double;
      final center = Offset(x, y);

      if (pts.length == 1) {
        canvas.drawCircle(center, r,
            Paint()..color = pts[0]['color'] as Color);
      } else {
        final sweep = 2 * math.pi / pts.length;
        for (int i = 0; i < pts.length; i++) {
          final path = Path()
            ..moveTo(x, y)
            ..arcTo(Rect.fromCircle(center: center, radius: r),
                -math.pi / 2 + sweep * i, sweep, false)
            ..close();
          canvas.drawPath(path, Paint()
            ..color = pts[i]['color'] as Color
            ..style = PaintingStyle.fill);
        }
        canvas.drawCircle(center, r, Paint()
          ..color       = Colors.white.withValues(alpha: 0.3)
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 0.5);
      }
    }

    // ─── Точки выбранной метрики: halo поверх всего ──────────
    if (selectedMetric != null) {
      final selIdx = metrics.indexOf(selectedMetric!);
      if (selIdx >= 0) {
        final color = selectedColor;
        for (final pt in metricPoints[selIdx]!) {
          // Glow
          canvas.drawCircle(pt, 12, Paint()
            ..color = color.withValues(alpha: 0.12)
            ..style = PaintingStyle.fill);
          // Подложка
          canvas.drawCircle(pt, 7, Paint()
            ..color = isDark ? const Color(0xFF1A1A1A) : Colors.white
            ..style = PaintingStyle.fill);
          // Точка
          canvas.drawCircle(pt, 5, Paint()
            ..color = color
            ..style = PaintingStyle.fill);
          // Контур
          canvas.drawCircle(pt, 5, Paint()
            ..color       = color.withValues(alpha: 0.5)
            ..style       = PaintingStyle.stroke
            ..strokeWidth = 1.5);
        }
      }
    }
  }

  TextPainter _makeTextPainter(String text, {required TextStyle style}) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
    );
  }

  @override
  bool shouldRepaint(ChartPainter old) =>
      old.allRatings     != allRatings     ||
      old.selectedMetric != selectedMetric ||
      old.highlightedDay != highlightedDay ||
      old.year           != year           ||
      old.month          != month          ||
      old.isDark         != isDark;
}
