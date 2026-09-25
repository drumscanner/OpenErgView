import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

/// Records every field from a rowing session's live data stream to a CSV file.
///
/// Each call to [start] writes to its own numbered file - "<baseName>_1.csv",
/// "<baseName>_2.csv", and so on - inside [directory], using the first number not already
/// taken so nothing from a previous session gets overwritten.
class SessionRecorder {
  final String directory;
  final String baseName;

  /// Called if writing fails partway through (e.g. lost folder permission, disk full, or the
  /// folder was removed) - otherwise a failure would only surface as a Flutter zone error with
  /// nothing to show the user, and recording would silently stop producing data.
  final void Function(Object error)? onError;

  IOSink? _sink;
  StreamSubscription<Map<String, Object?>>? _subscription;

  SessionRecorder(
      {required this.directory, required this.baseName, this.onError});

  bool get isRecording => _subscription != null;

  Future<void> start(Stream<Map<String, Object?>> dataStream) async {
    await stop();

    final sink = _nextAvailableFile().openWrite();
    // Errors on this file (e.g. permission lost, disk full) surface here asynchronously,
    // not from the openWrite()/writeln() calls themselves.
    unawaited(sink.done.catchError((Object error) {
      onError?.call(error);
      stop();
    }));
    sink.writeln('timestamp,key,value');
    _sink = sink;

    _subscription = dataStream.listen(
      (event) {
        final timestamp = DateTime.now().toIso8601String();
        for (final entry in event.entries) {
          sink.writeln(
              '$timestamp,${entry.key},${_formatValue(entry.value)}');
        }
      },
      onError: (Object error) => onError?.call(error),
    );
  }

  /// Keeps every value to a single comma-free CSV cell.
  static String _formatValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is Duration) {
      return (value.inMicroseconds / Duration.microsecondsPerSecond).toString();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is List) {
      return value.join(';');
    }
    return value.toString();
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;

    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {
      // Already failed via onError above; nothing more to clean up.
    }
    _sink = null;
  }

  File _nextAvailableFile() {
    int count = 1;
    File candidate;
    do {
      candidate = File(path.join(directory, '${baseName}_$count.csv'));
      count++;
    } while (candidate.existsSync());
    return candidate;
  }
}
