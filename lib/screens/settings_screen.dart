import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';

class SettingsScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const SettingsScreen({super.key, required this.service});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _sendWifiCredentials() {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    if (ssid.isEmpty) return;

    widget.service.sendCommands({'wifi.ssid': ssid, 'wifi.password': password});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wi-Fi credentials sent to ESP32.')),
    );

    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Settings')),
      body: StreamBuilder<MixerState>(
        stream: widget.service.stateStream,
        builder: (context, snapshot) {
          final state = snapshot.data ?? MixerState();

          // Fallback properties, adjust to your MixerState model
          final bool ledsEnabled = state.device.enableStatusLights.value;
          int updateInterval = state.client.smallUpdateIntervalMs.value;

          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              // Wi-Fi Section
              const Text(
                'Network (STA Mode)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'Wi-Fi SSID',
                  prefixIcon: Icon(Icons.wifi),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Wi-Fi Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _sendWifiCredentials,
                icon: const Icon(Icons.save),
                label: const Text('Update Wi-Fi & Connect'),
              ),
              const Divider(height: 48),

              // Device Section
              const Text(
                'Device Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Status LEDs'),
                subtitle: const Text(
                  'Enable or disable hardware indicator lights',
                ),
                value: state.device.enableStatusLights.value,
                activeColor: Colors.cyan,
                onChanged: (val) {
                  widget.service.sendCommands({
                    'device.enable_status_lights': val ? 't' : 'f',
                  });
                },
              ),
              const SizedBox(height: 16),

              // Update Interval Section
              Text('UI Update Interval: ${updateInterval}ms'),
              Slider(
                value: updateInterval.toDouble().clamp(30, 1000),
                min: 30,
                max: 1000,
                divisions: 1000 - 30,
                label: '${updateInterval}ms',
                onChanged: (val) {
                  // Only update UI locally during drag, send on end to prevent network spam
                  state.client.smallUpdateIntervalMs.value = val.toInt();
                },
                onChangeEnd: (val) {
                  widget.service.sendCommands({
                    'client.small_update_interval_ms': val.toInt().toString(),
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
