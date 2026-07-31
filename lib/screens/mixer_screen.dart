import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/audio_meter.dart';
import 'connection_screen.dart';
import 'eq_screen.dart';

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
    setState(() => _isManualDisconnect = true);
    await widget.service.disconnect();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ConnectionScreen(service: widget.service)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MiniMixer'),
        actions: [IconButton(
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
            icon: const Icon(Icons.power_settings_new),
            tooltip: 'Disconnect',
            onPressed: _handleManualDisconnect, // Even works during a reconnect!
          )
        ],
      ),
      body: Stack(
        children: [
          // Background: The standard Mixer UI
          StreamBuilder<MixerState>(
            stream: widget.service.stateStream,
            builder: (context, snapshot) {
              final state = snapshot.data ?? MixerState();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Audio Meter Column
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AudioMeterWidget(
                          peakLinear: state.peakOverPeriod,
                          avgPeakLinear: state.avgPeakOverPeriod,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${state.avgPeakDbfs.toStringAsFixed(1)} dBFS',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),

                    // Volume Fader Column
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              // Reads directly from the global state!
                              value: state.speaker.volume.value.toDouble(),
                              min: -57.0,
                              max: 6.0,
                              divisions: 63,
                              label: '${state.speaker.volume.value} dB',
                              onChanged: (val) {
                                // Sends the command (which instantly updates the state stream)
                                widget.service.sendCommands({'speaker.volume': val.toInt().toString()});
                              },
                            ),
                          ),
                        ),
                        Text(
                          '${state.speaker.volume.value} dB',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        IconButton.filled(
                          iconSize: 32,
                          icon: Icon(state.speaker.mute.value ? Icons.volume_off : Icons.volume_up),
                          color: state.speaker.mute.value ? Colors.red : Colors.green,
                          onPressed: () {
                            // Flips the current network state and sends
                            widget.service.sendCommands({'speaker.mute': state.speaker.mute.value ? 'f' : 't'});
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.speaker.mute.value ? 'MUTED' : 'ACTIVE',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    )
                  ],
                ),
              );
            },
          ),

          // Foreground: Reconnecting Overlay
          if (_isReconnecting)
            Container(
              color: Colors.black.withOpacity(0.7),
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