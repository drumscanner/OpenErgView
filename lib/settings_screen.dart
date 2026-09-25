import 'package:c2bluetooth/c2bluetooth.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';

import 'devices_list/devices_bloc_provider.dart';
import 'devices_list/devices_list_view.dart';
import 'src/recording/recording_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static String _sampleRateLabel(ErgSampleRate rate) {
    final interval = rate.interval;
    return interval.inSeconds >= 1
        ? '${interval.inSeconds} s'
        : '${interval.inMilliseconds} ms';
  }

  Future<void> _pickSampleRate(BuildContext context) async {
    final settings = context.read<RecordingSettings>();
    final rate = await showDialog<ErgSampleRate>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('PM5 sample rate'),
        children: [
          for (final rate in ErgSampleRate.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(rate),
              child: ListTile(
                title: Text(_sampleRateLabel(rate)),
                trailing:
                    rate == settings.sampleRate ? const Icon(Icons.check) : null,
              ),
            ),
        ],
      ),
    );
    if (rate != null) {
      await settings.setSampleRate(rate);
    }
  }

  Future<void> _pickRecordingDirectory(BuildContext context) async {
    final settings = context.read<RecordingSettings>();
    final directory = await getDirectoryPath(
      initialDirectory: settings.directory,
      confirmButtonText: 'Select',
      canCreateDirectories: true,
    );
    if (directory != null) {
      await settings.setDirectory(directory);
    }
  }

  Future<void> _editRecordingBaseName(BuildContext context) async {
    final settings = context.read<RecordingSettings>();
    final controller = TextEditingController(text: settings.baseName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recording file name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            helperText: 'Each session is saved as "name_1.csv", "name_2.csv", etc.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null) {
      await settings.setBaseName(newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Settings"),
        ),
        body: Consumer<RecordingSettings>(
          builder: (context, recordingSettings, _) => SettingsList(
            sections: [
              SettingsSection(
                title: Text('Connection'),
                tiles: <SettingsTile>[

                  //TODO: if theres a connected erg, show a disconnect button instead
                  SettingsTile.navigation(
                    title: Text("Connect to a PM5"),
                    onPressed: (context) => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DevicesBlocProvider(child: DevicesListScreen()),
                        )),
                  ),
                  SettingsTile.navigation(
                    title: const Text('Sample rate'),
                    description: const Text(
                        'How often the PM5 sends status updates'),
                    value: Text(_sampleRateLabel(recordingSettings.sampleRate)),
                    onPressed: _pickSampleRate,
                  ),
                ],
              ),
              SettingsSection(
                title: const Text('Recording'),
                tiles: <SettingsTile>[
                  SettingsTile.navigation(
                    title: const Text('Recording folder'),
                    value: Text(recordingSettings.directory ?? 'Not set'),
                    onPressed: _pickRecordingDirectory,
                  ),
                  SettingsTile.navigation(
                    title: const Text('File name'),
                    value: Text(recordingSettings.baseName),
                    onPressed: _editRecordingBaseName,
                  ),
                  SettingsTile.switchTile(
                    title: const Text('Enable recording'),
                    description: recordingSettings.isConfigured
                        ? null
                        : const Text('Pick a recording folder first'),
                    enabled: recordingSettings.isConfigured,
                    initialValue: recordingSettings.enabled,
                    onToggle: (value) => recordingSettings.setEnabled(value),
                  ),
                ],
              ),
            ],
          ),
        ));
  }
}
