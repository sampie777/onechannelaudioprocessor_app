import 'package:flutter/material.dart';

import '../../models/mixer_state.dart';
import '../../services/esp32_connection_service.dart';
import '../../widgets/hardware_volume_listener_widget.dart';
import '../../widgets/icons/eq_filter_icons.dart';
import 'interactive_eq_graph.dart';

class EqScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const EqScreen({super.key, required this.service});

  @override
  State<EqScreen> createState() => _EqScreenState();
}

class _EqScreenState extends State<EqScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('6-Band EQ')),
      body: HardwareVolumeListenerWidget(
        service: widget.service,
        child: StreamBuilder<MixerState>(
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
                  child: InteractiveEqGraph(
                    eq: eq,
                    spectrum: state.spectrum,
                    activeBandKey: _activeBandKey,
                    service: widget.service,
                    onBandSelected: (bandKey) {
                      setState(() => _activeBandKey = bandKey);
                    },
                    onLocalStateChanged: () {
                      setState(() {});
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
                      _buildShelfCard(
                        'Low Shelf',
                        'low_shelf',
                        eq.lowShelf,
                        EqBandsConfig.lowShelfFreqs,
                        const EqFilterIcon.lowShelf(size: 24),
                      ),
                      const SizedBox(height: 16),
                      _buildParametricCard(
                        'Low Band',
                        'low',
                        eq.low,
                        EqBandsConfig.lowFreqs,
                      ),
                      const SizedBox(height: 16),
                      _buildParametricCard(
                        'Mid Band',
                        'mid',
                        eq.mid,
                        EqBandsConfig.midFreqs,
                      ),
                      const SizedBox(height: 16),
                      _buildParametricCard(
                        'High Band',
                        'high',
                        eq.high,
                        EqBandsConfig.highFreqs,
                      ),
                      const SizedBox(height: 16),
                      _buildShelfCard(
                        'High Shelf',
                        'high_shelf',
                        eq.highShelf,
                        EqBandsConfig.highShelfFreqs,
                        const EqFilterIcon.highShelf(size: 24),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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
              ? [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ]
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
                  const EqFilterIcon.highPass(size: 24),
                  const SizedBox(width: 12),
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
                allowedValues: EqBandsConfig.highPassFreqs,
                unit: 'Hz',
                onChanged: (val) {
                  setState(() => _activeBandKey = bandKey);
                  widget.service.sendCommands({
                    filter.frequency.command: val.toString(),
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShelfCard(
      String title,
      String bandKey,
      ShelfFilter filter,
      List<int> allowedFreqs,
      Widget icon,
      ) {
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
                  icon,
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset Band',
                    onPressed: () =>
                        _resetBand(bandKey, filter, filter.defaultFreq),
                  ),
                  Switch(
                    value: !filter.isBypassed,
                    onChanged: (enabled) {
                      if (enabled) {
                        filter.isBypassed = false;
                        widget.service.sendCommands({
                          filter.gain.command: filter.storedGain.toString(),
                        });
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
                  widget.service.sendCommands({
                    filter.frequency.command: val.toString(),
                  });
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
                    widget.service.sendCommands({
                      filter.gain.command: val.toString(),
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParametricCard(
      String title,
      String bandKey,
      ParametricEqBand filter,
      List<int> allowedFreqs,
      ) {
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
                  const EqFilterIcon.bandPass(size: 24),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset Band',
                    onPressed: () => _resetBand(
                      bandKey,
                      filter,
                      filter.defaultFreq,
                      isParametric: true,
                    ),
                  ),
                  Switch(
                    value: !filter.isBypassed,
                    onChanged: (enabled) {
                      if (enabled) {
                        filter.isBypassed = false;
                        widget.service.sendCommands({
                          filter.gain.command: filter.storedGain.toString(),
                        });
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
                  selected: {
                    filter.band.value.isEmpty ? 'narrow' : filter.band.value,
                  },
                  onSelectionChanged: (Set<String> newSelection) {
                    widget.service.sendCommands({
                      filter.band.command: newSelection.first,
                    });
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
                  widget.service.sendCommands({
                    filter.frequency.command: val.toString(),
                  });
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
                    widget.service.sendCommands({
                      filter.gain.command: val.toString(),
                    });
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
    if (index == -1) {
      index = EqBandsConfig.findClosestIndex(value, allowedValues);
    }

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Slider(
            value: index.toDouble(),
            min: 0,
            max: (allowedValues.length - 1).toDouble(),
            divisions: allowedValues.length > 1 ? allowedValues.length - 1 : 1,
            onChanged: (newIndex) => onChanged(allowedValues[newIndex.toInt()]),
          ),
        ),
        SizedBox(
          width: 65,
          child: Text(
            '${allowedValues[index]} $unit',
            textAlign: TextAlign.right,
          ),
        ),
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
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double fraction = (0.0 - min) / (max - min);
              const double trackPadding = 26.0;
              final double trackWidth =
                  constraints.maxWidth - (trackPadding * 2);
              final double leftPosition =
                  trackPadding + (trackWidth * fraction);

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
        SizedBox(
          width: 65,
          child: Text('${clampedValue.toInt()} dB', textAlign: TextAlign.right),
        ),
      ],
    );
  }
}