import 'dart:math';

import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';

class EqScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const EqScreen({super.key, required this.service});

  @override
  State<EqScreen> createState() => _EqScreenState();
}

class _EqScreenState extends State<EqScreen> {
  static const List<int> _highPassFreqs = [4, 122, 153, 156, 245, 306, 392, 490, 612];
  static const List<int> _lowShelfFreqs = [80, 105, 135, 175];
  static const List<int> _lowFreqs = [230, 300, 385, 500];
  static const List<int> _midFreqs = [650, 850, 1100, 1400];
  static const List<int> _highFreqs = [1800, 2400, 3200, 4100];
  static const List<int> _highShelfFreqs = [5300, 6900, 9000, 11700];

  void _sendEqCommand(String band, String param, String value) {
    widget.service.sendCommands({'eq.$band.$param': value});
  }

  void _resetBand(String band, dynamic filter, int defaultFreq, {bool isParametric = false}) {
    // Clear client-side bypass memory
    if (filter is ShelfFilter || filter is ParametricEqBand) {
      filter.isBypassed = false;
      filter.storedGain = 0;
    }

    final Map<String, String> commands = {
      'eq.$band.frequency': defaultFreq.toString(),
      'eq.$band.gain': '0',
    };
    if (isParametric) commands['eq.$band.band'] = 'narrow';
    widget.service.sendCommands(commands);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('6-Band EQ'),
      ),
      body: StreamBuilder<MixerState>(
        stream: widget.service.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data;
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final eq = state.eq;

          return Column(
            children: [
              Container(
                height: 220,
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: CustomPaint(
                  painter: EqCurvePainter(eqState: eq),
                ),
              ),
              const Divider(height: 1, thickness: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildHighPassCard(eq.highPass),
                    const SizedBox(height: 16),
                    _buildShelfCard('Low Shelf', 'low_shelf', eq.lowShelf, _lowShelfFreqs),
                    const SizedBox(height: 16),
                    _buildParametricCard('Low Band', 'low', eq.low, _lowFreqs),
                    const SizedBox(height: 16),
                    _buildParametricCard('Mid Band', 'mid', eq.mid, _midFreqs),
                    const SizedBox(height: 16),
                    _buildParametricCard('High Band', 'high', eq.high, _highFreqs),
                    const SizedBox(height: 16),
                    _buildShelfCard('High Shelf', 'high_shelf', eq.highShelf, _highShelfFreqs),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHighPassCard(HighPassFilter hpf) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Text('High Pass Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset Band',
                  onPressed: () => widget.service.sendCommands({
                    'eq.high_pass.enabled': 'f',
                    'eq.high_pass.frequency': hpf.defaultFreq.toString() // Use model default
                  }),
                ),
                Switch(
                  value: hpf.enabled.value, // HPF uses hardware enable
                  onChanged: (val) => _sendEqCommand('high_pass', 'enabled', val ? 't' : 'f'),
                ),
              ],
            ),
            _buildDiscreteSliderRow(
              label: 'Freq',
              value: hpf.frequency.value,
              allowedValues: _highPassFreqs,
              unit: 'Hz',
              onChanged: (val) => _sendEqCommand('high_pass', 'frequency', val.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelfCard(String title, String bandKey, ShelfFilter filter, List<int> allowedFreqs) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset Band',
                  onPressed: () => _resetBand(bandKey, filter, filter.defaultFreq,),
                ),
                Switch(
                  value: !filter.isBypassed,
                  onChanged: (enabled) {
                    if (enabled) {
                      filter.isBypassed = false;
                      _sendEqCommand(bandKey, 'gain', filter.storedGain.toString());
                    } else {
                      filter.storedGain = filter.uiGain;
                      filter.isBypassed = true;
                      _sendEqCommand(bandKey, 'gain', '0'); // Mute on ESP32
                    }
                  },
                ),
              ],
            ),
            _buildDiscreteSliderRow(
              label: 'Freq',
              value: filter.frequency.value,
              allowedValues: allowedFreqs,
              unit: 'Hz',
              onChanged: (val) => _sendEqCommand(bandKey, 'frequency', val.toString()),
            ),
            _buildGainSliderRow(
              label: 'Gain',
              value: filter.uiGain,
              onChanged: (val) {
                if (filter.isBypassed) {
                  // Only update locally if bypassed to prevent un-bypassing
                  setState(() => filter.storedGain = val);
                } else {
                  _sendEqCommand(bandKey, 'gain', val.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParametricCard(String title, String bandKey, ParametricEqBand band, List<int> allowedFreqs) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset Band',
                  onPressed: () => _resetBand(bandKey, band, band.defaultFreq, isParametric: true),
                ),
                Switch(
                  value: !band.isBypassed,
                  onChanged: (enabled) {
                    if (enabled) {
                      band.isBypassed = false;
                      _sendEqCommand(bandKey, 'gain', band.storedGain.toString());
                    } else {
                      band.storedGain = band.uiGain;
                      band.isBypassed = true;
                      _sendEqCommand(bandKey, 'gain', '0');
                    }
                  },
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'narrow', label: Text('Narrow')),
                  ButtonSegment(value: 'wide', label: Text('Wide')),
                ],
                selected: {band.band.value.isEmpty ? 'narrow' : band.band.value},
                onSelectionChanged: (Set<String> newSelection) {
                  _sendEqCommand(bandKey, 'band', newSelection.first);
                },
              ),
            ),
            const SizedBox(height: 12),
            _buildDiscreteSliderRow(
              label: 'Freq',
              value: band.frequency.value,
              allowedValues: allowedFreqs,
              unit: 'Hz',
              onChanged: (val) => _sendEqCommand(bandKey, 'frequency', val.toString()),
            ),
            _buildGainSliderRow(
              label: 'Gain',
              value: band.uiGain,
              onChanged: (val) {
                if (band.isBypassed) {
                  setState(() => band.storedGain = val);
                } else {
                  _sendEqCommand(bandKey, 'gain', val.toString());
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscreteSliderRow({
    required String label,
    required int value,
    required List<int> allowedValues,
    required String unit,
    required Function(int) onChanged,
  }) {
    int index = allowedValues.indexOf(value);
    if (index == -1) index = _findClosestIndex(value, allowedValues);

    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Expanded(
          child: Slider(
            value: index.toDouble(),
            min: 0,
            max: (allowedValues.length - 1).toDouble(),
            divisions: allowedValues.length > 1 ? allowedValues.length - 1 : 1,
            onChanged: (newIndex) => onChanged(allowedValues[newIndex.toInt()]),
          ),
        ),
        SizedBox(width: 65, child: Text('${allowedValues[index]} $unit', textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildGainSliderRow({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    final clampedValue = value.toDouble().clamp(-12.0, 12.0);
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Expanded(
          child: Slider(
            value: clampedValue,
            min: -12.0,
            max: 12.0,
            divisions: 24,
            onChanged: (val) => onChanged(val.toInt()),
          ),
        ),
        SizedBox(width: 65, child: Text('${clampedValue.toInt()} dB', textAlign: TextAlign.right)),
      ],
    );
  }

  int _findClosestIndex(int target, List<int> array) {
    if (array.isEmpty) return 0;
    int closestIndex = 0;
    int minDiff = (array[0] - target).abs();
    for (int i = 1; i < array.length; i++) {
      int diff = (array[i] - target).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }
}

// -----------------------------------------------------------------------------
// VISUAL EQ GRAPH PAINTER
// -----------------------------------------------------------------------------
class EqCurvePainter extends CustomPainter {
  final EqState eqState;

  final double minFreq = 20.0;
  final double maxFreq = 20000.0;
  final double maxDb = 15.0;
  final double minDb = -15.0;

  EqCurvePainter({required this.eqState});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), bgPaint);

    _drawGridAndLabels(canvas, size);

    // Calculate curve points
    final Path curvePath = Path();
    final int resolution = size.width.toInt();

    bool isFirst = true;

    for (int i = 0; i <= resolution; i++) {
      final double x = i.toDouble();
      final double freq = _xToFreq(x, size.width);

      double totalGain = 0;

      totalGain += _calcHighPassGain(freq);
      totalGain += _calcShelfGain(freq, eqState.lowShelf, true);
      totalGain += _calcShelfGain(freq, eqState.highShelf, false);
      totalGain += _calcParametricGain(freq, eqState.low);
      totalGain += _calcParametricGain(freq, eqState.mid);
      totalGain += _calcParametricGain(freq, eqState.high);

      final double y = _dbToY(totalGain, size.height);

      if (isFirst) {
        curvePath.moveTo(x, y);
        isFirst = false;
      } else {
        curvePath.lineTo(x, y);
      }
    }

    // Draw the glowing line
    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(curvePath, linePaint);

    // Gradient fill below the curve
    final fillPath = Path.from(curvePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.cyanAccent.withOpacity(0.4),
          Colors.cyanAccent.withOpacity(0.0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(fillPath, fillPaint);
  }

  // --- Grid drawing ---
  void _drawGridAndLabels(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.white12..strokeWidth = 1;
    final textStyle = const TextStyle(color: Colors.white54, fontSize: 10);

    final yZero = _dbToY(0, size.height);
    canvas.drawLine(Offset(0, yZero), Offset(size.width, yZero), Paint()..color = Colors.white30..strokeWidth = 1.5);

    _drawText(canvas, '+12', Offset(4, _dbToY(12, size.height) - 6), textStyle);
    _drawText(canvas, '-12', Offset(4, _dbToY(-12, size.height) - 6), textStyle);

    final List<int> gridFreqs = [50, 100, 500, 1000, 5000, 10000];
    for (var f in gridFreqs) {
      final x = _freqToX(f.toDouble(), size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);

      String label = f >= 1000 ? '${f ~/ 1000}k' : '$f';
      _drawText(canvas, label, Offset(x + 4, size.height - 16), textStyle);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, offset);
  }

  // --- Math Approximations for UI Drawing ---

  double _calcHighPassGain(double f) {
    if (!eqState.highPass.enabled.value) return 0.0;

    final double fc = eqState.highPass.frequency.value.toDouble();

    final int order = (fc <= 4.0) ? 1 : 2;

    // Standard Butterworth high-pass magnitude response formula
    // Gain(dB) = -10 * log10( 1 + (fc / f)^(2 * order) )
    return -10.0 * (log(1.0 + pow(fc / f, 2 * order)) / ln10);
  }

  double _calcShelfGain(double f, ShelfFilter filter, bool isLowShelf) {
    if (filter.isBypassed) return 0.0;

    final double gain = filter.gain.value.toDouble();
    if (gain == 0) return 0.0;

    final double fc = filter.frequency.value.toDouble();

    if (isLowShelf) {
      return gain / (1.0 + pow(f / fc, 3.0));
    } else {
      return gain / (1.0 + pow(fc / f, 3.0));
    }
  }

  double _calcParametricGain(double f, ParametricEqBand band) {
    if (band.isBypassed) return 0.0;

    final double gain = band.gain.value.toDouble();
    if (gain == 0) return 0.0;

    final double fc = band.frequency.value.toDouble();

    final double q = band.band.value == 'wide' ? 0.75 : 1.8;

    final double logDist = log(f / fc);
    return gain * exp(-(logDist * logDist) * (q * 4.0));
  }

  double _xToFreq(double x, double width) => minFreq * pow(maxFreq / minFreq, x / width);
  double _freqToX(double f, double width) => width * (log(f / minFreq) / log(maxFreq / minFreq));

  double _dbToY(double db, double height) {
    final double clampedDb = db.clamp(minDb, maxDb);
    final double normalized = 1.0 - ((clampedDb - minDb) / (maxDb - minDb));
    return normalized * height;
  }

  @override
  bool shouldRepaint(covariant EqCurvePainter oldDelegate) => true;
}