import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';

class EqScreen extends StatelessWidget {
  final Esp32ConnectionService service;

  const EqScreen({super.key, required this.service});

  // Allowed frequencies strictly defined by the NAU88 hardware registers
  static const List<int> _highPassFreqs = [4, 122, 153, 156, 245, 306, 392, 490, 612];
  static const List<int> _lowShelfFreqs = [80, 105, 135, 175];
  static const List<int> _lowFreqs = [230, 300, 385, 500];
  static const List<int> _midFreqs = [650, 850, 1100, 1400];
  static const List<int> _highFreqs = [1800, 2400, 3200, 4100];
  static const List<int> _highShelfFreqs = [5300, 6900, 9000, 11700];

  // Helper to send commands easily
  void _sendEqCommand(String band, String param, String value) {
    service.sendCommands({'eq.$band.$param': value});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('6-Band EQ'),
      ),
      body: StreamBuilder<MixerState>(
        stream: service.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data;
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final eq = state.eq;

          return ListView(
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
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARD BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildHighPassCard(HighPassFilter hpf) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('High Pass Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Switch(
                  value: hpf.enabled.value,
                  onChanged: (val) => _sendEqCommand('high_pass', 'enabled', val ? 't' : 'f'),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDiscreteSliderRow(
              label: 'Freq',
              value: filter.frequency.value,
              allowedValues: allowedFreqs,
              unit: 'Hz',
              onChanged: (val) => _sendEqCommand(bandKey, 'frequency', val.toString()),
            ),
            _buildGainSliderRow(
              label: 'Gain',
              value: filter.gain.value,
              onChanged: (val) => _sendEqCommand(bandKey, 'gain', val.toString()),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'narrow', label: Text('Narrow')),
                    ButtonSegment(value: 'wide', label: Text('Wide')),
                  ],
                  // Fallback to 'narrow' if the initial state hasn't populated yet
                  selected: {band.band.value.isEmpty ? 'narrow' : band.band.value},
                  onSelectionChanged: (Set<String> newSelection) {
                    _sendEqCommand(bandKey, 'band', newSelection.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDiscreteSliderRow(
              label: 'Freq',
              value: band.frequency.value,
              allowedValues: allowedFreqs,
              unit: 'Hz',
              onChanged: (val) => _sendEqCommand(bandKey, 'frequency', val.toString()),
            ),
            _buildGainSliderRow(
              label: 'Gain',
              value: band.gain.value,
              onChanged: (val) => _sendEqCommand(bandKey, 'gain', val.toString()),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HARDWARE-CONSTRAINED UI WIDGETS
  // ---------------------------------------------------------------------------

  // Maps an array of allowed values to standard slider steps
  Widget _buildDiscreteSliderRow({
    required String label,
    required int value,
    required List<int> allowedValues,
    required String unit,
    required Function(int) onChanged,
  }) {
    // Gracefully handle uninitialized/stale state by finding the closest allowed match
    int index = allowedValues.indexOf(value);
    if (index == -1) {
      index = _findClosestIndex(value, allowedValues);
    }

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Slider(
            value: index.toDouble(),
            min: 0,
            max: (allowedValues.length - 1).toDouble(),
            divisions: allowedValues.length > 1 ? allowedValues.length - 1 : 1,
            onChanged: (newIndex) {
              onChanged(allowedValues[newIndex.toInt()]);
            },
          ),
        ),
        SizedBox(
          width: 65,
          child: Text('${allowedValues[index]} $unit', textAlign: TextAlign.right),
        ),
      ],
    );
  }

  // Restricts gain specifically between -12dB and +12dB per NAU88 limitations
  Widget _buildGainSliderRow({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    final clampedValue = value.toDouble().clamp(-12.0, 12.0);

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Slider(
            value: clampedValue,
            min: -12.0,
            max: 12.0,
            divisions: 24, // 24 discrete 1dB steps from -12 to +12
            onChanged: (val) => onChanged(val.toInt()),
          ),
        ),
        SizedBox(
          width: 65,
          child: Text('${clampedValue.toInt()} dB', textAlign: TextAlign.right),
        ),
      ],
    );
  }

  // Helper to ensure the UI doesn't crash if the app boots with a value of 0
  // before the ESP32 sends the first payload over the network.
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