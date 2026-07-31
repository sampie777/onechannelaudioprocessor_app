import 'dart:math';

import 'package:flutter/material.dart';

class AudioMeterWidget extends StatelessWidget {
  final double peakLinear;    // 0.0 - 1.0
  final double avgPeakLinear; // 0.0 - 1.0

  const AudioMeterWidget({
    super.key,
    required this.peakLinear,
    required this.avgPeakLinear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: CustomPaint(
        painter: _MeterPainter(peakLinear: peakLinear, avgPeakLinear: avgPeakLinear),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double peakLinear;
  final double avgPeakLinear;

  _MeterPainter({required this.peakLinear, required this.avgPeakLinear});


  static double _dBToLinear(double linear) {
    return sqrt(linear.clamp(0.0, 1.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double height = size.height;
    final double width = size.width;

    // Draw Average Peak Bar (Solid Fill)
    final avgHeight = height * _dBToLinear(avgPeakLinear).clamp(0.0, 1.0);
    final avgRect = Rect.fromLTWH(4, height - avgHeight, width - 8, avgHeight);

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: const [Colors.green, Colors.yellow, Colors.red],
        stops: const [0.6, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    canvas.drawRect(avgRect, fillPaint);

    // Draw Max Peak Marker Line
    if (peakLinear > 0.01) {
      final peakY = height - (height * _dBToLinear(peakLinear).clamp(0.0, 1.0));
      final Paint linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.0;

      canvas.drawLine(Offset(2, peakY), Offset(width - 2, peakY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeterPainter oldDelegate) {
    return oldDelegate.peakLinear != peakLinear || oldDelegate.avgPeakLinear != avgPeakLinear;
  }
}