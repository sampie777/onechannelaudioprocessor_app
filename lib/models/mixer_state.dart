import '../utils/math.dart';

// -----------------------------------------------------------------------------
// GENERIC LOCKABLE STATE WRAPPER
// -----------------------------------------------------------------------------
class Lockable<T> {
  T value;
  DateTime _lockUntil = DateTime.fromMillisecondsSinceEpoch(0);
  final String command;

  Lockable(this.value, {required this.command});

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
  final Lockable<bool> micToPga = Lockable(
    false,
    command: 'routing.mic_to_pga',
  );
  final Lockable<bool> lineMonoToPga = Lockable(
    false,
    command: 'routing.line_mono_to_pga',
  );
  final Lockable<bool> lineStereoToPga = Lockable(
    false,
    command: 'routing.line_stereo_to_pga',
  );
  final Lockable<bool> lineStereoToAdcMix = Lockable(
    false,
    command: 'routing.line_stereo_to_adcmix',
  );
  final Lockable<bool> adcMixToMainMixer = Lockable(
    false,
    command: 'routing.adcmix_to_main_mixer',
  );
  final Lockable<bool> auxToMainMixer = Lockable(
    false,
    command: 'routing.aux_to_main_mixer',
  );
  final Lockable<bool> adcToDac = Lockable(
    false,
    command: 'routing.adc_to_dac',
  );
  final Lockable<bool> dacToMainMixer = Lockable(
    false,
    command: 'routing.dac_to_main_mixer',
  );

  @override
  Map<String, Lockable> get properties => {
    'mic_to_pga': micToPga,
    'line_mono_to_pga': lineMonoToPga,
    'line_stereo_to_pga': lineStereoToPga,
    'line_stereo_to_adcmix': lineStereoToAdcMix,
    'adcmix_to_main_mixer': adcMixToMainMixer,
    'aux_to_main_mixer': auxToMainMixer,
    'adc_to_dac': adcToDac,
    'dac_to_main_mixer': dacToMainMixer,
  };
}

class PgaState extends MixerModule {
  final Lockable<bool> mute = Lockable(false, command: 'pga.mute');
  final Lockable<double> gain = Lockable(0.0, command: 'pga.gain');
  final Lockable<bool> boost = Lockable(false, command: 'pga.boost');

  @override
  Map<String, Lockable> get properties => {
    'mute': mute,
    'gain': gain,
    'boost': boost,
  };
}

class AdcState extends MixerModule {
  final Lockable<double> volume = Lockable(0.0, command: 'adc.volume');
  final Lockable<bool> pcmInsteadOfI2sMode = Lockable(true, command: 'adc.pcm_instead_of_i2s_mode');

  @override
  Map<String, Lockable> get properties => {
    'volume': volume,
    'pcm_instead_of_i2s_mode': pcmInsteadOfI2sMode,
  };
}

class DacState extends MixerModule {
  final Lockable<bool> mute = Lockable(false, command: 'dac.mute');
  final Lockable<double> volume = Lockable(0.0, command: 'dac.volume');

  @override
  Map<String, Lockable> get properties => {'mute': mute, 'volume': volume};
}

class MixerControlState extends MixerModule {
  final Lockable<int> volumeAdcMix = Lockable(
    0,
    command: 'mixer.volume_adcmix',
  );
  final Lockable<int> volumeAux = Lockable(0, command: 'mixer.volume_aux');
  final Lockable<bool> mono = Lockable(false, command: 'mixer.mono');

  @override
  Map<String, Lockable> get properties => {
    'volume_adcmix': volumeAdcMix,
    'volume_aux': volumeAux,
    'mono': mono,
  };
}

class HeadphonesState extends MixerModule {
  final Lockable<bool> mute = Lockable(false, command: 'headphones.mute');
  final Lockable<int> volume = Lockable(0, command: 'headphones.volume');

  @override
  Map<String, Lockable> get properties => {'mute': mute, 'volume': volume};
}

class AuxOutState extends MixerModule {
  final Lockable<bool> mute = Lockable(false, command: 'auxout.mute');
  final Lockable<bool> gainBoost = Lockable(
    false,
    command: 'auxout.gain_boost',
  );
  final Lockable<bool> balanced = Lockable(false, command: 'auxout.balanced');

  @override
  Map<String, Lockable> get properties => {
    'mute': mute,
    'gain_boost': gainBoost,
    'balanced': balanced,
  };
}

class SpeakerState extends MixerModule {
  final Lockable<bool> mute = Lockable(false, command: 'speaker.mute');
  final Lockable<bool> gainBoost = Lockable(
    false,
    command: 'speaker.gain_boost',
  );
  final Lockable<bool> balanced = Lockable(false, command: 'speaker.balanced');
  final Lockable<int> volume = Lockable(0, command: 'speaker.volume');

  @override
  Map<String, Lockable> get properties => {
    'mute': mute,
    'gain_boost': gainBoost,
    'balanced': balanced,
    'volume': volume,
  };
}

