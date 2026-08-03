import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/esp32_connection_service.dart';
import 'mixer_screen.dart';

class ConnectionScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const ConnectionScreen({super.key, required this.service});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  static const String _recentIpsKey = 'recent_ip_addresses';

  ConnectionType _selectedType = ConnectionType.wifi;
  final TextEditingController _ipController = TextEditingController(text: "192.168.1.100");

  List<String> _recentIps = [];
  List<BluetoothDevice> _btDevices = [];
  BluetoothDevice? _selectedBtDevice;
  bool _isLoading = false;

  bool get _isBluetoothSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _loadSavedIps();
    _requestPermissions();
  }

  // ---------------------------------------------------------------------------
  // LOAD & SAVE RECENT IPS
  // ---------------------------------------------------------------------------
  Future<void> _loadSavedIps() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIps = prefs.getStringList(_recentIpsKey) ?? [];

    setState(() {
      _recentIps = savedIps;
      // Pre-fill input with the most recent IP if available, or fall back to default
      if (_recentIps.isNotEmpty) {
        _ipController.text = _recentIps.first;
      } else {
        _ipController.text = "192.168.1.50";
      }
    });
  }

  Future<void> _saveSuccessfulIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();

    // Remove duplicates and keep only the 3 most recent IPs
    List<String> updatedList = List.from(_recentIps);
    updatedList.remove(ip);
    updatedList.insert(0, ip);

    if (updatedList.length > 3) {
      updatedList = updatedList.sublist(0, 3);
    }

    await prefs.setStringList(_recentIpsKey, updatedList);

    setState(() {
      _recentIps = updatedList;
    });
  }

  // ---------------------------------------------------------------------------
  // PERMISSIONS & BLUETOOTH
  // ---------------------------------------------------------------------------
  Future<void> _requestPermissions() async {
    // Mobile platforms (Android / iOS) require runtime permissions
    if (_isBluetoothSupported) {
      await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.locationWhenInUse,
      ].request();
    }

    _loadBluetoothDevices();
  }

  Future<void> _loadBluetoothDevices() async {
    if (_isBluetoothSupported) {
      try {
        List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance
            .getBondedDevices();
        setState(() {
          _btDevices = devices;
          if (devices.isNotEmpty) _selectedBtDevice = devices.first;
        });
      } catch (e) {
        dev.log('Failed to load BT devices: $e');
      }
    }
  }

  Future<void> _handleConnect() async {
    dev.log("Start new connection.");

    setState(() => _isLoading = true);
    try {
      if (_selectedType == ConnectionType.wifi) {
        final ip = _ipController.text.trim();
        if (ip.isEmpty) throw Exception("Please enter an IP address");

        // 1. Attempt connection (Will throw an exception if socket/IP is invalid)
        await widget.service.connectWifi(ip);

        // 2. Only saved if connectWifi succeeded!
        await _saveSuccessfulIp(ip);
      } else if (_selectedType == ConnectionType.bluetooth) {
        if (_selectedBtDevice == null) {
          throw Exception("Select a Bluetooth device");
        }

        // Attempt Bluetooth connection
        await widget.service.connectBluetooth(_selectedBtDevice!.address);
      } else if (_selectedType == ConnectionType.demo) {
        // Launch Demo Mode
        await widget.service.connectDemo();
      }

      // 3. Navigate to MixerScreen only after successful connection test
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MixerScreen(service: widget.service),
          ),
        );
      }
    } catch (e) {
      dev.log("Failed to create a new connection", error: e);
      await widget.service.disconnect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MiniMixer Connect'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ConnectionType>(
              segments: [
                const ButtonSegment(
                  value: ConnectionType.wifi,
                  label: Text('Wi-Fi'),
                  icon: Icon(Icons.wifi),
                ),
                ButtonSegment(
                  value: ConnectionType.bluetooth,
                  label: Text(
                    _isBluetoothSupported
                        ? 'Bluetooth'
                        : 'Bluetooth (Android/iOS Only)',
                  ),
                  icon: const Icon(Icons.bluetooth),
                  enabled: _isBluetoothSupported,
                ),
                const ButtonSegment(
                  value: ConnectionType.demo,
                  label: Text('Demo'),
                  icon: Icon(Icons.play_circle_outline),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (set) {
                if (_isBluetoothSupported ||
                    set.first == ConnectionType.wifi ||
                    set.first == ConnectionType.demo) {
                  setState(() => _selectedType = set.first);
                }
              },
            ),
            const SizedBox(height: 32),

            // Wi-Fi Connection View
            if (_selectedType == ConnectionType.wifi) ...[
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'ESP32 IP Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.computer),
                ),
                keyboardType: TextInputType.number,
              ),

              // Recent IPs Quick Connect Chips
              if (_recentIps.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Recent Connections:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _recentIps.map((ip) {
                    final bool isCurrent = _ipController.text == ip;
                    return ActionChip(
                      avatar: Icon(
                        Icons.history,
                        size: 16,
                        color: isCurrent
                            ? Colors.deepPurpleAccent
                            : Colors.grey,
                      ),
                      label: Text(ip),
                      backgroundColor: isCurrent
                          ? Colors.deepPurple.withAlpha(50)
                          : null,
                      onPressed: () {
                        setState(() {
                          _ipController.text = ip;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ]
            // Bluetooth Connection View
            else if (_isBluetoothSupported) ...[
              DropdownButtonFormField<BluetoothDevice>(
                value: _selectedBtDevice,
                decoration: const InputDecoration(
                  labelText: 'Select Paired Device',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bluetooth_searching),
                ),
                items: _btDevices.map((dev) {
                  return DropdownMenuItem(
                    value: dev,
                    child: Text(dev.name ?? dev.address),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedBtDevice = val),
              ),
            ]
            // Demo Connection View
            else if (_selectedType == ConnectionType.demo) ...[
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.withAlpha(100),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.purpleAccent.shade100,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Demo Mode runs offline with simulated audio meter values. No actual commands will be sent to hardware.',
                        style: TextStyle(fontSize: 14, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleConnect,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'CONNECT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
