import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:onechannelaudioprocessor/widgets/icons/jack_icon.dart';
import 'package:onechannelaudioprocessor/widgets/icons/xlr_icon.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/hardware_volume_listener_widget.dart';
import '../widgets/icons/balancing_icons.dart';
import '../widgets/icons/ground_icon.dart';
import '../widgets/volume_slider.dart';
import '../widgets/vu_meter/horizontal_audio_meter.dart';

class InputOutputControlScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const InputOutputControlScreen({super.key, required this.service});

  @override
  State<InputOutputControlScreen> createState() =>
      _InputOutputControlScreenState();
}

class _InputOutputControlScreenState extends State<InputOutputControlScreen> {
  bool? wasLineMono;
  bool? wasOutputBalanced;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input / Output Control')),
      body: HardwareVolumeListenerWidget(
        service: widget.service,
        child: StreamBuilder<MixerState>(
          stream: widget.service.stateStream,
          builder: (context, snapshot) {
            final state = snapshot.data ?? MixerState();

            final bool isXlr = state.routing.micToPga.value;
            final String inputSource = isXlr ? 'xlr' : 'jack';

            final bool isLineStereo = state.routing.lineStereoToPga.value;
            final String inputMode = isLineStereo ? 'stereo' : 'mono';

            final bool isOutputMono = state.mixer.mono.value;
            final String outputChannelMode = isOutputMono ? 'mono' : 'stereo';

            final bool isOutputBalanced = state.speaker.balanced.value;
            final String outputBalanceMode = (isOutputMono && isOutputBalanced)
                ? 'balanced'
                : 'unbalanced';

            final bool isGroundLifted = state.device.groundLiftEnabled.value;

            if (!isXlr && wasLineMono == null) {
              wasLineMono = state.routing.lineMonoToPga.value;
            }

            if (isOutputMono && wasOutputBalanced == null) {
              wasOutputBalanced = isOutputBalanced;
            }

            return ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Text(
                  'Input Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Source'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  segments: [
                    ButtonSegment(
                      value: 'xlr',
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              child: XlrIcon(
                                size: 36,
                                color: state.device.inputXlrDetected.value
                                    ? Colors.greenAccent
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'XLR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ButtonSegment(
                      value: 'jack',
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 40,
                              child: JackIcon(
                                size: 28,
                                color: state.device.inputJackDetected.value
                                    ? Colors.greenAccent
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '1/4" Jack',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  selected: {inputSource},
                  onSelectionChanged: (set) {
                    final String newSource = set.first;
                    if (newSource == 'xlr') {
                      widget.service.sendCommands({
                        state.routing.micToPga.command: 't',
                        state.routing.lineMonoToPga.command: 'f',
                        state.routing.lineStereoToPga.command: 'f',
                      });
                    } else {
                      bool isMono = inputMode == 'mono';
                      if (isXlr && wasLineMono != null) {
                        isMono = wasLineMono!;
                      }

                      widget.service.sendCommands({
                        state.routing.micToPga.command: 'f',
                        state.routing.lineMonoToPga.command: isMono ? 't' : 'f',
                        state.routing.lineStereoToPga.command: !isMono
                            ? 't'
                            : 'f',
                      });

                      wasLineMono = isMono;
                    }
                  },
                ),
                const SizedBox(height: 24),

                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'stereo',
                      tooltip: !isXlr
                          ? null
                          : 'Stereo is only available for the 1/4" TRS Jack input. Although it is possible to send a stereo signal over a single XLR cable, it is in the same category as walking outside on your socks. Therefore, by not supporting it, we encourage good behaviour.',
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.rotate(
                                  angle: 180 * math.pi / 180,
                                  child: Icon(
                                    Icons.volume_up,
                                    size: 26,
                                    color: inputMode == 'stereo'
                                        ? Colors.cyanAccent
                                        : null,
                                  ),
                                ),
                                Icon(
                                  Icons.volume_up,
                                  size: 26,
                                  color: inputMode == 'stereo'
                                      ? Colors.cyanAccent
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Stereo / Unbalanced',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    ButtonSegment(
                      value: 'mono',
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.volume_up,
                                  size: 26,
                                  color:
                                      inputMode == 'mono' &&
                                          inputSource == 'jack'
                                      ? Colors.cyanAccent
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Mono / Balanced',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  selected: {inputMode},
                  onSelectionChanged: isXlr
                      ? null
                      : (set) {
                          final String newMode = set.first;
                          final bool isMono = newMode == 'mono';
                          widget.service.sendCommands({
                            state.routing.micToPga.command: 'f',
                            state.routing.lineMonoToPga.command: isMono
                                ? 't'
                                : 'f',
                            state.routing.lineStereoToPga.command: !isMono
                                ? 't'
                                : 'f',
                          });

                          wasLineMono = isMono;
                        },
                ),
                const SizedBox(height: 32),

                VolumeSlider(
                  service: widget.service,
                  input: state.pga.gain,
                  label: 'Input Gain',
                  valueLabelDecimals: 2,
                  min: -12.0,
                  max: 35.25,
                  stepSize: 0.75,
                ),

                const SizedBox(height: 20),
                HorizontalAudioMeterWidget(
                  peak: state.peakOverPeriod,
                  showTicks: true,
                ),

                const Divider(height: 64),

                const Text(
                  'Output Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
                  ),
                ),
                const SizedBox(height: 16),

                const Text('Mode'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'stereo',
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.rotate(
                                  angle: 180 * math.pi / 180,
                                  child: Icon(
                                    Icons.volume_up,
                                    size: 26,
                                    color: outputChannelMode == 'stereo'
                                        ? Colors.cyanAccent
                                        : null,
                                  ),
                                ),
                                Icon(
                                  Icons.volume_up,
                                  size: 26,
                                  color: outputChannelMode == 'stereo'
                                      ? Colors.cyanAccent
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Stereo', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                    ButtonSegment(
                      value: 'mono',
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.volume_up,
                                  size: 26,
                                  color: outputChannelMode == 'mono'
                                      ? Colors.cyanAccent
                                      : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Mono', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ],
                  selected: {outputChannelMode},
                  onSelectionChanged: (set) {
                    final String newMode = set.first;
                    if (newMode == 'mono') {
                      // Restore previous balancing preference or default to balanced
                      final bool restoreBalanced = wasOutputBalanced ?? true;
                      widget.service.sendCommands({
                        state.mixer.mono.command: 't',
                        state.speaker.balanced.command: restoreBalanced
                            ? 't'
                            : 'f',
                      });
                      wasOutputBalanced = restoreBalanced;
                    } else {
                      // Stereo is strictly unbalanced
                      widget.service.sendCommands({
                        state.mixer.mono.command: 'f',
                        state.speaker.balanced.command: 'f',
                      });
                    }
                  },
                ),
                const SizedBox(height: 24),

                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'unbalanced',
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UnbalancedSignalIcon(
                              size: 24,
                              color:
                                  outputBalanceMode == 'unbalanced' &&
                                      outputChannelMode == 'mono'
                                  ? Colors.cyanAccent
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text('Unbalanced', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),

                    ButtonSegment(
                      value: 'balanced',
                      tooltip: !isOutputMono
                          ? 'Balanced output requires mono mode.'
                          : 'Recommended for the XLR output.',
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BalancedSignalIcon(
                              size: 24,
                              primaryColor: outputBalanceMode == 'balanced'
                                  ? Colors.cyanAccent
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text('Balanced', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ],
                  selected: {outputBalanceMode},
                  onSelectionChanged: !isOutputMono
                      ? null
                      : (set) {
                          final String newBalance = set.first;
                          final bool makeBalanced = newBalance == 'balanced';
                          widget.service.sendCommands({
                            state.speaker.balanced.command: makeBalanced
                                ? 't'
                                : 'f',
                          });
                          wasOutputBalanced = makeBalanced;
                        },
                ),
                const SizedBox(height: 24),

                VolumeSlider(
                  service: widget.service,
                  input: state.speaker.volume,
                  label: 'Master Output Volume',
                  min: -57,
                  max: 6,
                ),

                const SizedBox(height: 24),

                IntrinsicHeight(
                  child: Row(
                    spacing: 12.0,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withAlpha(50)),
                        ),
                        child: XlrIcon(
                          size: 36,
                          color: state.device.outputXlrDetected.value
                              ? Colors.greenAccent
                              : null,
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withAlpha(50)),
                        ),
                        child: JackIcon(
                          size: 36,
                          color: state.device.outputJackDetected.value
                              ? Colors.greenAccent
                              : null,
                        ),
                      ),

                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.withAlpha(50),
                            ),
                          ),
                          child: Row(
                            children: [
                              GroundIcon(size: 28, isLifted: isGroundLifted),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isGroundLifted
                                          ? 'Ground Lifted'
                                          : 'Ground Connected',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
