import 'package:flutter/material.dart';

import '../models/mixer_state.dart';
import '../services/esp32_connection_service.dart';
import '../widgets/vu_meter/horizontal_audio_meter.dart';
import 'register_control_screen.dart';

class AdvancedDeviceControl extends StatelessWidget {
  final Esp32ConnectionService service;

  const AdvancedDeviceControl({super.key, required this.service});

  void _showEditDialog(BuildContext context, Lockable lockable, String label) {
    final controller = TextEditingController(text: lockable.value.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $label'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Command: ${lockable.command}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  labelText: 'Value',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newValue = controller.text.trim();
                service.sendCommands({lockable.command: newValue});
                Navigator.of(context).pop();
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Control'),
        backgroundColor: Colors.blueGrey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.memory, color: Colors.cyanAccent),
            tooltip: 'Registers Control',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegisterControlScreen(service: service),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<MixerState>(
        stream: service.stateStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final state = snapshot.data!;

          // Map all modules (including individual EQ sections) to a readable group name
          final Map<String, MixerModule> namedModules = {
            'Routing': state.routing,
            'PGA': state.pga,
            'ADC': state.adc,
            'DAC': state.dac,
            'Mixer Control': state.mixer,
            'Headphones': state.headphones,
            'Aux Out': state.auxout,
            'Speaker': state.speaker,
            'Client': state.client,
            'Device': state.device,
            'Wi-Fi': state.wifi,
            'EQ: High Pass': state.eq.highPass,
            'EQ: Low Shelf': state.eq.lowShelf,
            'EQ: Low': state.eq.low,
            'EQ: Mid': state.eq.mid,
            'EQ: High': state.eq.high,
            'EQ: High Shelf': state.eq.highShelf,
          };

          final List<Widget> listItems = [];

          for (final entry in namedModules.entries) {
            final String groupName = entry.key;
            final MixerModule module = entry.value;

            // Gather all Lockable properties for this module
            final List<Lockable> allProps = [];

            // 1. Check module's properties map
            for (final lockable in module.properties.values) {
              allProps.add(lockable);
            }

            // 2. Fallbacks for nested EQ properties if not mapped in properties
            if (module is HighPassFilter) {
              if (!allProps.contains(module.enabled)) allProps.add(module.enabled);
              if (!allProps.contains(module.frequency)) allProps.add(module.frequency);
            } else if (module is ShelfFilter) {
              if (!allProps.contains(module.frequency)) allProps.add(module.frequency);
              if (!allProps.contains(module.gain)) allProps.add(module.gain);
            } else if (module is ParametricEqBand) {
              if (!allProps.contains(module.frequency)) allProps.add(module.frequency);
              if (!allProps.contains(module.gain)) allProps.add(module.gain);
              if (!allProps.contains(module.band)) allProps.add(module.band);
            }

            if (allProps.isNotEmpty) {
              allProps.sort((a, b) => a.command.compareTo(b.command));

              // Add Group Header
              listItems.add(
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
                  child: Text(
                    groupName.toUpperCase(),
                    style: TextStyle(
                      color: Colors.cyanAccent.shade100,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              );

              // Add Controls (Checkboxes for bools, Editable Tiles for non-bools)
              for (final lockable in allProps) {
                // Strip the module prefix (e.g. "routing.mic_to_pga" -> "mic_to_pga")
                final String displayLabel = lockable.command.contains('.')
                    ? lockable.command.substring(lockable.command.indexOf('.') + 1)
                    : lockable.command;

                if (lockable is Lockable<bool>) {
                  // Boolean Control (Checkbox)
                  listItems.add(
                    CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 0.0,
                      ),
                      dense: true,
                      title: Text(
                        displayLabel,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      value: lockable.value,
                      activeColor: Colors.cyan,
                      checkColor: Colors.black,
                      onChanged: (bool? newValue) {
                        if (newValue != null) {
                          service.sendCommands({
                            lockable.command: newValue ? 't' : 'f',
                          });
                        }
                      },
                    ),
                  );
                } else {
                  // Non-Boolean Control (Editable Tile)
                  listItems.add(
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 0.0,
                      ),
                      dense: true,
                      title: Text(
                        displayLabel,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade800),
                            ),
                            child: Text(
                              '${lockable.value}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            color: Colors.grey,
                            onPressed: () => _showEditDialog(
                              context,
                              lockable,
                              displayLabel,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => _showEditDialog(
                        context,
                        lockable,
                        displayLabel,
                      ),
                    ),
                  );
                }
              }

              listItems.add(
                Divider(height: 1, color: Colors.grey.shade800),
              );
            }
          }

          return Column(
            children: [
              // Fixed Top Audio Meter
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: HorizontalAudioMeterWidget(
                  peak: state.peakOverPeriod,
                  showTicks: true,
                  label: 'Audio Peak',
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade800),

              // Scrollable Controls
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  children: listItems,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}