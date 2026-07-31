import 'dart:math';

enum EqBand { narrow, wide }

class HighPassFilter {
  final bool enabled;
  final int frequency;

  HighPassFilter({this.enabled = false, this.frequency = 0});

  factory HighPassFilter.fromJson(Map<String, dynamic>? json) {
    if (json == null) return HighPassFilter();
    return HighPassFilter(
      enabled: json['enabled'] as bool? ?? false,
      frequency: (json['frequency'] as num?)?.toInt() ?? 0,
    );
  }
}

class ShelfFilter {
  final int frequency;
  final int gain;

  ShelfFilter({this.frequency = 0, this.gain = 0});

  factory ShelfFilter.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ShelfFilter();
    return ShelfFilter(
      frequency: (json['frequency'] as num?)?.toInt() ?? 0,
      gain: (json['gain'] as num?)?.toInt() ?? 0,
    );
  }
}

class ParametricEqBand {
  final int frequency;
  final int gain;
  final EqBand band;

  ParametricEqBand({
    this.frequency = 0,
    this.gain = 0,
    this.band = EqBand.narrow,
  });

  factory ParametricEqBand.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ParametricEqBand();

    final bandStr = json['band'] as String? ?? 'Narrow';
    final bandEnum = bandStr.toLowerCase() == 'wide' ? EqBand.wide : EqBand.narrow;

    return ParametricEqBand(
      frequency: (json['frequency'] as num?)?.toInt() ?? 0,
      gain: (json['gain'] as num?)?.toInt() ?? 0,
      band: bandEnum,
    );
  }
}

class EqState {
  final HighPassFilter highPass;
  final ShelfFilter lowShelf;
  final ParametricEqBand low;
  final ParametricEqBand mid;
  final ParametricEqBand high;
  final ShelfFilter highShelf;

  EqState({
    HighPassFilter? highPass,
    ShelfFilter? lowShelf,
    ParametricEqBand? low,
    ParametricEqBand? mid,
    ParametricEqBand? high,
    ShelfFilter? highShelf,
  })  : highPass = highPass ?? HighPassFilter(),
        lowShelf = lowShelf ?? ShelfFilter(),
        low = low ?? ParametricEqBand(),
        mid = mid ?? ParametricEqBand(),
        high = high ?? ParametricEqBand(),
        highShelf = highShelf ?? ShelfFilter();

  factory EqState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return EqState();
    return EqState(
      highPass: HighPassFilter.fromJson(json['high_pass']),
      lowShelf: ShelfFilter.fromJson(json['low_shelf']),
      low: ParametricEqBand.fromJson(json['low']),
      mid: ParametricEqBand.fromJson(json['mid']),
      high: ParametricEqBand.fromJson(json['high']),
      highShelf: ShelfFilter.fromJson(json['high_shelf']),
    );
  }
}

class RoutingState {
  final bool micToPga;
  final bool lineToPga;
  final bool lineToAdcMix;
  final bool adcMixToMainMixer;
  final bool auxToMainMixer;
  final bool dacToMainMixer;

  RoutingState({
    this.micToPga = false,
    this.lineToPga = false,
    this.lineToAdcMix = false,
    this.adcMixToMainMixer = false,
    this.auxToMainMixer = false,
    this.dacToMainMixer = false,
  });

  factory RoutingState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return RoutingState();
    return RoutingState(
      micToPga: json['mic_to_pga'] as bool? ?? false,
      lineToPga: json['line_to_pga'] as bool? ?? false,
      lineToAdcMix: json['line_to_adcmix'] as bool? ?? false,
      adcMixToMainMixer: json['adcmix_to_main_mixer'] as bool? ?? false,
      auxToMainMixer: json['aux_to_main_mixer'] as bool? ?? false,
      dacToMainMixer: json['dac_to_main_mixer'] as bool? ?? false,
    );
  }
}

class PgaState {
  final bool mute;
  final double gain;
  final bool boost;

  PgaState({this.mute = false, this.gain = 0.0, this.boost = false});

  factory PgaState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PgaState();
    return PgaState(
      mute: json['mute'] as bool? ?? false,
      gain: (json['gain'] as num?)?.toDouble() ?? 0.0,
      boost: json['boost'] as bool? ?? false,
    );
  }
}

class AdcState {
  final double volume;

  AdcState({this.volume = 0.0});

