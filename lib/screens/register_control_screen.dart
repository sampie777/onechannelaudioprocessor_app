import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/vu_meter/horizontal_audio_meter.dart';

class Nau88RegisterDef {
  final int address;
  final String name;
  final List<String> bitNames; // Strictly ordered: Bit 0 (LSB) to Bit 8 (MSB)
  final bool readOnly;

  const Nau88RegisterDef(this.address, this.name, this.bitNames, {this.readOnly = false});
}

// -----------------------------------------------------------------------------
// NAU8822 REGISTER MAP (16-bit word: 7-bit Address, 9-bit Data)
// Ordered strictly from Bit 0 [Index 0] to Bit 8 [Index 8].
// -----------------------------------------------------------------------------
const List<Nau88RegisterDef> _nauRegisters = [
  Nau88RegisterDef(0, 'Software Reset', ['RESET', 'RESET', 'RESET', 'RESET', 'RESET', 'RESET', 'RESET', 'RESET', 'RESET']),
  Nau88RegisterDef(1, 'Power Management 1', ['REFIMP0', 'REFIMP1', 'IOBUFEN', 'ABIASEN', 'MICBIASEN', 'PLLEN', 'AUX2MXEN', 'AUX1MXEN', 'DCBUFEN']),
  Nau88RegisterDef(2, 'Power Management 2', ['LADCEN', 'RADCEN', 'LPGAEN', 'RPGAEN', 'LBSTEN', 'RBSTEN', 'SLEEP', 'LHPEN', 'RHPEN']),
  Nau88RegisterDef(3, 'Power Management 3', ['LDACEN', 'RDACEN', 'LMIXEN', 'RMIXEN', 'Reserved', 'RSPKEN', 'LSPKEN', 'AUXOUT2EN', 'AUXOUT1EN']),
  Nau88RegisterDef(4, 'Audio Interface', ['MONO', 'ADCPHS', 'DACPHS', 'AIFMT0', 'AIFMT1', 'WLEN0', 'WLEN1', 'LRP', 'BCLKP']),
  Nau88RegisterDef(5, 'Companding', ['ADDAP', 'ADCCM0', 'ADCCM1', 'DACCM0', 'DACCM1', 'CMB8', '0', '0', '0']),
  Nau88RegisterDef(6, 'Clock Control 1', ['CLKIOEN', '0', 'BCLKSEL0', 'BCLKSEL1', 'BCLKSEL2', 'MCLKSEL0', 'MCLKSEL1', 'MCLKSEL2', 'CLKM']),
  Nau88RegisterDef(7, 'Clock Control 2', ['SCLKEN', 'SMPLR0', 'SMPLR1', 'SMPLR2', '0', '0', '0', '0', '4WSPIEN']),
  Nau88RegisterDef(8, 'GPIO', ['GPIO1SEL0', 'GPIO1SEL1', 'GPIO1SEL2', '0', 'GPIO1PL', 'GPIO1PLL', '0', '0', '0']),
  Nau88RegisterDef(9, 'Jack Detect 1', ['0', '0', '0', '0', '0', 'JCKDIO', 'JCKDEN', 'JCKMIDEN0', 'JCKMIDEN1']),
  Nau88RegisterDef(10, 'DAC Control', ['LDACPL', 'RDACPL', 'AUTOMT', 'DACOS', '0', '0', 'SOFTMT', '0', '0']),
  Nau88RegisterDef(11, 'Left DAC Volume', ['LDACGAIN0', 'LDACGAIN1', 'LDACGAIN2', 'LDACGAIN3', 'LDACGAIN4', 'LDACGAIN5', 'LDACGAIN6', 'LDACGAIN7', 'LDACVU']),
  Nau88RegisterDef(12, 'Right DAC Volume', ['RDACGAIN0', 'RDACGAIN1', 'RDACGAIN2', 'RDACGAIN3', 'RDACGAIN4', 'RDACGAIN5', 'RDACGAIN6', 'RDACGAIN7', 'RDACVU']),
  Nau88RegisterDef(13, 'Jack Detect 2', ['JCKDOEN0_0', 'JCKDOEN0_1', 'JCKDOEN0_2', 'JCKDOEN0_3', 'JCKDOEN1_0', 'JCKDOEN1_1', 'JCKDOEN1_2', 'JCKDOEN1_3', '0']),
  Nau88RegisterDef(14, 'ADC Control', ['LADCPL', 'RADCPL', '0', 'ADCOS', 'HPF0', 'HPF1', 'HPF2', 'HPFAM', 'HPFEN']),
  Nau88RegisterDef(15, 'Left ADC Volume', ['LADCGAIN0', 'LADCGAIN1', 'LADCGAIN2', 'LADCGAIN3', 'LADCGAIN4', 'LADCGAIN5', 'LADCGAIN6', 'LADCGAIN7', 'LADCVU']),
  Nau88RegisterDef(16, 'Right ADC Volume', ['RADCGAIN0', 'RADCGAIN1', 'RADCGAIN2', 'RADCGAIN3', 'RADCGAIN4', 'RADCGAIN5', 'RADCGAIN6', 'RADCGAIN7', 'RADCVU']),
  Nau88RegisterDef(18, 'EQ1-high cutoff', ['EQ1GC0', 'EQ1GC1', 'EQ1GC2', 'EQ1GC3', 'EQ1GC4', 'EQ1CF0', 'EQ1CF1', '0', 'EQM']),
  Nau88RegisterDef(19, 'EQ2-peak 1', ['EQ2GC0', 'EQ2GC1', 'EQ2GC2', 'EQ2GC3', 'EQ2GC4', 'EQ2CF0', 'EQ2CF1', '0', 'EQ2BW']),
  Nau88RegisterDef(20, 'EQ3-peak 2', ['EQ3GC0', 'EQ3GC1', 'EQ3GC2', 'EQ3GC3', 'EQ3GC4', 'EQ3CF0', 'EQ3CF1', '0', 'EQ3BW']),
  Nau88RegisterDef(21, 'EQ4-peak 3', ['EQ4GC0', 'EQ4GC1', 'EQ4GC2', 'EQ4GC3', 'EQ4GC4', 'EQ4CF0', 'EQ4CF1', '0', 'EQ4BW']),
  Nau88RegisterDef(22, 'EQ5-low cutoff', ['EQ5GC0', 'EQ5GC1', 'EQ5GC2', 'EQ5GC3', 'EQ5GC4', 'EQ5CF0', 'EQ5CF1', '0', '0']),
  Nau88RegisterDef(24, 'DAC Limiter 1', ['DACLIMATK0', 'DACLIMATK1', 'DACLIMATK2', 'DACLIMATK3', 'DACLIMDCY0', 'DACLIMDCY1', 'DACLIMDCY2', 'DACLIMDCY3', 'DACLIMEN']),
  Nau88RegisterDef(25, 'DAC Limiter 2', ['DACLIMBST0', 'DACLIMBST1', 'DACLIMBST2', 'DACLIMBST3', 'DACLIMTHL0', 'DACLIMTHL1', 'DACLIMTHL2', '0', '0']),
  Nau88RegisterDef(27, 'Notch Filter 1', ['NFCA0_7', 'NFCA0_8', 'NFCA0_9', 'NFCA0_10', 'NFCA0_11', 'NFCA0_12', 'NFCA0_13', 'NFCEN', 'NFCU1']),
  Nau88RegisterDef(28, 'Notch Filter 2', ['NFCA0_0', 'NFCA0_1', 'NFCA0_2', 'NFCA0_3', 'NFCA0_4', 'NFCA0_5', 'NFCA0_6', '0', 'NFCU2']),
  Nau88RegisterDef(29, 'Notch Filter 3', ['NFCA1_7', 'NFCA1_8', 'NFCA1_9', 'NFCA1_10', 'NFCA1_11', 'NFCA1_12', 'NFCA1_13', '0', 'NFCU3']),
  Nau88RegisterDef(30, 'Notch Filter 4', ['NFCA1_0', 'NFCA1_1', 'NFCA1_2', 'NFCA1_3', 'NFCA1_4', 'NFCA1_5', 'NFCA1_6', '0', 'NFCU4']),
  Nau88RegisterDef(32, 'ALC Control 1', ['ALCMNGAIN0', 'ALCMNGAIN1', 'ALCMNGAIN2', 'ALCMXGAIN0', 'ALCMXGAIN1', 'ALCMXGAIN2', '0', 'ALCEN0', 'ALCEN1']),
  Nau88RegisterDef(33, 'ALC Control 2', ['ALCSL0', 'ALCSL1', 'ALCSL2', 'ALCSL3', 'ALCHT0', 'ALCHT1', 'ALCHT2', 'ALCHT3', '0']),
  Nau88RegisterDef(34, 'ALC Control 3', ['ALCATK0', 'ALCATK1', 'ALCATK2', 'ALCATK3', 'ALCDCY0', 'ALCDCY1', 'ALCDCY2', 'ALCDCY3', 'ALCM']),
  Nau88RegisterDef(35, 'Noise Gate', ['ALCNTH0', 'ALCNTH1', 'ALCNTH2', 'ALCNEN', '0', '0', '0', '0', '0']),
  Nau88RegisterDef(36, 'PLL N', ['PLLN0', 'PLLN1', 'PLLN2', 'PLLN3', 'PLLMCLK', '0', '0', '0', '0']),
  Nau88RegisterDef(37, 'PLL K 1', ['PLLK18', 'PLLK19', 'PLLK20', 'PLLK21', 'PLLK22', 'PLLK23', '0', '0', '0']),
  Nau88RegisterDef(38, 'PLL K 2', ['PLLK9', 'PLLK10', 'PLLK11', 'PLLK12', 'PLLK13', 'PLLK14', 'PLLK15', 'PLLK16', 'PLLK17']),
  Nau88RegisterDef(39, 'PLL K 3', ['PLLK0', 'PLLK1', 'PLLK2', 'PLLK3', 'PLLK4', 'PLLK5', 'PLLK6', 'PLLK7', 'PLLK8']),
  Nau88RegisterDef(41, '3D control', ['3DDEPTH0', '3DDEPTH1', '3DDEPTH2', '3DDEPTH3', '0', '0', '0', '0', '0']),
  Nau88RegisterDef(43, 'Right Speaker Submix', ['RAUXSMUT', 'RAUXRSUBG0', 'RAUXRSUBG1', 'RAUXRSUBG2', 'RSUBBYP', 'RMIXMUT', '0', '0', '0']),
  Nau88RegisterDef(44, 'Input Control', ['LMICPLPGA', 'LMICNLPGA', 'LLINLPGA', '0', 'RMICPRPGA', 'RMICNRPGA', 'RLINRPGA', 'MICBIASV0', 'MICBIASV1']),
  Nau88RegisterDef(45, 'Left Input PGA Gain', ['LPGAGAIN0', 'LPGAGAIN1', 'LPGAGAIN2', 'LPGAGAIN3', 'LPGAGAIN4', 'LPGAGAIN5', 'LPGAMT', 'LPGAZC', 'LPGAU']),
  Nau88RegisterDef(46, 'Right Input PGA Gain', ['RPGAGAIN0', 'RPGAGAIN1', 'RPGAGAIN2', 'RPGAGAIN3', 'RPGAGAIN4', 'RPGAGAIN5', 'RPGAMT', 'RPGAZC', 'RPGAU']),
  Nau88RegisterDef(47, 'Left ADC Boost', ['LAUXBSTGAIN0', 'LAUXBSTGAIN1', 'LAUXBSTGAIN2', '0', 'LPGABSTGAIN0', 'LPGABSTGAIN1', 'LPGABSTGAIN2', '0', 'LPGABST']),
  Nau88RegisterDef(48, 'Right ADC Boost', ['RAUXBSTGAIN0', 'RAUXBSTGAIN1', 'RAUXBSTGAIN2', '0', 'RPGABSTGAIN0', 'RPGABSTGAIN1', 'RPGABSTGAIN2', '0', 'RPGABST']),
  Nau88RegisterDef(49, 'Output Control', ['AOUTIMP', 'TSEN', 'SPKBST', 'AUX2BST', 'AUX1BST', 'RDACLMX', 'LDACRMX', '0', '0']),
  Nau88RegisterDef(50, 'Left Mixer', ['LDACLMX', 'LBYPLMX', 'LBYPMXGAIN0', 'LBYPMXGAIN1', 'LBYPMXGAIN2', 'LAUXLMX', 'LAUXMXGAIN0', 'LAUXMXGAIN1', 'LAUXMXGAIN2']),
  Nau88RegisterDef(51, 'Right Mixer', ['RDACRMX', 'RBYPRMX', 'RBYPMXGAIN0', 'RBYPMXGAIN1', 'RBYPMXGAIN2', 'RAUXRMX', 'RAUXMXGAIN0', 'RAUXMXGAIN1', 'RAUXMXGAIN2']),
  Nau88RegisterDef(52, 'LHP Volume', ['LHPGAIN0', 'LHPGAIN1', 'LHPGAIN2', 'LHPGAIN3', 'LHPGAIN4', 'LHPGAIN5', 'LHPMUTE', 'LHPZC', 'LHPVU']),
  Nau88RegisterDef(53, 'RHP Volume', ['RHPGAIN0', 'RHPGAIN1', 'RHPGAIN2', 'RHPGAIN3', 'RHPGAIN4', 'RHPGAIN5', 'RHPMUTE', 'RHPZC', 'RHPVU']),
  Nau88RegisterDef(54, 'LSPKOUT Volume', ['LSPKGAIN0', 'LSPKGAIN1', 'LSPKGAIN2', 'LSPKGAIN3', 'LSPKGAIN4', 'LSPKGAIN5', 'LSPKMUTE', 'LSPKZC', 'LSPKVU']),
  Nau88RegisterDef(55, 'RSPKOUT Volume', ['RSPKGAIN0', 'RSPKGAIN1', 'RSPKGAIN2', 'RSPKGAIN3', 'RSPKGAIN4', 'RSPKGAIN5', 'RSPKMUTE', 'RSPKZC', 'RSPKVU']),
  Nau88RegisterDef(56, 'AUX2 Mixer', ['LDACAUX2', 'LMIXAUX2', 'LADCAUX2', 'AUX1MIX>2', '0', '0', 'AUXOUT2MT', '0', '0']),
  Nau88RegisterDef(57, 'AUX1 Mixer', ['RDACAUX1', 'RMIXAUX1', 'RADCAUX1', 'LDACAUX1', 'LMIXAUX1', 'AUX1HALF', 'AUXOUT1MT', '0', '0']),
  Nau88RegisterDef(58, 'Power Management 4', ['IBADJ0', 'IBADJ1', 'REGVOLT0', 'REGVOLT1', 'MICBIASM', 'LPSPKD', 'LPADC', 'LPIPBST', 'LPDAC']),
  Nau88RegisterDef(59, 'Left Time Slot', ['LTSLOT0', 'LTSLOT1', 'LTSLOT2', 'LTSLOT3', 'LTSLOT4', 'LTSLOT5', 'LTSLOT6', 'LTSLOT7', 'LTSLOT8']),
  Nau88RegisterDef(60, 'Misc', ['LTSLOT9', 'RTSLOT9', 'Reserved', 'PUDPS', 'PUDPE', 'PUDEN', 'PCM8BIT', 'TRI', 'PCMTSEN']),
  Nau88RegisterDef(61, 'Right Time Slot', ['RTSLOT0', 'RTSLOT1', 'RTSLOT2', 'RTSLOT3', 'RTSLOT4', 'RTSLOT5', 'RTSLOT6', 'RTSLOT7', 'RTSLOT8']),
  Nau88RegisterDef(62, 'Device Revision Number', ['ID0', 'ID1', 'ID2', 'ID3', 'ID4', 'ID5', 'ID6', '0', '0'], readOnly: true),
  Nau88RegisterDef(63, 'Device ID', ['ID0', 'ID1', 'ID2', 'ID3', 'ID4', 'ID5', 'ID6', 'ID7', 'ID8'], readOnly: true),
  Nau88RegisterDef(70, 'ALC Enhancements', ['ALCGAINL0', 'ALCGAINL1', 'ALCGAINL2', 'ALCGAINL3', 'ALCGAINL4', 'ALCGAINL5', 'ALCNGSEL', 'ALCPKSEL', 'ALCTBLSEL']),
  Nau88RegisterDef(71, 'ALC Enhancements', ['ALCGAINR0', 'ALCGAINR1', 'ALCGAINR2', 'ALCGAINR3', 'ALCGAINR4', 'ALCGAINR5', 'Reserved', 'Reserved', 'PKLIMENA']),
  Nau88RegisterDef(73, 'Misc Controls', ['DACOS256', 'PLLLOKBP', 'Reserved', 'Reserved', 'FSERRENA', 'FSERFLSH', 'FSERRVAL0', 'FSERRVAL1', '4WSPIENA']),
  Nau88RegisterDef(74, 'Tie-Off Overrides', ['MANLMICP', 'MANLMICN', 'MANLLIN', 'MANLAUX', 'MANRMICP', 'MANRMICN', 'MANRLIN', 'MANRAUX', 'MANINENA']),
  Nau88RegisterDef(75, 'Power/Tie-off Ctrl', ['MANVREFL', 'MANVREFM', 'MANVREFH', 'MANINPAD', 'MANINBBP', 'IBT250DN', 'IBT500UP', 'Reserved', 'IBTHALFI']),
  Nau88RegisterDef(76, 'P2P Detector Read', ['P2PVAL0', 'P2PVAL1', 'P2PVAL2', 'P2PVAL3', 'P2PVAL4', 'P2PVAL5', 'P2PVAL6', 'P2PVAL7', 'P2PVAL8'], readOnly: true),
  Nau88RegisterDef(77, 'Peak Detector Read', ['PEAKVAL0', 'PEAKVAL1', 'PEAKVAL2', 'PEAKVAL3', 'PEAKVAL4', 'PEAKVAL5', 'PEAKVAL6', 'PEAKVAL7', 'PEAKVAL8'], readOnly: true),
  Nau88RegisterDef(78, 'Control and Status', ['FASTDEC', 'DIGMUTER', 'DIGMUTEL', 'ANAMUTE', 'NSGATE', 'HVDET', 'Reserved', 'Reserved', 'Reserved'], readOnly: true),
  Nau88RegisterDef(79, 'Output tie-off control', ['SHRTRHP', 'SHRTLHP', 'SHRTAUX2', 'SHRTAUX1', 'SHRTRSPK', 'SHRTLSPK', 'SHRTBUFL', 'SHRTBUFH', 'MANOUTEN']),
];

