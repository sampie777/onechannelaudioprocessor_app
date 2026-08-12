import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../utils/math.dart';

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

  double _fallingPeak = 0.0; // Peak-hold line value
  double _displayedBarPeak = 0.0; // Interpolated main bar value
  Duration _lastTickTime = Duration.zero;

  // The specific dB stops that should be spaced evenly on the meter
  final List<double> _meterStops = [-60.0, -40.0, -20.0, -10.0, -5.0, 0.0];
  static const double _decayRatePerSecond = 0.0015;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant AudioMeterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.peak > _fallingPeak) {
      _fallingPeak = widget.peak.clamp(0.0, 1.0);
    }
  }

  void _onTick(Duration elapsed) {
    // Calculate delta time between frames for frame-rate independent physics
    final double dt = _lastTickTime == Duration.zero
        ? 1 / 60.0
        : (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    setState(() {
      // Peak Hold Decay
      if (_fallingPeak > 0.0) {
        _fallingPeak -= _decayRatePerSecond * dt * 60.0;
        if (_fallingPeak < widget.peak) {
          _fallingPeak = widget.peak.clamp(0.0, 1.0);
        }
      }

      // Smooth Bar Interpolation (filling bar)
      final double target = widget.peak.clamp(0.0, 1.0);
      if (_displayedBarPeak < target) {
        // Attack: Fast rise (0.35 factor per frame for instant response)
        _displayedBarPeak += (target - _displayedBarPeak) * 0.35;
      } else {
        // Release: Smooth glide down between 50ms+ network updates
        _displayedBarPeak += (target - _displayedBarPeak) * 0.12;
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
              Container(
                width: widget.width,
                height: 280,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: CustomPaint(
                  painter: _MeterPainter(
                    peakLinear: _fallingPeak,
                    avgPeakLinear: _displayedBarPeak,
                    meterStops: _meterStops,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                width: 35,
                child: CustomPaint(
                  painter: AudioMeterScalePainter(meterStops: _meterStops),
                ),
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
  final List<double> meterStops;

  _MeterPainter({
    required this.peakLinear,
    required this.avgPeakLinear,
    required this.meterStops,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double height = size.height;
    final double width = size.width;

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: const [Colors.green, Colors.yellow, Colors.red],
        stops: const [0.6, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, width, height));

    // Calculate height based on new piecewise visual scale mapping
    final avgHeight =
        height * rawToVisualLinear(meterStops, avgPeakLinear).clamp(0.0, 1.0);
    final Rect barRect = Rect.fromLTWH(0, height - avgHeight, width, avgHeight);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
      fillPaint,
    );

    if (peakLinear > 0.001) {
      // Calculate Y coordinate for peak line using the same piecewise visual scale
      final peakY =
          height -
          (height * rawToVisualLinear(meterStops, peakLinear).clamp(0.0, 1.0));
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
  // Use ticks that map exactly to the new piecewise segments
  final List<double> ticks = [0.0, -5.0, -10.0, -20.0, -40.0, -60.0];
  final List<double> meterStops;

  AudioMeterScalePainter({required this.meterStops});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeCap = StrokeCap.round;

    for (final tick in ticks) {
      // Piecewise fraction (0.0 is bottom of the meter, 1.0 is top)
      final double visualFraction = dbToVisualLinear(meterStops, tick);

      // Invert for Canvas Y coordinate (Y=0 is top, Y=height is bottom)
      final double normalizedY = 1.0 - visualFraction;
      final double y = normalizedY * size.height;

      final isZero = tick == 0.0;
      final lineLength = isZero ? 10.0 : 6.0;

      paint.color = isZero ? Colors.redAccent : Colors.grey.shade600;
      paint.strokeWidth = isZero ? 2.0 : 1.5;

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

      tp.paint(canvas, Offset(lineLength + 6, y - (tp.height / 2)));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
