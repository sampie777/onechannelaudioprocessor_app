import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';

class TestToneGeneratorWidget extends StatelessWidget {
  final Esp32ConnectionService service;
  final GeneratorState generator;

  static const double _minFreq = 20.0;
  static const double _maxFreq = 20000.0;

  const TestToneGeneratorWidget({
    super.key,
    required this.service,
    required this.generator,
  });

  /// Converts a logarithmic frequency in Hz to a normalized 0.0 – 1.0 slider fraction
  double _freqToFraction(double freq) {
    final double clamped = freq.clamp(_minFreq, _maxFreq);
    return (math.log(clamped) - math.log(_minFreq)) /
        (math.log(_maxFreq) - math.log(_minFreq));
  }

  /// Converts a normalized 0.0 – 1.0 slider fraction back to logarithmic frequency in Hz
  double _fractionToFreq(double fraction) {
    final double logFreq = math.log(_minFreq) +
        fraction * (math.log(_maxFreq) - math.log(_minFreq));
    return math.exp(logFreq);
  }

  /// Formats frequency cleanly (e.g. "250 Hz", "1.5 kHz", "10.0 kHz")
  String _formatFrequency(int hz) {
    if (hz >= 1000) {
      final double khz = hz / 1000.0;
      return '${khz >= 10 ? khz.toStringAsFixed(0) : khz.toStringAsFixed(1)} kHz';
    }
    return '$hz Hz';
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = generator.enabled.value;
    final String activeType = generator.type.value;
    final double volume = generator.volume.value.clamp(-127.0, 0.0);
    final int frequency = generator.frequency.value;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Enable / Disable Switch
            Row(
              children: [
                Icon(
                  Icons.waves,
                  color: isEnabled ? Colors.cyanAccent : Colors.grey,
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Test Tone Generator',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isEnabled,
                  activeColor: Colors.cyanAccent,
                  onChanged: (val) {
                    service.sendCommands({
                      generator.enabled.command: val ? 't' : 'f',
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tone Type Selector
            const Text(
              'Tone Type',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'sine',
                    label: Text('Sine'),
                  ),
                  ButtonSegment(
                    value: 'white_noise',
                    label: Text('White Noise'),
                  ),
                  ButtonSegment(
                    value: 'pink_noise',
                    label: Text('Pink Noise'),
                  ),
                ],
                selected: {
                  ['sine', 'white_noise', 'pink_noise'].contains(activeType)
                      ? activeType
                      : 'sine'
                },
                onSelectionChanged: (Set<String> selected) {
                  service.sendCommands({
                    generator.type.command: selected.first,
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Logarithmic Frequency Slider (Only relevant for Sine wave)
            if (activeType == 'sine') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Frequency',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _formatFrequency(frequency),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _freqToFraction(frequency.toDouble()),
                min: 0.0,
                max: 1.0,
                activeColor: Colors.cyan,
                onChanged: (fraction) {
                  final double calculatedFreq = _fractionToFreq(fraction);

                  // Round to clean steps based on frequency magnitude
                  final int roundedFreq = calculatedFreq < 100
                      ? calculatedFreq.round()
                      : calculatedFreq < 1000
                      ? ((calculatedFreq / 5).round() * 5)
                      : calculatedFreq < 10000
                      ? ((calculatedFreq / 50).round() * 50)
                      : ((calculatedFreq / 500).round() * 500);

                  service.sendCommands({
                    generator.frequency.command: roundedFreq.toString(),
                  });
                },
              ),
              const SizedBox(height: 8),
            ],

            // Volume Slider (-127 dB to 0 dB)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Generator Volume',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  '${volume.toStringAsFixed(1)} dBFS',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
            Slider(
              value: volume,
              min: -127.0,
              max: 0.0,
              activeColor: Colors.cyan,
              onChanged: (val) {
                final double rounded = (val * 2).round() / 2.0;
                service.sendCommands({
                  generator.volume.command: rounded.toStringAsFixed(1),
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}