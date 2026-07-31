import 'dart:math';

enum EqBand { narrow, wide }

// -----------------------------------------------------------------------------
// NESTED EQ COMPONENTS
// -----------------------------------------------------------------------------
class HighPassFilter {
  bool enabled = false;
  int frequency = 0;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('enabled')) enabled = json['enabled'] as bool;
    if (json.containsKey('frequency')) frequency = (json['frequency'] as num).toInt();
  }
}

class ShelfFilter {
  int frequency = 0;
  int gain = 0;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('frequency')) frequency = (json['frequency'] as num).toInt();
    if (json.containsKey('gain')) gain = (json['gain'] as num).toInt();
  }
}

class ParametricEqBand {
  int frequency = 0;
  int gain = 0;
  EqBand band = EqBand.narrow;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('frequency')) frequency = (json['frequency'] as num).toInt();
    if (json.containsKey('gain')) gain = (json['gain'] as num).toInt();
    if (json.containsKey('band')) {
      final bandStr = json['band'] as String? ?? 'Narrow';
      band = bandStr.toLowerCase() == 'wide' ? EqBand.wide : EqBand.narrow;
    }
  }
}

class EqState {
  final HighPassFilter highPass = HighPassFilter();
  final ShelfFilter lowShelf = ShelfFilter();
  final ParametricEqBand low = ParametricEqBand();
  final ParametricEqBand mid = ParametricEqBand();
  final ParametricEqBand high = ParametricEqBand();
  final ShelfFilter highShelf = ShelfFilter();

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('high_pass')) highPass.updateFromJson(json['high_pass']);
    if (json.containsKey('low_shelf')) lowShelf.updateFromJson(json['low_shelf']);
    if (json.containsKey('low')) low.updateFromJson(json['low']);
    if (json.containsKey('mid')) mid.updateFromJson(json['mid']);
    if (json.containsKey('high')) high.updateFromJson(json['high']);
    if (json.containsKey('high_shelf')) highShelf.updateFromJson(json['high_shelf']);
  }
}

// -----------------------------------------------------------------------------
// MODULE COMPONENTS
// -----------------------------------------------------------------------------
class RoutingState {
  bool micToPga = false;
  bool lineToPga = false;
  bool lineToAdcMix = false;
  bool adcMixToMainMixer = false;
  bool auxToMainMixer = false;
  bool dacToMainMixer = false;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('mic_to_pga')) micToPga = json['mic_to_pga'] as bool;
    if (json.containsKey('line_to_pga')) lineToPga = json['line_to_pga'] as bool;
    if (json.containsKey('line_to_adcmix')) lineToAdcMix = json['line_to_adcmix'] as bool;
    if (json.containsKey('adcmix_to_main_mixer')) adcMixToMainMixer = json['adcmix_to_main_mixer'] as bool;
    if (json.containsKey('aux_to_main_mixer')) auxToMainMixer = json['aux_to_main_mixer'] as bool;
    if (json.containsKey('dac_to_main_mixer')) dacToMainMixer = json['dac_to_main_mixer'] as bool;
  }
}

class PgaState {
  bool mute = false;
  double gain = 0.0;
  bool boost = false;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('mute')) mute = json['mute'] as bool;
    if (json.containsKey('gain')) gain = (json['gain'] as num).toDouble();
    if (json.containsKey('boost')) boost = json['boost'] as bool;
  }
}

class AdcState {
  double volume = 0.0;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('volume')) volume = (json['volume'] as num).toDouble();
  }
}

class DacState {
  bool mute = false;
  double volume = 0.0;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('mute')) mute = json['mute'] as bool;
    if (json.containsKey('volume')) volume = (json['volume'] as num).toDouble();
  }
}

class MixerControlState {
  int volumeAdcMix = 0;
  int volumeAux = 0;
  bool mono = false;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('volume_adcmix')) volumeAdcMix = (json['volume_adcmix'] as num).toInt();
    if (json.containsKey('volume_aux')) volumeAux = (json['volume_aux'] as num).toInt();
    if (json.containsKey('mono')) mono = json['mono'] as bool;
  }
}

