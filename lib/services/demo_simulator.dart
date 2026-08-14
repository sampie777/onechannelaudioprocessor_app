import 'dart:async';
import 'dart:math';

import 'package:onechannelaudioprocessor/services/ping_service.dart';

import '../models/mixer_state.dart';
import '../utils/math.dart';

class DemoSimulator {
  Timer? _audioTimer;
  Timer? _pingTimer;
  final Random _random = Random();

  final MixerState state;
  final void Function(MixerState updatedState) onUpdate;
  final PingService pingService;

  DemoSimulator({
    required this.state,
    required this.onUpdate,
    required this.pingService,
  });

  void start() {
    stop(); // Ensure any existing timers are killed

    state.device.inputJackDetected.value = true;
    state.device.outputXlrDetected.value = true;
    state.routing.lineStereoToPga.value = true;
    state.mixer.mono.value = true;
    state.speaker.balanced.value = true;

    _audioTimer = Timer.periodic(const Duration(milliseconds: 50), _onAudioTick);
    _pingTimer = Timer.periodic(const Duration(seconds: 2), _onPingTick);
  }

  void stop() {
    _audioTimer?.cancel();
    _audioTimer = null;

    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _onPingTick(Timer timer) {
    pingService.pingMs = 11 + _random.nextInt(90) + (_random.nextDouble() < 0.2 ? _random.nextInt(60) : 0);
  }

  void _onAudioTick(Timer timer) {
    generateDemoDataUpdate(timer);
    onUpdate(state);
  }

  void generateDemoDataUpdate(Timer timer) {
    double rawPeak = generatePeakData(timer);

    // Calculate average peak based on the boosted raw peak
    double avgPeak = (rawPeak * 0.7) + (_random.nextDouble() * 0.05);
    avgPeak = avgPeak.clamp(0.0001, rawPeak); // Avg shouldn't exceed raw peak

    List<double> mockSpectrum = generateSpectrumData(avgPeak);

    state.peakOverPeriod = rawPeak;
    state.avgPeakOverPeriod = avgPeak;
    state.spectrum = mockSpectrum;
  }

  double generatePeakData(Timer timer) {
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
      double inputGain = state.pga.gain.value;
      // Simulate the effect of mic vs line input on the signal level
      double inputTypeGain = state.routing.micToPga.value ? -30 : 0;

      double baseSignalDbfs = rawToDbfs(baseSignal) + inputGain + inputTypeGain;
      baseSignal = dbfsToRaw(baseSignalDbfs);
    }

    double rawPeak = baseSignal + pow(_random.nextDouble(), 2).toDouble() * 0.1;
    // Clamp to 1.0 maximum to simulate hard analog/digital clipping at 0 dBFS
    return rawPeak.clamp(0.0001, 1.0);
  }

  List<double> generateSpectrumData(double avgPeak) {
    final eq = state.eq;

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
      double targetDb = randomVal > 0.00001
          ? (20 * log(randomVal) / ln10)
          : -80.0;

      // -----------------------------------------------------------------------
      // APPLY EQ SIMULATION TO THE SPECTRUM BIN
      // -----------------------------------------------------------------------
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
      double oldDb = state.spectrum[i];
      mockSpectrum[i] = (oldDb * 0.7) + (targetDb * 0.3);
    }
    return mockSpectrum;
  }
}