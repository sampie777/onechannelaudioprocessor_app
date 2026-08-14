import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

import '../models/mixer_state.dart';
import 'demo_simulator.dart';
import 'ping_service.dart';
import 'wifi_connection_handler.dart';

enum ConnectionType { wifi, direct, demo }

class Esp32ConnectionService extends ChangeNotifier {
  String? _lastIpAddress;
  ConnectionType? _lastConnectionType;
  ConnectionType? _activeType;
  bool _isConnected = false;

  DemoSimulator? _demoSimulator;
  WifiConnectionHandler? _wifiHandler;

  // We keep the PingService here so UI Listeners stay permanently attached
  final PingService pingService = PingService();

  final _stateController = StreamController<MixerState>.broadcast();

  Stream<MixerState> get stateStream => _stateController.stream;

  final MixerState _currentMixerState = MixerState();

  bool get isConnected => _isConnected;

  ConnectionType? get activeType => _activeType;

  ConnectionType? get lastConnectionType => _lastConnectionType;

  String? get connectedIpAddress => _lastIpAddress;

  Future<void> connectWifi(String ipAddress) async {
    dev.log("Connecting to IP address: $ipAddress");
    await disconnect();

    try {
      _lastIpAddress = ipAddress;
      _lastConnectionType = ConnectionType.wifi;

      _wifiHandler = WifiConnectionHandler(
        ipAddress: ipAddress,
        pingService: pingService,
        onJsonData: (json) {
          _currentMixerState.updateFromJson(json);
          _stateController.add(_currentMixerState);
        },
        onMeterData: (peak, avg, spectrum) {
          _currentMixerState.peakOverPeriod = peak;
          _currentMixerState.avgPeakOverPeriod = avg;
          _currentMixerState.spectrum = spectrum;
          _stateController.add(_currentMixerState);
        },
        onDisconnected: () {
          // If the socket drops unexpectedly, trigger the main disconnect to clean state
          if (_isConnected && _activeType != ConnectionType.demo) {
            disconnect();
          }
        },
      );

      await _wifiHandler!.connect();

      _activeType = ConnectionType.wifi;
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      dev.log("Failed to connect to IP address: $ipAddress.");
      _isConnected = false;
      _wifiHandler = null;
      pingService.stop();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> connectDemo() async {
    dev.log("Launching Demo Mode.");
    await disconnect();

    _lastConnectionType = ConnectionType.demo;
    _activeType = ConnectionType.demo;
    _isConnected = true;
    notifyListeners();

    _demoSimulator = DemoSimulator(
      state: _currentMixerState,
      pingService: pingService,
      onUpdate: (updatedState) {
        if (!_isConnected || _activeType != ConnectionType.demo) return;
        _stateController.add(updatedState);
      },
    );

    _demoSimulator!.start();
  }

  // ---------------------------------------------------------------------------
  // SEND COMMAND FORMATTER: "speaker.mute=t&speaker.volume=0"
  // ---------------------------------------------------------------------------
  void sendCommands(Map<String, String> commands) {
    if (!_isConnected) return;

    // Apply the updates locally instantly for immediate UI feedback
    _currentMixerState.updateFromCommands(commands);
    _stateController.add(_currentMixerState);

    if (_activeType == ConnectionType.demo) return;

    List<String> parts = [];
    commands.forEach((key, value) {
      parts.add('$key=$value');
    });

    String payload = parts.join('&');

    if (_activeType == ConnectionType.wifi ||
        _activeType == ConnectionType.direct) {
      _wifiHandler?.sendPayload(payload);
    }
  }

  Future<void> disconnect() async {
    // Guard: Don't execute multiple disconnect cleanups if already disconnected
    if (!_isConnected && _demoSimulator == null && _wifiHandler == null) return;

    dev.log(
      "Disconnecting current connection.\n"
      "\t_isConnected=$_isConnected;\n"
      "\t_activeType=$_activeType;",
    );

    _demoSimulator?.stop();
    _demoSimulator = null;

    await _wifiHandler?.disconnect();
    _wifiHandler = null;

    pingService.stop();

    _isConnected = false;
    _activeType = null;
    notifyListeners();
  }

  Future<void> reconnect() async {
    dev.log(
      "Reconnecting current connection.\n"
      "\t_lastConnectionType=$_lastConnectionType;\n"
      "\t_isConnected=$_isConnected;\n"
      "\t_activeType=$_activeType;",
    );

    if (_lastConnectionType == null) {
      dev.log("Reconnect aborted: No last connection type.");
      return;
    }

    if ((_lastConnectionType == ConnectionType.wifi ||
            _lastConnectionType == ConnectionType.direct) &&
        _lastIpAddress != null) {
      await connectWifi(_lastIpAddress!);
    } else if (_lastConnectionType == ConnectionType.demo) {
      await connectDemo();
    } else {
      throw Exception("No previous connection data to restore");
    }
  }
}
