import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ecg_record.dart';
import '../theme/app_colors.dart';

class HRDataPoint {
  final DateTime timestamp;
  final int heartRate;
  final Severity severity;

  HRDataPoint({required this.timestamp, required this.heartRate, required this.severity});
}

class HeartRateChartPainter extends CustomPainter {
  final List<HRDataPoint> data;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  HeartRateChartPainter({
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftPad = 40.0;
    const rightPad = 16.0;
    const topPad = 16.0;
    const bottomPad = 40.0;
    final chartWidth = size.width - leftPad - rightPad;
    final chartHeight = size.height - topPad - bottomPad;

    // Y range: 30-180 BPM
    const minHR = 30;
    const maxHR = 180;
    const hrRange = maxHR - minHR;

    double yForHR(int hr) {
      return topPad + chartHeight - ((hr - minHR) / hrRange * chartHeight);
    }

    double xForTime(DateTime t) {
      final totalMs = rangeEnd.difference(rangeStart).inMilliseconds;
      if (totalMs == 0) return leftPad;
      final ms = t.difference(rangeStart).inMilliseconds;
      return leftPad + (ms / totalMs * chartWidth);
    }

    // Normal range band (60-100 BPM)
    final normalBandPaint = Paint()..color = AppColors.normalGreen.withAlpha(20);
    canvas.drawRect(
      Rect.fromLTRB(leftPad, yForHR(100), leftPad + chartWidth, yForHR(60)),
      normalBandPaint,
    );

    // Reference lines at 60 and 100
    final refPaint = Paint()
      ..color = AppColors.normalGreen.withAlpha(80)
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(leftPad, yForHR(60)),
      Offset(leftPad + chartWidth, yForHR(60)),
      refPaint,
    );
    canvas.drawLine(
      Offset(leftPad, yForHR(100)),
      Offset(leftPad + chartWidth, yForHR(100)),
      refPaint,
    );

    // Y axis labels
    final textStyle = TextStyle(color: Colors.grey.shade500, fontSize: 10);
    for (final hr in [40, 60, 80, 100, 120, 140, 160]) {
      final tp = TextPainter(
        text: TextSpan(text: '$hr', style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, yForHR(hr) - tp.height / 2));

      // Grid line
      final gridPaint = Paint()
        ..color = Colors.grey.shade200
        ..strokeWidth = 0.5;
      canvas.drawLine(
        Offset(leftPad, yForHR(hr)),
        Offset(leftPad + chartWidth, yForHR(hr)),
        gridPaint,
      );
    }

    // X axis date labels (up to 5)
    final labelCount = data.length < 5 ? data.length : 5;
    final step = data.length > 1 ? (data.length - 1) / (labelCount - 1) : 1;
    for (int i = 0; i < labelCount; i++) {
      final idx = (i * step).round().clamp(0, data.length - 1);
      final point = data[idx];
      final x = xForTime(point.timestamp);
      final dateStr = DateFormat('M/d').format(point.timestamp);
      final tp = TextPainter(
        text: TextSpan(text: dateStr, style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomPad + 8));
    }

    // Connecting lines
    if (data.length > 1) {
      for (int i = 0; i < data.length - 1; i++) {
        final p1 = data[i];
        final p2 = data[i + 1];
        final linePaint = Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(xForTime(p1.timestamp), yForHR(p1.heartRate)),
          Offset(xForTime(p2.timestamp), yForHR(p2.heartRate)),
          linePaint,
        );
      }
    }

    // Data points
    for (final point in data) {
      final x = xForTime(point.timestamp);
      final y = yForHR(point.heartRate);
      final color = switch (point.severity) {
        Severity.normal => AppColors.normalGreen,
        Severity.warning => AppColors.warningAmber,
        Severity.critical => AppColors.criticalRed,
      };

      canvas.drawCircle(Offset(x, y), 5, Paint()..color = color);
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HeartRateChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.rangeStart != rangeStart ||
        oldDelegate.rangeEnd != rangeEnd;
  }
}
