import 'dart:async';

import 'package:c2bluetooth/c2bluetooth.dart';
import 'package:flutter/foundation.dart';

import 'recording_settings.dart';
import 'session_recorder.dart';

/// Keeps a connected erg in line with [RecordingSettings]: records a session file whenever the
/// erg is connected and recording is enabled, and applies the configured sample rate.
///
/// Settings changes take effect immediately - enabling recording mid-connection starts the next
/// numbered file, and disabling it (or disconnecting) closes the current one.
class RecordingController {
  final Ergometer erg;
  final RecordingSettings settings;

  StreamSubscription<ErgometerConnectionState>? _connectionSubscription;
  bool _connected = false;
  ErgSampleRate? _appliedSampleRate;
  SessionRecorder? _recorder;

  RecordingController({required this.erg, required this.settings}) {
    settings.addListener(_sync);
    _connectionSubscription =
        erg.monitorConnectionState().listen(_onConnectionStateChanged);
  }

  void _onConnectionStateChanged(ErgometerConnectionState state) {
    _connected = state == ErgometerConnectionState.connected;
    // The PM5 goes back to its default rate on every new connection.
    _appliedSampleRate = null;
    _sync();
  }

  void _sync() {
    if (_connected && _appliedSampleRate != settings.sampleRate) {
      _appliedSampleRate = settings.sampleRate;
      erg.setSampleRate(settings.sampleRate);
    }

    bool shouldRecord = _connected && settings.shouldRecord;
    if (shouldRecord && _recorder == null) {
      _recorder = SessionRecorder(
        directory: settings.directory!,
        baseName: settings.baseName,
        onError: (error) {
          debugPrint('Recording failed: $error');
          _recorder = null;
        },
      )..start(erg.monitorAllData());
    } else if (!shouldRecord && _recorder != null) {
      _recorder!.stop();
      _recorder = null;
    }
  }

  Future<void> dispose() async {
    settings.removeListener(_sync);
    await _connectionSubscription?.cancel();
    await _recorder?.stop();
    _recorder = null;
  }
}
