import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:onechannelaudioprocessor/screens/settings_screen.dart';
import 'package:onechannelaudioprocessor/screens/state_debug_screen.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/audio_fader/audio_fader.dart';
import '../widgets/vu_meter/audio_meter.dart';
import 'advanced_controls_screen.dart';
import 'connection_screen.dart';
import 'eq/eq_screen.dart';

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
        await widget.service.reconnect();

        // If reconnect() didn't throw an error, it succeeded!
        // The listener will catch the success and clear the UI.
        return;
      } catch (e) {
        // Attempt failed, loop continues
      }
    }

    // 4. If we reach here, all 3 attempts failed.
    if (mounted && !_isManualDisconnect) {
      dev.log("Connection lost permanently.");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniMixer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.amber),
            tooltip: 'Device Control',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StateDebugScreen(service: widget.service),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_input_composite),
            tooltip: 'Advanced Controls',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AdvancedControlsScreen(service: widget.service),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
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
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(service: widget.service),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: 'Disconnect',
            onPressed: _handleManualDisconnect,
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<MixerState>(
            stream: widget.service.stateStream,
            builder: (context, snapshot) {
              final state = snapshot.data ?? MixerState();

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    AudioMeterWidget(
                      peak: state.peakOverPeriod,
                      width: 20,
                      label: "Max",
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
                            state.dac.volume.command: value.toStringAsFixed(1),
                          });
                        },
                        onMuteToggled: () {
                          widget.service.sendCommands({
                            state.speaker.mute.command: state.speaker.mute.value
                                ? 'f'
                                : 't',
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
    );
  }
}