class ClientState extends MixerModule {
  final Lockable<int> smallUpdateIntervalMs = Lockable(
    0,
    command: 'client.small_update_interval_ms',
  );
  final Lockable<int> bigUpdateIntervalMs = Lockable(
    0,
    command: 'client.big_update_interval_ms',
  );

  @override
  Map<String, Lockable> get properties => {
    'small_update_interval_ms': smallUpdateIntervalMs,
    'big_update_interval_ms': bigUpdateIntervalMs,
  };
}

class DeviceState extends MixerModule {
  final Lockable<bool> enableStatusLights = Lockable(
    true,
    command: 'device.enable_status_lights',
  );
  final Lockable<bool> buttonMiscPressed = Lockable(
    false,
    command: 'device.button_misc_pressed',
  );
  final Lockable<bool> groundLiftEnabled = Lockable(
    false,
    command: 'device.ground_lift_enabled',
  );
  final Lockable<bool> inputXlrDetected = Lockable(
    false,
    command: 'device.input_xlr_detected',
  );
  final Lockable<bool> inputJackDetected = Lockable(
    false,
    command: 'device.input_jack_detected',
  );
  final Lockable<bool> outputXlrDetected = Lockable(
    false,
    command: 'device.output_xlr_detected',
  );
  final Lockable<bool> outputJackDetected = Lockable(
    false,
    command: 'device.output_jack_detected',
  );
  final Lockable<bool> autoSwitchInputMode = Lockable(
    true,
    command: 'device.auto_switch_input_mode',
  );
  final Lockable<bool> autoSwitchOutputMode = Lockable(
    true,
    command: 'device.auto_switch_output_mode',
  );

  @override
  Map<String, Lockable> get properties => {
    'enable_status_lights': enableStatusLights,
    'button_misc_pressed': buttonMiscPressed,
    'ground_lift_enabled': groundLiftEnabled,
    'input_xlr_detected': inputXlrDetected,
    'input_jack_detected': inputJackDetected,
    'output_xlr_detected': outputXlrDetected,
    'output_jack_detected': outputJackDetected,
    'auto_switch_input_mode': autoSwitchInputMode,
    'auto_switch_output_mode': autoSwitchOutputMode,
  };
}

class WifiState extends MixerModule {
  final Lockable<String> ssid = Lockable("", command: 'wifi.ssid');
  final Lockable<String> ip = Lockable("", command: 'wifi.ip');
  final Lockable<bool> connected = Lockable(false, command: 'wifi.connected');

  @override
  Map<String, Lockable> get properties => {
    'ssid': ssid,
    'ip': ip,
    'connected': connected,
  };
}

// -----------------------------------------------------------------------------
// NESTED EQ COMPONENTS
// -----------------------------------------------------------------------------
class HighPassFilter extends MixerModule {
  final int defaultFreq;
  final Lockable<bool> enabled;
  final Lockable<int> frequency;

  HighPassFilter({this.defaultFreq = 4, required String commandPrefix})
    : frequency = Lockable(defaultFreq, command: '$commandPrefix.frequency'),
      enabled = Lockable(true, command: '$commandPrefix.enabled');

  @override
  Map<String, Lockable> get properties => {
    'enabled': enabled,
    'frequency': frequency,
  };
}

class ShelfFilter extends MixerModule {
  final int defaultFreq;
  bool isBypassed = false;
  int storedGain = 0;

  final Lockable<int> frequency;
  final Lockable<int> gain;

  ShelfFilter({this.defaultFreq = 80, required String commandPrefix})
    : frequency = Lockable(defaultFreq, command: '$commandPrefix.frequency'),
      gain = Lockable(0, command: '$commandPrefix.gain');

  @override
  Map<String, Lockable> get properties => {
    'frequency': frequency,
    'gain': gain,
  };

  @override
  void updateFromJson(Map<String, dynamic>? json) {
    super.updateFromJson(json);
    // Auto-unbypass if another device on the network sets a non-zero gain
    if (gain.value != 0 && isBypassed) isBypassed = false;
  }

  // Helper to ensure the UI slider shows the stored gain when bypassed
  int get uiGain => isBypassed ? storedGain : gain.value;
}

class ParametricEqBand extends MixerModule {
  final int defaultFreq;
  bool isBypassed = false;
  int storedGain = 0;

  final Lockable<int> frequency;
  final Lockable<int> gain;
  final Lockable<String> band;

  ParametricEqBand({this.defaultFreq = 230, required String commandPrefix})
    : frequency = Lockable(defaultFreq, command: '$commandPrefix.frequency'),
      gain = Lockable(0, command: '$commandPrefix.gain'),
      band = Lockable('narrow', command: '$commandPrefix.band');

  @override
  Map<String, Lockable> get properties => {
    'frequency': frequency,
    'gain': gain,
    'band': band,
  };

  @override
  void updateFromJson(Map<String, dynamic>? json) {
    super.updateFromJson(json);
    if (gain.value != 0 && isBypassed) isBypassed = false;
  }

  int get uiGain => isBypassed ? storedGain : gain.value;
}

