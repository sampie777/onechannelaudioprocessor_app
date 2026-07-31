import 'dart:math';

// -----------------------------------------------------------------------------
// GENERIC LOCKABLE STATE WRAPPER
// -----------------------------------------------------------------------------
class Lockable<T> {
  T value;
  DateTime _lockUntil = DateTime.fromMillisecondsSinceEpoch(0);

  Lockable(this.value);

  // Automatically parses from incoming JSON (if lock expired)
  void updateFromJson(dynamic jsonValue) {
    if (jsonValue == null || DateTime.now().isBefore(_lockUntil)) return;

    if (T == double && jsonValue is num) {
      value = jsonValue.toDouble() as T;
    } else if (T == int && jsonValue is num) {
      value = jsonValue.toInt() as T;
    } else if (T == bool && jsonValue is bool) {
      value = jsonValue as T;
    } else if (T == String && jsonValue is String) {
      value = jsonValue as T;
    }
  }

  // Parses from outgoing command strings (e.g. "t", "-12") and applies 2-sec lock
  void updateFromStringCommand(String strVal) {
    T? parsed;

    if (T == bool) {
      parsed = (strVal == 't' || strVal == 'true' || strVal == '1') as T;
    } else if (T == int) {
      parsed = int.tryParse(strVal) as T?;
    } else if (T == double) {
      parsed = double.tryParse(strVal) as T?;
    } else if (T == String) {
      parsed = strVal as T?;
    }

    if (parsed != null) {
      value = parsed;
      _lockUntil = DateTime.now().add(const Duration(seconds: 2));
    }
  }
}

// -----------------------------------------------------------------------------
// BASE MODULE CLASS
// -----------------------------------------------------------------------------
abstract class MixerModule {
  // Modules map their JSON keys to their internal Lockable objects here
  Map<String, Lockable> get properties;

  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    json.forEach((key, val) {
      if (properties.containsKey(key)) {
        properties[key]!.updateFromJson(val);
      }
    });
  }

  void applyOptimisticCommand(String param, String value) {
    if (properties.containsKey(param)) {
      properties[param]!.updateFromStringCommand(value);
    }
  }
}

// -----------------------------------------------------------------------------
// MODULE COMPONENTS
// -----------------------------------------------------------------------------
class RoutingState extends MixerModule {
  final Lockable<bool> micToPga = Lockable(false);
  final Lockable<bool> lineToPga = Lockable(false);
  final Lockable<bool> lineToAdcMix = Lockable(false);
  final Lockable<bool> adcMixToMainMixer = Lockable(false);
  final Lockable<bool> auxToMainMixer = Lockable(false);
  final Lockable<bool> dacToMainMixer = Lockable(false);

  @override
  Map<String, Lockable> get properties => {
    'mic_to_pga': micToPga,
    'line_to_pga': lineToPga,
    'line_to_adcmix': lineToAdcMix,
    'adcmix_to_main_mixer': adcMixToMainMixer,
    'aux_to_main_mixer': auxToMainMixer,
    'dac_to_main_mixer': dacToMainMixer,
  };
}

class PgaState extends MixerModule {
  final Lockable<bool> mute = Lockable(false);
  final Lockable<double> gain = Lockable(0.0);
  final Lockable<bool> boost = Lockable(false);

  @override
  Map<String, Lockable> get properties => {
    'mute': mute,
    'gain': gain,
    'boost': boost,
  };
}

class AdcState extends MixerModule {
  final Lockable<double> volume = Lockable(0.0);

  @override
  Map<String, Lockable> get properties => {'volume': volume};
}

class DacState extends MixerModule {
  final Lockable<bool> mute = Lockable(false);
  final Lockable<double> volume = Lockable(0.0);

  @override
  Map<String, Lockable> get properties => {'mute': mute, 'volume': volume};
}

class MixerControlState extends MixerModule {
  final Lockable<int> volumeAdcMix = Lockable(0);
  final Lockable<int> volumeAux = Lockable(0);
  final Lockable<bool> mono = Lockable(false);

  @override
  Map<String, Lockable> get properties => {
    'volume_adcmix': volumeAdcMix,
    'volume_aux': volumeAux,
    'mono': mono,
  };
}

class HeadphonesState extends MixerModule {
  final Lockable<bool> mute = Lockable(false);
  final Lockable<int> volume = Lockable(0);

  @override
  Map<String, Lockable> get properties => {'mute': mute, 'volume': volume};
}

class AuxOutState extends MixerModule {
  final Lockable<bool> mute = Lockable(false);
  final Lockable<bool> gainBoost = Lockable(false);
  final Lockable<bool> balanced = Lockable(false);

  @override
  Map<String, Lockable> get properties => {
    'mute': mute,
    'gain_boost': gainBoost,
    'balanced': balanced,
  };
}

class SpeakerState extends MixerModule {
  final Lockable<bool> mute = Lockable(false);
  final Lockable<bool> gainBoost = Lockable(false);
  final Lockable<bool> balanced = Lockable(false);
  final Lockable<int> volume = Lockable(0);

  @override
  Map<String, Lockable> get properties => {
    'mute': mute,
    'gain_boost': gainBoost,
    'balanced': balanced,
    'volume': volume,
  };
}

class ClientState extends MixerModule {
  final Lockable<int> smallUpdateIntervalMs = Lockable(0);
  final Lockable<int> bigUpdateIntervalMs = Lockable(0);

  @override
  Map<String, Lockable> get properties => {
    'small_update_interval_ms': smallUpdateIntervalMs,
    'big_update_interval_ms': bigUpdateIntervalMs,
  };
}