class RegisterControlScreen extends StatefulWidget {
  final Esp32ConnectionService service;

  const RegisterControlScreen({super.key, required this.service});

  @override
  State<RegisterControlScreen> createState() => _RegisterControlScreenState();
}

class _RegisterControlScreenState extends State<RegisterControlScreen> {
  void _onBitChanged(int regAddr, int currentVal, int bitIndex, bool isChecked) {
    int newVal;
    if (isChecked) {
      newVal = currentVal | (1 << bitIndex);
    } else {
      newVal = currentVal & ~(1 << bitIndex);
    }
    // Instantly send update command back to the ESP32
    widget.service.sendCommands({'nau88_reg.$regAddr': newVal.toString()});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Control'),
        backgroundColor: Colors.blueGrey.shade900,
      ),
      body: StreamBuilder<MixerState>(
        stream: widget.service.stateStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final state = snapshot.data!;
          final List<int> shadowRegs = state.nau88Registers;

          return Column(
            children: [
              // ---------------------------------------------------------------
              // FIXED TOP HEADER: HORIZONTAL AUDIO METER
              // ---------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: HorizontalAudioMeterWidget(
                  peak: state.peakOverPeriod, // Passed directly from state
                  showTicks: true,
                  label: 'Audio Peak',
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade800),

              // ---------------------------------------------------------------
              // SCROLLABLE REGISTER LIST
              // ---------------------------------------------------------------
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: _nauRegisters.length,
                  itemBuilder: (context, index) {
                    final regDef = _nauRegisters[index];
                    final int regValue = shadowRegs.length > regDef.address
                        ? shadowRegs[regDef.address]
                        : 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'R${regDef.address}: ${regDef.name}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.cyanAccent,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '0x${regValue.toRadixString(16).padLeft(3, '0').toUpperCase()}',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                      color: regDef.readOnly ? Colors.orangeAccent : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: List.generate(9, (bitIndexInverse) {
                                  // Lay out MSB (Bit 8) to LSB (Bit 0) from left to right
                                  final int bit = 8 - bitIndexInverse;
                                  final bool isSet = (regValue & (1 << bit)) != 0;

                                  // Use the bit number DIRECTLY to index the array.
                                  final String bitName = regDef.bitNames[bit];

                                  // Dim out the '0' or 'Reserved' bits
                                  final bool isUnused = bitName == '0' || bitName == 'Reserved';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          bitName,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: isUnused ? Colors.white24 : Colors.grey.shade400,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Checkbox(
                                          value: isSet,
                                          activeColor: Colors.cyan,
                                          checkColor: Colors.black,
                                          // Disable checkbox if the bit is unused, reserved, or the register is Read-Only
                                          onChanged: (isUnused || regDef.readOnly)
                                              ? null
                                              : (val) {
                                            if (val != null) {
                                              _onBitChanged(regDef.address, regValue, bit, val);
                                            }
                                          },
                                        ),
                                        Text(
                                          'B$bit',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            color: isUnused ? Colors.white24 : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}