import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/volume_slider.dart';

class AdvancedControlsScreen extends StatelessWidget {
  final Esp32ConnectionService service;

  const AdvancedControlsScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Advanced Controls')),
      body: StreamBuilder<MixerState>(
        stream: service.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? MixerState();

          // -------------------------------------------------------------------
          // DERIVE UI STATE FROM HARDWARE FLAGS
          // -------------------------------------------------------------------
          final double inputGain = state.pga.gain.value.toDouble();
          final double outputVolume = state.speaker.volume.value.toDouble();

          // Derive Input Source
          final bool isXlr = state.routing.micToPga.value;
          final String inputSource = isXlr ? 'xlr' : 'jack';

          // Derive Input Mode (Only relevant for Jack)
          final bool isLineStereo = state.routing.lineStereoToPga.value;
          final String inputMode = isLineStereo ? 'stereo' : 'mono';

          // Derive Output Mode
          final bool isOutputMono = state.mixer.mono.value;
          final String outputMode = isOutputMono ? 'mono' : 'stereo';

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // ---------------------------------------------------------------
              // INPUT SECTION
              // ---------------------------------------------------------------
              const Text(
                'Input Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 16),

              const Text('Source Selection'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'xlr', label: Text('XLR')),
                  ButtonSegment(value: 'jack', label: Text('1/4" Jack')),
                ],
                selected: {inputSource},
                onSelectionChanged: (set) {
                  final String newSource = set.first;
                  if (newSource == 'xlr') {
                    service.sendCommands({
                      'routing.mic_to_pga': 't',
                      'routing.line_mono_to_pga': 'f',
                      'routing.line_stereo_to_pga': 'f',
                    });
                  } else {
                    // Switching to Jack: Restore the previously active mono/stereo mode
                    service.sendCommands({
                      'routing.mic_to_pga': 'f',
                      'routing.line_mono_to_pga': inputMode == 'mono'
                          ? 't'
                          : 'f',
                      'routing.line_stereo_to_pga': inputMode == 'stereo'
                          ? 't'
                          : 'f',
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              const Text('Input Mode'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'stereo',
                    label: Text('Stereo / Unbalanced'),
                  ),
                  ButtonSegment(value: 'mono', label: Text('Mono / Balanced')),
                ],
                selected: {inputMode},
                // Disable the mode switch when XLR is selected since XLR handles its own routing
                onSelectionChanged: isXlr
                    ? null
                    : (set) {
                        final String newMode = set.first;
                        service.sendCommands({
                          'routing.mic_to_pga': 'f',
                          'routing.line_mono_to_pga': newMode == 'mono'
                              ? 't'
                              : 'f',
                          'routing.line_stereo_to_pga': newMode == 'stereo'
                              ? 't'
                              : 'f',
                        });
                      },
              ),
              const SizedBox(height: 24),

              VolumeSlider(
                service: service,
                input: state.pga.gain,
                label: 'Input Gain',
                valueLabelDecimals: 2,
                min: -12.0,
                max: 35.25,
                stepSize: 0.75,
              ),

              const Divider(height: 48),

              // ---------------------------------------------------------------
              // OUTPUT SECTION
              // ---------------------------------------------------------------
              const Text(
                'Output Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 16),

              const Text('Output Mode'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'stereo',
                    label: Text('Stereo / Unbalanced'),
                  ),
                  ButtonSegment(value: 'mono', label: Text('Mono / Balanced')),
                ],
                selected: {outputMode},
                onSelectionChanged: (set) {
                  final String newMode = set.first;
                  if (newMode == 'mono') {
                    service.sendCommands({
                      'mixer.mono': 't',
                      'speaker.balanced': 't',
                    });
                  } else {
                    service.sendCommands({
                      'mixer.mono': 'f',
                      'speaker.balanced': 'f',
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              VolumeSlider(
                service: service,
                input: state.speaker.volume,
                label: 'Master Output Volume',
                min: -57,
                max: 6,
              ),
            ],
          );
        },
      ),
    );
  }
}
