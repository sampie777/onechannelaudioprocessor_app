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

  String? get connectedIpAddress => _lastIpAddress;

  Future<void> connectWifi(String ipAddress) async {
    dev.log("Connecting to IP address: $ipAddress");
    await disconnect();

    try {
      _lastIpAddress = ipAddress;
      _lastConnectionType = ConnectionType.wifi;

      final wsUrl = 'ws://$ipAddress/ws';

      final ws = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            throw TimeoutException('Connection timed out. Device unreachable.'),
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
      udpService!.onMeterData =
          (double peak, double avg, List<double> spectrum) {
            _currentMixerState.peakOverPeriod = peak;
            _currentMixerState.avgPeakOverPeriod = avg;
            _currentMixerState.spectrum = spectrum;
            _stateController.add(_currentMixerState);
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

      final eq = _currentMixerState.eq;

      // Generate randomized spectrum for demo testing
      List<double> mockSpectrum = List.filled(32, -80.0);
      for (int i = 0; i < 32; i++) {
        // Create a shaping envelope to mimic typical music
        double shapeMultiplier = 1.0;
        if (i < 4) {
          // Ramp up the lowest frequencies
          shapeMultiplier = 0.4 + (0.15 * i);
        } else if (i > 16) {
          // Aggressive exponential roll-off for the high frequencies
          shapeMultiplier = pow(0.8, i - 16).toDouble();
        }

        // Generate a random amplitude scaled by the overall average peak signal AND the shape
        double randomVal = _random.nextDouble() * avgPeak * shapeMultiplier;

        // Convert the linear random value to decibels
        double targetDb = randomVal > 0.00001 ? (20 * log(randomVal) / ln10) : -80.0;

        // ---------------------------------------------------------------------
        // APPLY EQ SIMULATION TO THE SPECTRUM BIN
        // ---------------------------------------------------------------------
        // Calculate the center frequency of this specific bin
        double f = 20.0 * pow(10, (i + 0.5) * 3.0 / 32.0);
        double eqGain = 0.0;

        // High Pass
        if (eq.highPass.enabled.value) {
          double fc = eq.highPass.frequency.value.toDouble();
          int order = fc <= 4.0 ? 1 : 2;
          eqGain += -10.0 * (log(1.0 + pow(fc / f, 2 * order)) / ln10);
        }

        // Low Shelf
        if (!eq.lowShelf.isBypassed && eq.lowShelf.gain.value != 0) {
          double fc = eq.lowShelf.frequency.value.toDouble();
          double g = eq.lowShelf.gain.value.toDouble();
          eqGain += g / (1.0 + pow(f / fc, 3.0));
        }

        // Parametric Bands (Low, Mid, High)
        void applyParametric(ParametricEqBand band) {
          if (!band.isBypassed && band.gain.value != 0) {
            double fc = band.frequency.value.toDouble();
            double g = band.gain.value.toDouble();
            double q = band.band.value == 'wide' ? 0.75 : 1.8;
            double logDist = log(f / fc);
            eqGain += g * exp(-(logDist * logDist) * (q * 4.0));
          }
        }
        applyParametric(eq.low);
        applyParametric(eq.mid);
        applyParametric(eq.high);

        // High Shelf
        if (!eq.highShelf.isBypassed && eq.highShelf.gain.value != 0) {
          double fc = eq.highShelf.frequency.value.toDouble();
          double g = eq.highShelf.gain.value.toDouble();
          eqGain += g / (1.0 + pow(fc / f, 3.0));
        }

        // Apply EQ changes and clamp to prevent clipping or falling off the graph
        targetDb += eqGain;
        targetDb = targetDb.clamp(-80.0, 0.0);

        // Apply EWMA smoothing so the random jumps look like organic EQ bands
        double oldDb = _currentMixerState.spectrum[i];
        mockSpectrum[i] = (oldDb * 0.7) + (targetDb * 0.3);
      }

      // Directly apply to state instead of routing through JSON mock
      _currentMixerState.peakOverPeriod = rawPeak;
      _currentMixerState.avgPeakOverPeriod = avgPeak;
      _currentMixerState.spectrum = mockSpectrum;
      _stateController.add(_currentMixerState);
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

    // Guard: Do not attempt reconnection if there's no stored endpoint/type
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
