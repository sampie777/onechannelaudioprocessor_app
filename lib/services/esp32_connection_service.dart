import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:onechannelaudioprocessor/services/ping_service.dart';
import 'package:onechannelaudioprocessor/services/udp_meter_service.dart';
import 'package:onechannelaudioprocessor/utils/math.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/mixer_state.dart';

enum ConnectionType { wifi, direct, demo }

class Esp32ConnectionService extends ChangeNotifier {
  String? _lastIpAddress;
  ConnectionType? _lastConnectionType;

  ConnectionType? _activeType;
  bool _isConnected = false;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  UdpMeterService? udpService;

  final PingService pingService = PingService();

  // Demo Mode Members
  Timer? _demoTimer;
  final Random _random = Random();

  final _stateController = StreamController<MixerState>.broadcast();

  Stream<MixerState> get stateStream => _stateController.stream;
  final MixerState _currentMixerState = MixerState();

  bool get isConnected => _isConnected;
  ConnectionType? get activeType => _activeType;
  ConnectionType? get lastConnectionType => _lastConnectionType;

  Future<void> connectWifi(String ipAddress) async {
    dev.log("Connecting to IP address: $ipAddress");
    await disconnect();

    try {
      _lastIpAddress = ipAddress;
      _lastConnectionType = ConnectionType.wifi;

      final wsUrl = 'ws://$ipAddress/ws';

      final ws = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Connection timed out. Device unreachable.');
        },
      );

      ws.pingInterval = const Duration(seconds: 3);

      // Wrap the successfully connected socket into the channel
      _wsChannel = IOWebSocketChannel(ws);

      _wsSubscription = _wsChannel!.stream.listen(
        (data) => _parseIncomingData(data.toString()),
        onError: (error) {
          dev.log("Error while listening to websocket: $error", error: error);
          disconnect();
        },
        onDone: () {
          dev.log("Websocket stream is done.");
          disconnect();
        },
        cancelOnError: true,
      );

      udpService = UdpMeterService();
      udpService!.onMeterData = (double peak, double avg) {
        final json = {"peak_over_period": peak, "avg_peak_over_period": avg};
        _parseIncomingData(jsonEncode(json));
      };
      udpService!.startListening(5005);

      _activeType = ConnectionType.wifi;
      _isConnected = true;

      // Start ping loop on successful connection
      pingService.start(_wsChannel!);

      notifyListeners();
    } catch (e) {
      dev.log("Failed to connect to IP address: $ipAddress.");
      _isConnected = false;
      _wsChannel = null;
      pingService.stop();
      notifyListeners();
      rethrow; // Throws back to the UI so the catch block dismisses the spinner
    }
  }

  Future<void> connectDemo() async {
    dev.log("Launching Demo Mode.");
    await disconnect();

    _lastConnectionType = ConnectionType.demo;
    _activeType = ConnectionType.demo;
    _isConnected = true;
    _currentMixerState.device.inputJackDetected.value = true;
    _currentMixerState.device.outputXlrDetected.value = true;
    _currentMixerState.routing.lineStereoToPga.value = true;
    notifyListeners();

    // Periodically generate simulated audio meter peaks
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isConnected || _activeType != ConnectionType.demo) return;
      double baseSignal = 0;
      baseSignal += sin(timer.tick / 20) * 0.1;
      baseSignal += sin((timer.tick + 3) / 17) * 0.2;
      baseSignal += sin((timer.tick + 2) / 11) * 0.15;
      baseSignal += sin(timer.tick / 9) * 0.05;
      baseSignal += sin(timer.tick / 3) * 0.1;
      baseSignal += sin(timer.tick / 1) * 0.01;
      baseSignal += sin(timer.tick / 0.9) * 0.05;
      baseSignal = baseSignal.abs();

      // Apply input gain in dBFS only if signal is non-zero
      if (baseSignal > 0.00001) {
        double inputGain = _currentMixerState.pga.gain.value;
        // Simulate the effect of mic vs line input on the signal level
        double inputTypeGain = _currentMixerState.routing.micToPga.value ? -30 : 0;

        double baseSignalDbfs = rawToDbfs(baseSignal) + inputGain + inputTypeGain;
        baseSignal = dbfsToRaw(baseSignalDbfs);
      }

      double rawPeak = baseSignal + pow(_random.nextDouble(), 2).toDouble() * 0.1;
      // Clamp to 1.0 maximum to simulate hard analog/digital clipping at 0 dBFS
      rawPeak = rawPeak.clamp(0.0001, 1.0);

      // Calculate average peak based on the boosted raw peak
      double avgPeak = (rawPeak * 0.7) + (_random.nextDouble() * 0.05);
      avgPeak = avgPeak.clamp(0.0001, rawPeak); // Avg shouldn't exceed raw peak

      final mockJson = {
        'peak_over_period': rawPeak,
        'avg_peak_over_period': avgPeak,
      };

      _parseIncomingData(jsonEncode(mockJson));
    });
  }

  // ---------------------------------------------------------------------------
  // SEND COMMAND FORMATTER: "speaker.mute=t&speaker.volume=0"
  // ---------------------------------------------------------------------------
  void sendCommands(Map<String, String> commands) {
    if (!_isConnected) return;

    _currentMixerState.updateFromCommands(commands);
    _stateController.add(_currentMixerState);

    if (_activeType == ConnectionType.demo) return;

    List<String> parts = [];
    commands.forEach((key, value) {
      parts.add('$key=$value');
    });

    String payload = parts.join('&');

    if ((_activeType == ConnectionType.wifi ||
            _activeType == ConnectionType.direct) &&
        _wsChannel != null) {
      _wsChannel!.sink.add(payload);
    }
  }

  void _parseIncomingData(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        // Forward pong payloads to PingService
        if (decoded.containsKey('pong')) {
          pingService.handleIncomingJson(decoded);
          return;
        }

        // Update the existing state in-place with whatever keys are present
        _currentMixerState.updateFromJson(decoded);
        // Push the updated state object to the stream to trigger UI rebuilds
        _stateController.add(_currentMixerState);
      }
    } catch (_) {}
  }

  Future<void> disconnect() async {
    // Guard: Don't execute multiple disconnect cleanups if already disconnected
    if (!_isConnected && _wsChannel == null && _wsSubscription == null) return;

    dev.log(
      "Disconnecting current connection.\n"
      "\t_isConnected=$_isConnected;\n"
      "\t_activeType=$_activeType;",
    );

    _demoTimer?.cancel();
    _demoTimer = null;

    pingService.stop();

    await _wsSubscription?.cancel();
    _wsSubscription = null;

    await _wsChannel?.sink.close();
    _wsChannel = null;

    udpService?.stopListening();
    udpService = null;

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
