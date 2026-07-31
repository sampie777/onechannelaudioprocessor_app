import 'package:flutter/material.dart';

import '../utils/math.dart';

class AudioMeterWidget extends StatelessWidget {
  final double peakLinear; // 0.0 - 1.0
  final double avgPeakLinear; // 0.0 - 1.0

  const AudioMeterWidget({
    super.key,
    required this.peakLinear,
    required this.avgPeakLinear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. The Audio Meter Widget
        Column(
          children: [
            Expanded(
              child: Container(
                width: 48,
                height: 280,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: CustomPaint(
                  painter: _MeterPainter(
                    peakLinear: peakLinear,
                    avgPeakLinear: avgPeakLinear,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 5,
              children: [
                Text(
                  rawToDbfs(avgPeakLinear).toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12.0),
                ),
                Text('dBFS', style: const TextStyle(fontSize: 10.0)),
              ],
            ),
          ],
        ),
        const SizedBox(width: 4),
        // 2. The Professional dBFS Scale
        Column(
          children: [
            Expanded(
              child: SizedBox(
                width: 35,
                child: CustomPaint(painter: AudioMeterScalePainter()),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ],
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double peakLinear;
  final double avgPeakLinear;

  _MeterPainter({required this.peakLinear, required this.avgPeakLinear});

  @override
  void paint(Canvas canvas, Size size) {
    final double height = size.height;
    final double width = size.width;

    // Draw Average Peak Bar (Solid Fill)
    final avgHeight = height * rawToDbLinear(avgPeakLinear).clamp(0.0, 1.0);
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
      final peakY =
          height - (height * rawToDbLinear(peakLinear).clamp(0.0, 1.0));
      final Paint linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.0;

      canvas.drawLine(Offset(2, peakY), Offset(width - 2, peakY), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MeterPainter oldDelegate) {
    return oldDelegate.peakLinear != peakLinear ||
        oldDelegate.avgPeakLinear != avgPeakLinear;
  }
}

// -----------------------------------------------------------------------------
// AUDIO METER SCALE PAINTER
// -----------------------------------------------------------------------------
class AudioMeterScalePainter extends CustomPainter {
  final List<double> ticks = [0.0, -6.0, -12.0, -20.0, -24.0, -48.0];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;

    // Maps standard dBFS values to a 0.0 -> 1.0 height ratio
    // 0 dBFS is at the very top (y = 0), -60 dBFS is at the bottom (y = height)
    for (final tick in ticks) {
      // Linear approximation for visual meter scaling (0dB is top, -48dB is near bottom)
      // Assuming a floor of -60dB for the bottom of the meter
      final double normalized = dbfsToDbLinear(tick);
      // final double normalized = _dbfsToLinear(tick);
      final double y = normalized * size.height;

      final isZero = tick == 0.0;
      final lineLength = isZero ? 10.0 : 6.0;

      paint.color = isZero ? Colors.redAccent : Colors.grey.shade600;
      paint.strokeWidth = isZero ? 2.0 : 1.5;

      // Draw tick line pointing left towards the meter
      canvas.drawLine(Offset(0, y), Offset(lineLength, y), paint);

      final text = tick == 0 ? '0' : '${tick.toInt()}';
      final textStyle = TextStyle(
        color: isZero ? Colors.redAccent : Colors.grey.shade500,
        fontSize: 10,
        fontWeight: isZero ? FontWeight.bold : FontWeight.normal,
      );

      final tp = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      // Paint text to the right of the tick line
      tp.paint(canvas, Offset(lineLength + 6, y - (tp.height / 2)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
