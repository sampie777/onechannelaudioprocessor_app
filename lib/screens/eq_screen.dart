import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // Graph Constants for Coordinate Mapping
  static const double minFreq = 20.0;
  static const double maxFreq = 20000.0;
  static const double maxDb = 15.0;
  static const double minDb = -15.0;

  String? _activeBandKey;

  void _resetBand(
      String band,
      dynamic filter,
      int defaultFreq, {
        bool isParametric = false,
      }) {
    final Map<String, String> commands = {};

    if (filter is ShelfFilter || filter is ParametricEqBand) {
      filter.isBypassed = false;
      filter.storedGain = 0;
    }

    if (filter is HighPassFilter) {
      commands.addAll({
        filter.frequency.command: defaultFreq.toString(),
        filter.enabled.command: 't',
      });
    } else if (filter is ShelfFilter) {
      commands.addAll({
        filter.frequency.command: defaultFreq.toString(),
        filter.gain.command: '0',
      });
    } else if (filter is ParametricEqBand) {
      commands.addAll({
        filter.frequency.command: defaultFreq.toString(),
        filter.gain.command: '0',
        filter.band.command: 'narrow',
      });
    }

    widget.service.sendCommands(commands);
  }

  // --- Graph Interaction Handlers ---

  double _freqToX(double f, double width) =>
      width * (log(f / minFreq) / log(maxFreq / minFreq));

  double _xToFreq(double x, double width) =>
      minFreq * pow(maxFreq / minFreq, x / width);

  double _dbToY(double db, double height) {
    final double clampedDb = db.clamp(minDb, maxDb);
    final double normalized = 1.0 - ((clampedDb - minDb) / (maxDb - minDb));
    return normalized * height;
  }

  double _yToDb(double y, double height) {
    final double normalized = 1.0 - (y / height);
    return (minDb + normalized * (maxDb - minDb)).clamp(-12.0, 12.0);
  }

  void _handleGraphInteractionStart(Offset touch, Size size, EqState eq) {
    // Find the closest band to the touch point
    final Map<String, Offset> bandPositions = {
      'high_pass': Offset(
          _freqToX(eq.highPass.frequency.value.toDouble(), size.width),
          _dbToY(0, size.height)),
      'low_shelf': Offset(
          _freqToX(eq.lowShelf.frequency.value.toDouble(), size.width),
          _dbToY(eq.lowShelf.uiGain.toDouble(), size.height)),
      'low': Offset(
          _freqToX(eq.low.frequency.value.toDouble(), size.width),
          _dbToY(eq.low.uiGain.toDouble(), size.height)),
      'mid': Offset(
          _freqToX(eq.mid.frequency.value.toDouble(), size.width),
          _dbToY(eq.mid.uiGain.toDouble(), size.height)),
      'high': Offset(
          _freqToX(eq.high.frequency.value.toDouble(), size.width),
          _dbToY(eq.high.uiGain.toDouble(), size.height)),
      'high_shelf': Offset(
          _freqToX(eq.highShelf.frequency.value.toDouble(), size.width),
          _dbToY(eq.highShelf.uiGain.toDouble(), size.height)),
    };

    String closest = 'high_pass';
    double minDist = double.infinity;

    for (var entry in bandPositions.entries) {
      final double dist = (entry.value - touch).distance;
      if (dist < minDist) {
        minDist = dist;
        closest = entry.key;
      }
    }

    setState(() {
      _activeBandKey = closest;
    });
  }

  void _handleGraphPanUpdate(Offset touch, Size size, EqState eq) {
    if (_activeBandKey == null) return;

    final double rawFreq = _xToFreq(touch.dx, size.width);
    final double rawDb = _yToDb(touch.dy, size.height);

    List<int> allowedFreqs;
    dynamic filter;
    bool isGainAllowed = true;

    switch (_activeBandKey) {
      case 'high_pass':
        allowedFreqs = _highPassFreqs;
        filter = eq.highPass;
        isGainAllowed = false;
        break;
      case 'low_shelf':
        allowedFreqs = _lowShelfFreqs;
        filter = eq.lowShelf;
        break;
      case 'low':
        allowedFreqs = _lowFreqs;
        filter = eq.low;
        break;
      case 'mid':
        allowedFreqs = _midFreqs;
        filter = eq.mid;
        break;
      case 'high':
        allowedFreqs = _highFreqs;
        filter = eq.high;
        break;
      case 'high_shelf':
        allowedFreqs = _highShelfFreqs;
        filter = eq.highShelf;
        break;
      default:
        return;
    }

    final int closestFreq = allowedFreqs[_findClosestIndex(rawFreq.toInt(), allowedFreqs)];
    final int clampedDb = rawDb.round();

    final Map<String, String> cmds = {};
    bool freqChanged = false;

    // Check if frequency snapped to a new value
    if (filter.frequency.value != closestFreq) {
      cmds[filter.frequency.command] = closestFreq.toString();
      freqChanged = true;
    }

    if (isGainAllowed) {
      if (filter.isBypassed) {
        // If bypassed, only update the UI state locally
        if (filter.storedGain != clampedDb) {
          setState(() => filter.storedGain = clampedDb);
        }
      } else {
        // If active, send command to the mixer
        if (filter.gain.value != clampedDb) {
          cmds[filter.gain.command] = clampedDb.toString();
        }
      }
    }

    if (cmds.isNotEmpty) {
      widget.service.sendCommands(cmds);
    }

    if (freqChanged) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('6-Band EQ')),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, constraints.maxHeight);
                    return GestureDetector(
                      onPanDown: (details) => _handleGraphInteractionStart(details.localPosition, size, eq),
                      onPanUpdate: (details) => _handleGraphPanUpdate(details.localPosition, size, eq),
                      child: CustomPaint(
                        size: size,
                        painter: EqCurvePainter(
                          eqState: eq,
                          activeBandKey: _activeBandKey,
                          freqToX: _freqToX,
                          dbToY: _dbToY,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, thickness: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildHighPassCard('high_pass', eq.highPass),
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

  Widget _buildFocusableCard({required String bandKey, required Widget child}) {
    final bool isActive = _activeBandKey == bandKey;
    return GestureDetector(
      onTap: () => setState(() => _activeBandKey = bandKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.cyanAccent : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.1), blurRadius: 8, spreadRadius: 1)]
              : [],
        ),
        child: child,
      ),
    );
  }

  Widget _buildHighPassCard(String bandKey, HighPassFilter filter) {
    return _buildFocusableCard(
      bandKey: bandKey,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'High Pass Filter',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset Band',
                    onPressed: () => widget.service.sendCommands({
                      filter.enabled.command: 't',
                      filter.frequency.command: filter.defaultFreq.toString(),
                    }),
                  ),
                  Switch(
                    value: filter.enabled.value,
                    onChanged: (val) => widget.service.sendCommands({
                      filter.enabled.command: val ? 't' : 'f',
                    }),
                  ),
                ],
              ),
              _buildDiscreteSliderRow(
                label: 'Freq',
                value: filter.frequency.value,
                allowedValues: _highPassFreqs,
                unit: 'Hz',
                onChanged: (val) {
                  setState(() => _activeBandKey = bandKey);
                  widget.service.sendCommands({filter.frequency.command: val.toString()});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShelfCard(String title, String bandKey, ShelfFilter filter, List<int> allowedFreqs) {
    return _buildFocusableCard(
      bandKey: bandKey,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
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
                    onPressed: () => _resetBand(bandKey, filter, filter.defaultFreq),
                  ),
                  Switch(
                    value: !filter.isBypassed,
                    onChanged: (enabled) {
                      if (enabled) {
                        filter.isBypassed = false;
                        widget.service.sendCommands({filter.gain.command: filter.storedGain.toString()});
                      } else {
                        filter.storedGain = filter.uiGain;
                        filter.isBypassed = true;
                        widget.service.sendCommands({filter.gain.command: '0'});
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
                onChanged: (val) {
                  setState(() => _activeBandKey = bandKey);
                  widget.service.sendCommands({filter.frequency.command: val.toString()});
                },
              ),
              _buildGainSliderRow(
                label: 'Gain',
                value: filter.uiGain,
                onChanged: (val) {
                  setState(() => _activeBandKey = bandKey);
                  if (filter.isBypassed) {
                    setState(() => filter.storedGain = val);
                  } else {
                    widget.service.sendCommands({filter.gain.command: val.toString()});
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParametricCard(String title, String bandKey, ParametricEqBand filter, List<int> allowedFreqs) {
    return _buildFocusableCard(
      bandKey: bandKey,
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
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
                    onPressed: () => _resetBand(bandKey, filter, filter.defaultFreq, isParametric: true),
                  ),
                  Switch(
                    value: !filter.isBypassed,
                    onChanged: (enabled) {
                      if (enabled) {
                        filter.isBypassed = false;
                        widget.service.sendCommands({filter.gain.command: filter.storedGain.toString()});
                      } else {
                        filter.storedGain = filter.uiGain;
                        filter.isBypassed = true;
                        widget.service.sendCommands({filter.gain.command: '0'});
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
                  selected: {filter.band.value.isEmpty ? 'narrow' : filter.band.value},
                  onSelectionChanged: (Set<String> newSelection) {
                    widget.service.sendCommands({filter.band.command: newSelection.first});
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildDiscreteSliderRow(
                label: 'Freq',
                value: filter.frequency.value,
                allowedValues: allowedFreqs,
                unit: 'Hz',
                onChanged: (val) {
                  setState(() => _activeBandKey = bandKey);
                  widget.service.sendCommands({filter.frequency.command: val.toString()});
                },
              ),
              _buildGainSliderRow(
                label: 'Gain',
                value: filter.uiGain,
                onChanged: (val) {
                  setState(() => _activeBandKey = bandKey);
                  if (filter.isBypassed) {
                    setState(() => filter.storedGain = val);
                  } else {
                    widget.service.sendCommands({filter.gain.command: val.toString()});
                  }
                },
              ),
            ],
          ),
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
    const double min = -12.0;
    const double max = 12.0;
    final clampedValue = value.toDouble().clamp(min, max);
    return Row(
      children: [
        SizedBox(width: 50, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double fraction = (0.0 - min) / (max - min);
              const double trackPadding = 26.0;
              final double trackWidth = constraints.maxWidth - (trackPadding * 2);
              final double leftPosition = trackPadding + (trackWidth * fraction);

              return Stack(
                alignment: Alignment.center,
                children: [
                  if (min <= 0 && max >= 0)
                    Positioned(
                      left: leftPosition - 1,
                      child: Container(
                        width: 2,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(150),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  Slider(
                    value: clampedValue.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: (max - min).toInt(),
                    onChanged: (val) => onChanged(val.toInt()),
                  ),
                ],
              );
            },
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
  final String? activeBandKey;

  final double Function(double, double) freqToX;
  final double Function(double, double) dbToY;

  EqCurvePainter({
    required this.eqState,
    required this.activeBandKey,
    required this.freqToX,
    required this.dbToY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bgPaint,
    );

    _drawGridAndLabels(canvas, size);

    final Path activePath = Path();
    final Path previewPath = Path();
    final int resolution = size.width.toInt();

    bool isFirst = true;

    for (int i = 0; i <= resolution; i++) {
      final double x = i.toDouble();
      final double freq = _xToFreqLocal(x, size.width);

      double activeGain = 0;
      activeGain += _calcHighPassGain(freq);
      activeGain += _calcShelfGain(freq, eqState.lowShelf, true);
      activeGain += _calcShelfGain(freq, eqState.highShelf, false);
      activeGain += _calcParametricGain(freq, eqState.low);
      activeGain += _calcParametricGain(freq, eqState.mid);
      activeGain += _calcParametricGain(freq, eqState.high);

      double previewGain = 0;
      previewGain += _calcHighPassGain(freq, forceActive: true);
      previewGain += _calcShelfGain(freq, eqState.lowShelf, true, useUiGain: true);
      previewGain += _calcShelfGain(freq, eqState.highShelf, false, useUiGain: true);
      previewGain += _calcParametricGain(freq, eqState.low, useUiGain: true);
      previewGain += _calcParametricGain(freq, eqState.mid, useUiGain: true);
      previewGain += _calcParametricGain(freq, eqState.high, useUiGain: true);

      final double yActive = dbToY(activeGain, size.height);
      final double yPreview = dbToY(previewGain, size.height);

      if (isFirst) {
        activePath.moveTo(x, yActive);
        previewPath.moveTo(x, yPreview);
        isFirst = false;
      } else {
        activePath.lineTo(x, yActive);
        previewPath.lineTo(x, yPreview);
      }
    }

    final previewLinePaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(previewPath, previewLinePaint);

    final previewFillPath = Path.from(previewPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final previewFillPaint = Paint()..color = Colors.white10;
    canvas.drawPath(previewFillPath, previewFillPaint);

    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(activePath, linePaint);

    final fillPath = Path.from(activePath)
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

    // Draw small inactive indicator dots for all unselected bands
    _drawSmallDot(canvas, size, 'high_pass', eqState.highPass.frequency.value.toDouble(), 0.0, eqState.highPass.enabled.value);
    _drawSmallDot(canvas, size, 'low_shelf', eqState.lowShelf.frequency.value.toDouble(), eqState.lowShelf.uiGain.toDouble(), !eqState.lowShelf.isBypassed);
    _drawSmallDot(canvas, size, 'low', eqState.low.frequency.value.toDouble(), eqState.low.uiGain.toDouble(), !eqState.low.isBypassed);
    _drawSmallDot(canvas, size, 'mid', eqState.mid.frequency.value.toDouble(), eqState.mid.uiGain.toDouble(), !eqState.mid.isBypassed);
    _drawSmallDot(canvas, size, 'high', eqState.high.frequency.value.toDouble(), eqState.high.uiGain.toDouble(), !eqState.high.isBypassed);
    _drawSmallDot(canvas, size, 'high_shelf', eqState.highShelf.frequency.value.toDouble(), eqState.highShelf.uiGain.toDouble(), !eqState.highShelf.isBypassed);

    // Draw the active band dot on top
    if (activeBandKey != null) {
      _drawActiveBandDot(canvas, size);
    }
  }

  void _drawSmallDot(Canvas canvas, Size size, String bandKey, double freq, double db, bool isActive) {
    if (bandKey == activeBandKey) return; // Skip the active band since it gets the large dot

    final double x = freqToX(freq, size.width);
    final double y = dbToY(db, size.height);

    final Paint fillPaint = Paint()
      ..color = isActive ? Colors.cyanAccent.withOpacity(0.5) : Colors.white38
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(x, y), 4.0, fillPaint);
  }

  void _drawActiveBandDot(Canvas canvas, Size size) {
    double freq = 1000;
    double db = 0;
    bool isActive = true;

    switch (activeBandKey) {
      case 'high_pass':
        freq = eqState.highPass.frequency.value.toDouble();
        isActive = eqState.highPass.enabled.value;
        break;
      case 'low_shelf':
        freq = eqState.lowShelf.frequency.value.toDouble();
        db = eqState.lowShelf.uiGain.toDouble();
        isActive = !eqState.lowShelf.isBypassed;
        break;
      case 'low':
        freq = eqState.low.frequency.value.toDouble();
        db = eqState.low.uiGain.toDouble();
        isActive = !eqState.low.isBypassed;
        break;
      case 'mid':
        freq = eqState.mid.frequency.value.toDouble();
        db = eqState.mid.uiGain.toDouble();
        isActive = !eqState.mid.isBypassed;
        break;
      case 'high':
        freq = eqState.high.frequency.value.toDouble();
        db = eqState.high.uiGain.toDouble();
        isActive = !eqState.high.isBypassed;
        break;
      case 'high_shelf':
        freq = eqState.highShelf.frequency.value.toDouble();
        db = eqState.highShelf.uiGain.toDouble();
        isActive = !eqState.highShelf.isBypassed;
        break;
    }

    final double x = freqToX(freq, size.width);
    final double y = dbToY(db, size.height);

    final Paint glowPaint = Paint()
      ..color = isActive ? Colors.cyanAccent.withOpacity(0.3) : Colors.white24
      ..style = PaintingStyle.fill;

    final Paint fillPaint = Paint()
      ..color = isActive ? Colors.cyanAccent : Colors.grey.shade400
      ..style = PaintingStyle.fill;

    final Paint outlinePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(Offset(x, y), 16.0, glowPaint);
    canvas.drawCircle(Offset(x, y), 8.0, fillPaint);
    canvas.drawCircle(Offset(x, y), 8.0, outlinePaint);
  }

  void _drawGridAndLabels(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    final textStyle = const TextStyle(color: Colors.white54, fontSize: 10);

    final yZero = dbToY(0, size.height);
    canvas.drawLine(Offset(0, yZero), Offset(size.width, yZero), Paint()..color = Colors.white30..strokeWidth = 1.5);

    _drawText(canvas, '+12', Offset(4, dbToY(12, size.height) - 6), textStyle);
    _drawText(canvas, '-12', Offset(4, dbToY(-12, size.height) - 6), textStyle);

    final List<int> gridFreqs = [50, 100, 500, 1000, 5000, 10000];
    for (var f in gridFreqs) {
      final x = freqToX(f.toDouble(), size.width);
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

  double _xToFreqLocal(double x, double width) => 20.0 * pow(20000.0 / 20.0, x / width);

  double _calcHighPassGain(double f, {bool forceActive = false}) {
    if (!forceActive && !eqState.highPass.enabled.value) return 0.0;
    final double fc = eqState.highPass.frequency.value.toDouble();
    final int order = (fc <= 4.0) ? 1 : 2;
    return -10.0 * (log(1.0 + pow(fc / f, 2 * order)) / ln10);
  }

  double _calcShelfGain(double f, ShelfFilter filter, bool isLowShelf, {bool useUiGain = false}) {
    if (!useUiGain && filter.isBypassed) return 0.0;
    final double gain = useUiGain ? filter.uiGain.toDouble() : filter.gain.value.toDouble();
    if (gain == 0) return 0.0;
    final double fc = filter.frequency.value.toDouble();
    if (isLowShelf) {
      return gain / (1.0 + pow(f / fc, 3.0));
    } else {
      return gain / (1.0 + pow(fc / f, 3.0));
    }
  }

  double _calcParametricGain(double f, ParametricEqBand band, {bool useUiGain = false}) {
    if (!useUiGain && band.isBypassed) return 0.0;
    final double gain = useUiGain ? band.uiGain.toDouble() : band.gain.value.toDouble();
    if (gain == 0) return 0.0;
    final double fc = band.frequency.value.toDouble();
    final double q = band.band.value == 'wide' ? 0.75 : 1.8;
    final double logDist = log(f / fc);
    return gain * exp(-(logDist * logDist) * (q * 4.0));
  }

  @override
  bool shouldRepaint(covariant EqCurvePainter oldDelegate) => true;
}