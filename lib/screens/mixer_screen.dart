import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:onechannelaudioprocessor/screens/advanced_device_control_screen.dart';
import 'package:onechannelaudioprocessor/screens/device_settings_screen.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../utils/math.dart';
import '../widgets/audio_fader/audio_fader.dart';
import '../widgets/hardware_volume_listener_widget.dart';
import '../widgets/ping_indicator_widget.dart';
import '../widgets/vu_meter/audio_meter.dart';
import 'connection_screen.dart';
import 'eq/eq_screen.dart';
import 'input_output_control_screen.dart';

enum MeterDisplayMode { input, both, output }

class MixerScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const MixerScreen({super.key, required this.service});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  bool _isManualDisconnect = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;

  // Meter Mode State
  MeterDisplayMode _meterMode = MeterDisplayMode.input;

  @override
  void initState() {
    super.initState();
    // Listen for unexpected disconnections
    widget.service.addListener(_onConnectionStateChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onConnectionStateChanged);
    super.dispose();
  }

  void _onConnectionStateChanged() {
    dev.log(
      "Connection state changed. \n"
      "\twidget.service.isConnected: ${widget.service.isConnected};\n"
      "\t_isManualDisconnect: $_isManualDisconnect;",
    );

    if (!mounted) return;

    // 1. Connection Restored / Is Active
    if (widget.service.isConnected) {
      if (_isReconnecting && mounted) {
        setState(() {
          _isReconnecting = false;
          _reconnectAttempts = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reconnected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    // 2. Ignore expected drops (user clicked disconnect)
    if (_isManualDisconnect) return;

    // 3. Unexpected drop detected! Start loop if not already running.
    if (!_isReconnecting && mounted) {
      _startAutoReconnect();
    }
  }

  Future<void> _startAutoReconnect() async {
    if (!mounted) return;

    setState(() {
      _isReconnecting = true;
      _reconnectAttempts = 0;
    });

    for (int i = 1; i <= 3; i++) {
      // Abort loop if user manually clicks disconnect while reconnecting
      if (!mounted || _isManualDisconnect) return;

      setState(() => _reconnectAttempts = i);

      try {
        await Future.delayed(const Duration(seconds: 2));

        // Re-check mounted status after async delay
        if (!mounted || _isManualDisconnect) return;

        await widget.service.reconnect();

        // If reconnect() didn't throw an error, it succeeded!
        return;
      } catch (e) {
        // Attempt failed, loop continues
      }
    }

    // 4. If we reach here, all 3 attempts failed.
    if (mounted && !_isManualDisconnect) {
      dev.log("Connection lost permanently.");

      // Stop any lingering sockets before going back
      await widget.service.disconnect();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection lost permanently.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConnectionScreen(service: widget.service),
        ),
      );
    }
  }

  Future<void> _handleManualDisconnect() async {
    dev.log("Manually disconnecting.");
    setState(() => _isManualDisconnect = true);
    await widget.service.disconnect();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConnectionScreen(service: widget.service),
        ),
      );
    }
  }

  Future<void> _confirmAndDisconnect() async {
    final bool? shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disconnect?'),
          content: const Text(
            'Are you sure you want to disconnect from the mixer?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );

    if (shouldDisconnect == true) {
      await _handleManualDisconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    String screenTitle = "MiniMix";
    if (widget.service.activeType == ConnectionType.wifi &&
        widget.service.connectedIpAddress != null &&
        widget.service.connectedIpAddress!.isNotEmpty) {
      screenTitle = "${widget.service.connectedIpAddress}";
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _confirmAndDisconnect();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(screenTitle),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ListenableBuilder(
                listenable: widget.service.pingService,
                builder: (context, _) {
                  return PingIndicatorWidget(
                    pingMs: widget.service.pingService.pingMs,
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.amber),
              tooltip: 'Advanced Control',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AdvancedDeviceControl(service: widget.service),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_input_svideo),
              tooltip: 'Input / Output Control',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        InputOutputControlScreen(service: widget.service),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.stacked_bar_chart_rounded),
              tooltip: 'Equalizer',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EqScreen(service: widget.service),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Device Settings',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        DeviceSettingsScreen(service: widget.service),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'Disconnect',
              onPressed: _confirmAndDisconnect,
            ),
          ],
        ),
        body: HardwareVolumeListenerWidget(
          service: widget.service,
          showVolumePopup: false,
          child: Stack(
          children: [
            StreamBuilder<MixerState>(
              stream: widget.service.stateStream,
              builder: (context, snapshot) {
                final state = snapshot.data ?? MixerState();

                // METER EMULATION LOGIC
                final double inputPeak = state.peakOverPeriod;
                final bool isMuted = state.speaker.mute.value;
                double outputPeak = 0.0;

                if (!isMuted && inputPeak > 0.0001) {
                  double inputDb = rawToDbfs(inputPeak);
                  double outputDb = inputDb + state.dac.volume.value;
                  outputPeak = dbfsToRaw(outputDb).clamp(0.0, 1.0);
                }

                var meterDisplayMode = state.generator.enabled.value ? MeterDisplayMode.input : _meterMode;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                int next =
                                    (meterDisplayMode.index + 1) %
                                    MeterDisplayMode.values.length;
                                _meterMode = MeterDisplayMode.values[next];
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade700),
                              ),
                              child: Text(
                                meterDisplayMode == MeterDisplayMode.input
                                    ? 'IN'
                                    : meterDisplayMode == MeterDisplayMode.output
                                    ? 'OUT'
                                    : 'IN | OUT',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (meterDisplayMode == MeterDisplayMode.input ||
                                    meterDisplayMode == MeterDisplayMode.both)
                                  AudioMeterWidget(
                                    peak: inputPeak,
                                    width: 20,
                                    showScale:
                                        meterDisplayMode == MeterDisplayMode.input,
                                    label: "Pre",
                                  ),
                                if (meterDisplayMode == MeterDisplayMode.both)
                                  const SizedBox(width: 12),
                                if (meterDisplayMode == MeterDisplayMode.output ||
                                    meterDisplayMode == MeterDisplayMode.both)
                                  AudioMeterWidget(
                                    peak: outputPeak,
                                    width: 20,
                                    label: "Post",
                                    border: isMuted ? Colors.redAccent : null,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      Expanded(
                        child: AudioFaderWidget(
                          showVolumeValueText: false,
                          value: state.dac.volume.value.toDouble(),
                          isMuted: state.speaker.mute.value,
                          scaleTicks: const [
                            -127,
                            -80.0,
                            -40.0,
                            -20.0,
                            -10.0,
                            -5.0,
                            0.0,
                          ],
                          onChanged: (val) {
                            // Limit to 0.5 dB interval changes
                            double value = (val * 2).toInt().toDouble() / 2;
                            widget.service.sendCommands({
                              state.dac.volume.command: value.toStringAsFixed(
                                1,
                              ),
                            });
                          },
                          onMuteToggled: () {
                            widget.service.sendCommands({
                              state.speaker.mute.command:
                                  state.speaker.mute.value ? 'f' : 't',
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            if (_isReconnecting)
              Container(
                color: Colors.black.withAlpha(178),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'Reconnecting...',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Attempt $_reconnectAttempts of 3',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}