class EqState extends MixerModule {
  // Inject the correct lowest allowed frequency for each specific band
  final HighPassFilter highPass = HighPassFilter(
    defaultFreq: 4,
    commandPrefix: "eq.high_pass",
  );
  final ShelfFilter lowShelf = ShelfFilter(
    defaultFreq: 105,
    commandPrefix: "eq.low_shelf",
  );
  final ParametricEqBand low = ParametricEqBand(
    defaultFreq: 300,
    commandPrefix: 'eq.low',
  );
  final ParametricEqBand mid = ParametricEqBand(
    defaultFreq: 850,
    commandPrefix: "eq.mid",
  );
  final ParametricEqBand high = ParametricEqBand(
    defaultFreq: 2400,
    commandPrefix: "eq.high",
  );
  final ShelfFilter highShelf = ShelfFilter(
    defaultFreq: 6900,
    commandPrefix: "eq.high_shelf",
  );

  @override
  Map<String, Lockable> get properties => {}; // Unused for nested parent

  @override
  void updateFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    if (json.containsKey('high_pass'))
      highPass.updateFromJson(json['high_pass']);
    if (json.containsKey('low_shelf'))
      lowShelf.updateFromJson(json['low_shelf']);
    if (json.containsKey('low')) low.updateFromJson(json['low']);
    if (json.containsKey('mid')) mid.updateFromJson(json['mid']);
    if (json.containsKey('high')) high.updateFromJson(json['high']);
    if (json.containsKey('high_shelf'))
      highShelf.updateFromJson(json['high_shelf']);
  }

  // Handles deep commands like 'eq.low.gain=5'
  void applyNestedCommand(String subModule, String param, String value) {
    switch (subModule) {
      case 'high_pass':
        highPass.applyOptimisticCommand(param, value);
        break;
      case 'low_shelf':
        lowShelf.applyOptimisticCommand(param, value);
        break;
      case 'low':
        low.applyOptimisticCommand(param, value);
        break;
      case 'mid':
        mid.applyOptimisticCommand(param, value);
        break;
      case 'high':
        high.applyOptimisticCommand(param, value);
        break;
      case 'high_shelf':
        highShelf.applyOptimisticCommand(param, value);
        break;
    }
  }
}

// -----------------------------------------------------------------------------
// MAIN STATE TREE
// -----------------------------------------------------------------------------
class MixerState {
  double peakOverPeriod = 0.0;
  double avgPeakOverPeriod = 0.0;
  int? stateVersion;
  List<double> spectrum = List.filled(32, -80.0);
  int fftWindowSize = 2048;

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
  late final DeviceState device;
  late final WifiState wifi;

  // Module Registry for automated looping
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
    device = DeviceState();
    wifi = WifiState();

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
    _modules['device'] = device;
    _modules['wifi'] = wifi;
  }

  List<int> nau88Registers = List.filled(128, 0);

  double get peakDbfs => rawToDbfs(peakOverPeriod);

  double get avgPeakDbfs => rawToDbfs(avgPeakOverPeriod);

  // Automatically parses all standard incoming JSON (Meters + UI State)
  void updateFromJson(Map<String, dynamic> json) {
    // 1. Fast Meter Updates
    if (json.containsKey('peak_over_period')) {
      peakOverPeriod = (json['peak_over_period'] as num).toDouble();
    }
    if (json.containsKey('avg_peak_over_period')) {
      avgPeakOverPeriod = (json['avg_peak_over_period'] as num).toDouble();
    }
    if (json.containsKey('state_version')) {
      stateVersion = (json['state_version'] as num).toInt();
    }
    if (json.containsKey('spectrum')) {
      final List<dynamic> spec = json['spectrum'];
      for (int i = 0; i < spec.length && i < 32; i++) {
        spectrum[i] = (spec[i] as num).toDouble();
      }
    }
    if (json.containsKey('fft_window_size')) {
      fftWindowSize = (json['fft_window_size'] as num).toInt();
    }

    if (json.containsKey('nau88_reg')) {
      final List<dynamic> regs = json['nau88_reg'];
      for (int i = 0; i < regs.length && i < 128; i++) {
        nau88Registers[i] = (regs[i] as num).toInt();
      }
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

        if (moduleName == 'nau88_reg' && parts.length == 2) {
          final int? regAddr = int.tryParse(parts[1]);
          final int? regValue = int.tryParse(value);

          if (regAddr != null &&
              regAddr >= 0 &&
              regAddr < 128 &&
              regValue != null) {
            nau88Registers[regAddr] = regValue;
          }
        }

        if (_modules.containsKey(moduleName)) {
          if (parts.length == 2) {
            // Standard command (e.g. "speaker.mute")
            _modules[moduleName]!.applyOptimisticCommand(parts[1], value);
          } else if (parts.length == 3 && moduleName == 'eq') {
            // Nested EQ command (e.g. "eq.low.gain")
            (_modules['eq'] as EqState).applyNestedCommand(
              parts[1],
              parts[2],
              value,
            );
          }
        }
      }
    });
  }
}
