import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ECGWaveformPainter extends CustomPainter {
  final List<double> data;
  final double pixelsPerSample;
  final double verticalScale;
  final int? visibleSamples; // for animated reveal

  ECGWaveformPainter({
    required this.data,
    this.pixelsPerSample = 2.0,
    this.verticalScale = 80.0,
    this.visibleSamples,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawTrace(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppColors.ecgBackground,
    );

    // Minor grid (1mm equivalent = 10px)
    const minorStep = 10.0;
    final minorPaint = Paint()
      ..color = AppColors.ecgGridMinor
      ..strokeWidth = 0.3;
    for (double x = 0; x < size.width; x += minorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorPaint);
    }
    for (double y = 0; y < size.height; y += minorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minorPaint);
    }

    // Major grid (5mm equivalent = 50px)
    const majorStep = 50.0;
    final majorPaint = Paint()
      ..color = AppColors.ecgGridMajor
      ..strokeWidth = 0.7;
    for (double x = 0; x < size.width; x += majorStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), majorPaint);
    }
    for (double y = 0; y < size.height; y += majorStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), majorPaint);
    }
  }

  void _drawTrace(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final sampleCount = visibleSamples ?? data.length;
    if (sampleCount < 2) return;

    final centerY = size.height / 2;
    final tracePaint = Paint()
      ..color = AppColors.ecgTrace
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(0, centerY - data[0] * verticalScale);

    for (int i = 1; i < sampleCount && i < data.length; i++) {
      path.lineTo(
        i * pixelsPerSample,
        centerY - data[i] * verticalScale,
      );
    }

    canvas.drawPath(path, tracePaint);
  }

  @override
  bool shouldRepaint(covariant ECGWaveformPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.visibleSamples != visibleSamples;
  }
}

class ECGWaveformWidget extends StatelessWidget {
  final List<double> data;
  final double height;

  const ECGWaveformWidget({
    super.key,
    required this.data,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final width = data.length * 2.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: CustomPaint(
          size: Size(width, height),
          painter: ECGWaveformPainter(data: data),
        ),
      ),
    );
  }
}
