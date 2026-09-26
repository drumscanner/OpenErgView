import 'dart:async';

import 'package:c2bluetooth/c2bluetooth.dart';
import 'package:c2bluetooth/helpers.dart';

/// Tracks the running average of "stroke.power" over a workout.
///
/// c2bluetooth only reports each stroke's instantaneous power, not an average, so this
/// accumulates one itself. [reset] restarts the average (e.g. when a new workout begins);
/// otherwise it keeps accumulating for as long as this tracker is listened to.
class AveragePowerTracker {
  final _controller = StreamController<String>.broadcast();
  StreamSubscription<Map<String, Object?>>? _subscription;
  double _sum = 0;
  int _count = 0;

  /// The running average pace (e.g. "2:05.0"), formatted the same way as the current-stroke
  /// pace tile, emitted after every new stroke.
  Stream<String> get averagePace => _controller.stream;

  AveragePowerTracker(Ergometer erg) {
    _subscription = erg.monitorForData({"stroke.power"}).listen((event) {
      final watts = event["stroke.power"];
      if (watts is num) {
        _sum += watts;
        _count++;
        _controller.add(wattsToSplit(_sum / _count, includeTenths: false));
      }
    });
  }

  void reset() {
    _sum = 0;
    _count = 0;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