class HeadphonesState {
  bool mute = false;
  int volume = 0;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('mute')) mute = json['mute'] as bool;
    if (json.containsKey('volume')) volume = (json['volume'] as num).toInt();
  }
}

class AuxOutState {
  bool mute = false;
  bool gainBoost = false;
  bool balanced = false;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('mute')) mute = json['mute'] as bool;
    if (json.containsKey('gain_boost')) gainBoost = json['gain_boost'] as bool;
    if (json.containsKey('balanced')) balanced = json['balanced'] as bool;
  }
}

class SpeakerState {
  bool mute = false;
  bool gainBoost = false;
  bool balanced = false;
  int volume = 0;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('mute')) mute = json['mute'] as bool;
    if (json.containsKey('gain_boost')) gainBoost = json['gain_boost'] as bool;
    if (json.containsKey('balanced')) balanced = json['balanced'] as bool;
    if (json.containsKey('volume')) volume = (json['volume'] as num).toInt();
  }
}

class ClientState {
  int smallUpdateIntervalMs = 0;
  int bigUpdateIntervalMs = 0;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('small_update_interval_ms')) smallUpdateIntervalMs = (json['small_update_interval_ms'] as num).toInt();
    if (json.containsKey('big_update_interval_ms')) bigUpdateIntervalMs = (json['big_update_interval_ms'] as num).toInt();
  }
}

// -----------------------------------------------------------------------------
// MAIN STATE TREE
// -----------------------------------------------------------------------------
class MixerState {
  double peakOverPeriod = 0.0;
  double avgPeakOverPeriod = 0.0;

  // Nested structures initialized once and updated in-place
  final RoutingState routing = RoutingState();
  final PgaState pga = PgaState();
  final AdcState adc = AdcState();
  final EqState eq = EqState();
  final DacState dac = DacState();
  final MixerControlState mixer = MixerControlState();
  final HeadphonesState headphones = HeadphonesState();
  final AuxOutState auxout = AuxOutState();
  final SpeakerState speaker = SpeakerState();

  // Linear float [0.0 - 1.0] to dBFS [-60 dBFS to 0 dBFS]
  double get peakDbfs => _linearToDbfs(peakOverPeriod);
  double get avgPeakDbfs => _linearToDbfs(avgPeakOverPeriod);

  static double _linearToDbfs(double linear) {
    if (linear <= 0.00001) return -60.0;
    double db = 20 * log(linear) / ln10;
    return db.clamp(-60.0, 0.0);
  }

  // Master update function handles partial JSON payloads
  void updateFromJson(Map<String, dynamic> json) {
    // High-frequency meter updates
    if (json.containsKey('peak_over_period')) {
      peakOverPeriod = (json['peak_over_period'] as num).toDouble();
    }
    if (json.containsKey('avg_peak_over_period')) {
      avgPeakOverPeriod = (json['avg_peak_over_period'] as num).toDouble();
    }

    // Low-frequency UI state updates
    if (json.containsKey('routing')) routing.updateFromJson(json['routing']);
    if (json.containsKey('pga')) pga.updateFromJson(json['pga']);
    if (json.containsKey('adc')) adc.updateFromJson(json['adc']);
    if (json.containsKey('eq')) eq.updateFromJson(json['eq']);
    if (json.containsKey('dac')) dac.updateFromJson(json['dac']);
    if (json.containsKey('mixer')) mixer.updateFromJson(json['mixer']);
    if (json.containsKey('headphones')) headphones.updateFromJson(json['headphones']);
    if (json.containsKey('auxout')) auxout.updateFromJson(json['auxout']);
    if (json.containsKey('speaker')) speaker.updateFromJson(json['speaker']);
    if (json.containsKey('client')) client.updateFromJson(json['client']);
  }
}