// -----------------------------------------------------------------------------
// NESTED EQ COMPONENTS
// -----------------------------------------------------------------------------
class HighPassFilter extends MixerModule {
  final Lockable<bool> enabled = Lockable(false);
  final Lockable<int> frequency = Lockable(0);

  @override Map<String, Lockable> get properties => {'enabled': enabled, 'frequency': frequency};
}

class ShelfFilter extends MixerModule {
  final Lockable<int> frequency = Lockable(0);
  final Lockable<int> gain = Lockable(0);

  @override Map<String, Lockable> get properties => {'frequency': frequency, 'gain': gain};
}

class ParametricEqBand extends MixerModule {
  final Lockable<int> frequency = Lockable(0);
  final Lockable<int> gain = Lockable(0);
  final Lockable<String> band = Lockable('narrow'); // Using string for wide/narrow enum

  @override Map<String, Lockable> get properties => {'frequency': frequency, 'gain': gain, 'band': band};
}

class EqState extends MixerModule {
  final HighPassFilter highPass = HighPassFilter();
  final ShelfFilter lowShelf = ShelfFilter();
  final ParametricEqBand low = ParametricEqBand();
  final ParametricEqBand mid = ParametricEqBand();
  final ParametricEqBand high = ParametricEqBand();
  final ShelfFilter highShelf = ShelfFilter();

  @override
  Map<String, Lockable> get properties => {}; // Unused for nested parent

  @override
  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('high_pass')) highPass.updateFromJson(json['high_pass']);
    if (json.containsKey('low_shelf')) lowShelf.updateFromJson(json['low_shelf']);
    if (json.containsKey('low')) low.updateFromJson(json['low']);
    if (json.containsKey('mid')) mid.updateFromJson(json['mid']);
    if (json.containsKey('high')) high.updateFromJson(json['high']);
    if (json.containsKey('high_shelf')) highShelf.updateFromJson(json['high_shelf']);
  }

  // Handles deep commands like 'eq.low.gain=5'
  void applyNestedCommand(String subModule, String param, String value) {
    switch (subModule) {
      case 'high_pass': highPass.applyOptimisticCommand(param, value); break;
      case 'low_shelf': lowShelf.applyOptimisticCommand(param, value); break;
      case 'low': low.applyOptimisticCommand(param, value); break;
      case 'mid': mid.applyOptimisticCommand(param, value); break;
      case 'high': high.applyOptimisticCommand(param, value); break;
      case 'high_shelf': highShelf.applyOptimisticCommand(param, value); break;
    }
  }
}


// -----------------------------------------------------------------------------
// MAIN STATE TREE
// -----------------------------------------------------------------------------
class MixerState {
  double peakOverPeriod = 0.0;
  double avgPeakOverPeriod = 0.0;

  // 1. Declare the modules
  late final RoutingState routing;
  late final PgaState pga;
  late final AdcState adc;
  late final EqState eq;
  late final DacState dac;
  late final MixerControlState mixer;
  late final HeadphonesState headphones;
  late final AuxOutState auxout;
  late final SpeakerState speaker;
  late final ClientState client;

  // 2. Module Registry for automated looping
  final Map<String, MixerModule> _modules = {};

  MixerState() {
    routing = RoutingState();
    pga = PgaState();
    adc = AdcState();
    eq = EqState();
    dac = DacState();
    mixer = MixerControlState();
    headphones = HeadphonesState();
    auxout = AuxOutState();
    speaker = SpeakerState();
    client = ClientState();

    _modules['routing'] = routing;
    _modules['pga'] = pga;
    _modules['adc'] = adc;
    _modules['eq'] = eq;
    _modules['dac'] = dac;
    _modules['mixer'] = mixer;
    _modules['headphones'] = headphones;
    _modules['auxout'] = auxout;
    _modules['speaker'] = speaker;
    _modules['client'] = client;
  }

  // Linear float [0.0 - 1.0] to dBFS [-60 dBFS to 0 dBFS]
  double get peakDbfs => _linearToDbfs(peakOverPeriod);
  double get avgPeakDbfs => _linearToDbfs(avgPeakOverPeriod);

  static double _linearToDbfs(double linear) {
    if (linear <= 0.00001) return -60.0;
    double db = 20 * log(linear) / ln10;
    return db.clamp(-60.0, 0.0);
  }

  // Automatically parses all standard incoming JSON (Meters + UI State)
  void updateFromJson(Map<String, dynamic> json) {
    // 1. Fast Meter Updates
    if (json.containsKey('peak_over_period')) {
      peakOverPeriod = (json['peak_over_period'] as num).toDouble();
    }
    if (json.containsKey('avg_peak_over_period')) {
      avgPeakOverPeriod = (json['avg_peak_over_period'] as num).toDouble();
    }

    // 2. Slow UI State Updates routed automatically
    json.forEach((key, val) {
      if (_modules.containsKey(key)) {
        _modules[key]!.updateFromJson(val as Map<String, dynamic>);
      }
    });
  }

  // Automatically applies timestamps and updates from outgoing commands
  void updateFromCommands(Map<String, String> commands) {
    commands.forEach((key, value) {
      final parts = key.split('.');
      if (parts.isNotEmpty) {
        final moduleName = parts[0];

        if (_modules.containsKey(moduleName)) {
          if (parts.length == 2) {
            // Standard command (e.g. "speaker.mute")
            _modules[moduleName]!.applyOptimisticCommand(parts[1], value);
          } else if (parts.length == 3 && moduleName == 'eq') {
            // Nested EQ command (e.g. "eq.low.gain")
            (_modules['eq'] as EqState).applyNestedCommand(parts[1], parts[2], value);
          }
        }
      }
    });
  }
}