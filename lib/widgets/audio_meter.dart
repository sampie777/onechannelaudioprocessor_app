import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../utils/math.dart';

class AudioMeterWidget extends StatefulWidget {
  final double peak; // 0.0 - 1.0
  final double width;
  final String? label;

  const AudioMeterWidget({
    super.key,
    required this.peak,
    required this.width,
    this.label,
  });

  @override
  State<AudioMeterWidget> createState() => _AudioMeterWidgetState();
}

class _AudioMeterWidgetState extends State<AudioMeterWidget>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _fallingPeak = 0.0;

  // Rate at which the peak bar drops per second (1.0 = full height per second)
  // Adjust this value to make the drop faster or slower!
  static const double _decayRatePerSecond = 0.05;

  @override
  void initState() {
    super.initState();
    // Use a Ticker to smoothly animate the drop on every display frame (60/120 Hz)
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant AudioMeterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If incoming peak is higher than current falling indicator, snap up immediately
    if (widget.peak > _fallingPeak) {
      _fallingPeak = widget.peak.clamp(0.0, 1.0);
    }
  }

  void _onTick(Duration elapsed) {
    if (_fallingPeak <= 0.0) return;

    // Calculate time delta since last frame (~16ms)
    // Decrement peak gradually over time
    setState(() {
      _fallingPeak -= _decayRatePerSecond * (1 / 60.0);

      // Keep falling peak clamped between current real-time peak and 0
      if (_fallingPeak < widget.peak) {
        _fallingPeak = widget.peak.clamp(0.0, 1.0);
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. The Audio Meter Widget
              Container(
                width: widget.width,
                height: 280,
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: CustomPaint(
                  painter: _MeterPainter(
                    peakLinear: _fallingPeak,
                    avgPeakLinear: widget.peak,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 2. The Professional dBFS Scale
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                width: 35,
                child: CustomPaint(painter: AudioMeterScalePainter()),
              ),
            ],
          ),
        ),
        if (widget.label != null)
          Text(
            widget.label!,
            style: const TextStyle(fontSize: 12.0, color: Colors.grey),
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
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: const [Colors.green, Colors.yellow, Colors.red],
        stops: const [0.6, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    final avgHeight = height * rawToDbLinear(avgPeakLinear).clamp(0.0, 1.0);
    final Rect barRect = Rect.fromLTWH(0, height - avgHeight, width, avgHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
      fillPaint,
    );

    // Draw Max Peak Marker Line
    if (peakLinear > 0.001) {
      final peakY =
          height - (height * rawToDbLinear(peakLinear).clamp(0.0, 1.0));
      final Paint linePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

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