  factory AdcState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AdcState();
    return AdcState(
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DacState {
  final bool mute;
  final double volume;

  DacState({this.mute = false, this.volume = 0.0});

  factory DacState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return DacState();
    return DacState(
      mute: json['mute'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MixerControlState {
  final int volumeAdcMix;
  final int volumeAux;
  final bool mono;

  MixerControlState({
    this.volumeAdcMix = 0,
    this.volumeAux = 0,
    this.mono = false,
  });

  factory MixerControlState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return MixerControlState();
    return MixerControlState(
      volumeAdcMix: (json['volume_adcmix'] as num?)?.toInt() ?? 0,
      volumeAux: (json['volume_aux'] as num?)?.toInt() ?? 0,
      mono: json['mono'] as bool? ?? false,
    );
  }
}

class HeadphonesState {
  final bool mute;
  final int volume;

  HeadphonesState({this.mute = false, this.volume = 0});

  factory HeadphonesState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return HeadphonesState();
    return HeadphonesState(
      mute: json['mute'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuxOutState {
  final bool mute;
  final bool gainBoost;
  final bool balanced;

  AuxOutState({
    this.mute = false,
    this.gainBoost = false,
    this.balanced = false,
  });

  factory AuxOutState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AuxOutState();
    return AuxOutState(
      mute: json['mute'] as bool? ?? false,
      gainBoost: json['gain_boost'] as bool? ?? false,
      balanced: json['balanced'] as bool? ?? false,
    );
  }
}

class SpeakerState {
  final bool mute;
  final bool gainBoost;
  final bool balanced;
  final int volume;

  SpeakerState({
    this.mute = false,
    this.gainBoost = false,
    this.balanced = false,
    this.volume = 0,
  });

  factory SpeakerState.fromJson(Map<String, dynamic>? json) {
    if (json == null) return SpeakerState();
    return SpeakerState(
      mute: json['mute'] as bool? ?? false,
      gainBoost: json['gain_boost'] as bool? ?? false,
      balanced: json['balanced'] as bool? ?? false,
      volume: (json['volume'] as num?)?.toInt() ?? 0,
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN NAU88 STATE TREE MODEL
// -----------------------------------------------------------------------------
class MixerState {
  final double peakOverPeriod;
  final double avgPeakOverPeriod;

  final RoutingState routing;
  final PgaState pga;
  final AdcState adc;
  final EqState eq;
  final DacState dac;
  final MixerControlState mixer;
  final HeadphonesState headphones;
  final AuxOutState auxout;
  final SpeakerState speaker;

  MixerState({
    this.peakOverPeriod = 0.0,
    this.avgPeakOverPeriod = 0.0,
    RoutingState? routing,
    PgaState? pga,
    AdcState? adc,
    EqState? eq,
    DacState? dac,
    MixerControlState? mixer,
    HeadphonesState? headphones,
    AuxOutState? auxout,
    SpeakerState? speaker,
  })  : routing = routing ?? RoutingState(),
        pga = pga ?? PgaState(),
        adc = adc ?? AdcState(),
        eq = eq ?? EqState(),
        dac = dac ?? DacState(),
        mixer = mixer ?? MixerControlState(),
        headphones = headphones ?? HeadphonesState(),
        auxout = auxout ?? AuxOutState(),
        speaker = speaker ?? SpeakerState();

  // Linear float [0.0 - 1.0] to dBFS [-60 dBFS to 0 dBFS]
  double get peakDbfs => _linearToDbfs(peakOverPeriod);
  double get avgPeakDbfs => _linearToDbfs(avgPeakOverPeriod);

  static double _linearToDbfs(double linear) {
    if (linear <= 0.00001) return -60.0;
    double db = 20 * log(linear) / ln10;
    return db.clamp(-60.0, 0.0);
  }

  factory MixerState.fromJson(Map<String, dynamic> json) {
    return MixerState(
      peakOverPeriod: (json['peak_over_period'] as num?)?.toDouble() ?? 0.0,
      avgPeakOverPeriod: (json['avg_peak_over_period'] as num?)?.toDouble() ?? 0.0,
      routing: RoutingState.fromJson(json['routing']),
      pga: PgaState.fromJson(json['pga']),
      adc: AdcState.fromJson(json['adc']),
      eq: EqState.fromJson(json['eq']),
      dac: DacState.fromJson(json['dac']),
      mixer: MixerControlState.fromJson(json['mixer']),
      headphones: HeadphonesState.fromJson(json['headphones']),
      auxout: AuxOutState.fromJson(json['auxout']),
      speaker: SpeakerState.fromJson(json['speaker']),
    );
  }
}