import 'dart:io';

import 'package:c2bluetooth/c2bluetooth.dart';
import 'package:flutter/foundation.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's configured destination for session recordings and PM5 sample rate, persisted
/// across app launches.
///
/// On macOS, picking a folder only grants sandboxed write access for the lifetime of the app
/// process that picked it - a fresh launch loses that access even though the path is still
/// remembered, and writing then fails with a PathAccessException. To survive relaunches, the
/// picked folder is also saved as a security-scoped bookmark, which [load] resolves and
/// re-activates on every startup.
class RecordingSettings extends ChangeNotifier {
  static const _directoryKey = 'recording_directory';
  static const _bookmarkKey = 'recording_directory_bookmark';
  static const _baseNameKey = 'recording_base_name';
  static const _enabledKey = 'recording_enabled';
  static const _sampleRateKey = 'sample_rate';
  static const defaultBaseName = 'session';

  String? _directory;
  String _baseName = defaultBaseName;
  bool _enabled = false;
  ErgSampleRate _sampleRate = ErgSampleRate.ms500;

  String? get directory => _directory;
  String get baseName => _baseName;
  ErgSampleRate get sampleRate => _sampleRate;

  /// Whether a folder has been picked - a recording folder must be set before recording can
  /// be turned on, so this gates whether the "Enable recording" toggle is interactive.
  bool get isConfigured => _directory != null && _directory!.isNotEmpty;

  /// Whether the "Enable recording" toggle is on. Only takes effect while [isConfigured].
  bool get enabled => _enabled;

  /// Whether a session should actually be recorded right now.
  bool get shouldRecord => _enabled && isConfigured;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _directory = prefs.getString(_directoryKey);
    _baseName = prefs.getString(_baseNameKey) ?? defaultBaseName;
    _enabled = prefs.getBool(_enabledKey) ?? false;
    _sampleRate = ErgSampleRate.values[
        prefs.getInt(_sampleRateKey) ?? ErgSampleRate.ms500.index];

    final bookmark = prefs.getString(_bookmarkKey);
    if (Platform.isMacOS && bookmark != null) {
      await _resumeAccess(bookmark);
    }

    notifyListeners();
  }

  /// Re-activates sandboxed write access to a previously-picked folder. Failures (e.g. the
  /// folder was moved or deleted) leave [directory] set but writes will keep failing until the
  /// user picks a folder again - [setDirectory] then overwrites the stale bookmark.
  Future<void> _resumeAccess(String bookmark) async {
    try {
      final resolved = await SecureBookmarks()
          .resolveBookmark(bookmark, isDirectory: true);
      await SecureBookmarks().startAccessingSecurityScopedResource(resolved);
    } catch (e) {
      debugPrint('RecordingSettings: could not resume folder access: $e');
    }
  }

  Future<void> setSampleRate(ErgSampleRate sampleRate) async {
    _sampleRate = sampleRate;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sampleRateKey, sampleRate.index);
  }

  Future<void> setDirectory(String? directory) async {
    _directory = directory;
    if (!isConfigured) {
      _enabled = false;
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (directory == null) {
      await prefs.remove(_directoryKey);
      await prefs.remove(_bookmarkKey);
    } else {
      await prefs.setString(_directoryKey, directory);
      if (Platform.isMacOS) {
        final bookmark =
            await SecureBookmarks().bookmark(Directory(directory));
        await prefs.setString(_bookmarkKey, bookmark);
        // The picker's own grant already covers this process; resuming access from the
        // fresh bookmark here as well keeps this path identical to the one `load` takes.
        await _resumeAccess(bookmark);
      }
    }
    await prefs.setBool(_enabledKey, _enabled);
  }

  Future<void> setBaseName(String baseName) async {
    _baseName = baseName.trim().isEmpty ? defaultBaseName : baseName.trim();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseNameKey, _baseName);
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled && isConfigured;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _enabled);
  }
}
