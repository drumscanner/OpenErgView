import 'dart:async';

import 'package:c2bluetooth/c2bluetooth.dart';
import 'package:c2bluetooth/helpers.dart';

/// Tracks pace from "stroke.power" over a workout, both the current stroke's and the running
/// average since the workout began.
///
/// Both are exposed from a single persistent subscription rather than one made fresh per widget
/// rebuild (e.g. via a plain `erg.monitorForData(...)` call in a build method): "stroke.power"
/// only arrives once per stroke, so a stream that gets discarded and resubscribed on every
/// rebuild can permanently miss it if rebuilds happen more often than strokes complete, leaving
/// a tile stuck on its default value.
class PowerTracker {
  final _currentController = StreamController<String>.broadcast();
  final _averageController = StreamController<String>.broadcast();
  StreamSubscription<Map<String, Object?>>? _subscription;
  double _sum = 0;
  int _count = 0;

  /// The current stroke's pace (e.g. "2:05.0").
  Stream<String> get currentPace => _currentController.stream;

  /// The running average pace since the workout began (or since the last [reset]).
  Stream<String> get averagePace => _averageController.stream;

  PowerTracker(Ergometer erg) {
    _subscription = erg.monitorForData({"stroke.power"}).listen((event) {
      final watts = event["stroke.power"];
      if (watts is num) {
        _currentController.add(wattsToSplit(watts.toDouble(), includeTenths: false));

        _sum += watts;
        _count++;
        _averageController.add(wattsToSplit(_sum / _count, includeTenths: false));
      }
    });
  }

  /// Restarts the running average (e.g. when a new workout begins). The current-stroke pace is
  /// unaffected, since it isn't accumulated.
  void reset() {
    _sum = 0;
    _count = 0;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _currentController.close();
    await _averageController.close();
  }
}
