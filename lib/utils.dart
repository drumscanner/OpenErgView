import 'package:c2bluetooth/helpers.dart';
import 'package:flutter/material.dart';

import 'src/ergometerstore.dart';

bool isTouchDevice(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.fuchsia;
}

bool isPointerDevice(BuildContext context) => !isTouchDevice(context);

String durationFormatter(Duration value) {
  int seconds = value.inSeconds - (value.inMinutes * Duration.secondsPerMinute);
  return "${value.inMinutes}:$seconds";
}

Stream<double>? getDoubleDataStream(ErgometerStore? ergstore, String datakey) {
  return ergstore?.erg?.monitorForData({datakey}).map((event) {
    return event[datakey] as double;
  });
}

Stream<String>? getStringDataStream(ErgometerStore? ergstore, String datakey) {
  return ergstore?.erg?.monitorForData({datakey}).map((event) {
    return event[datakey].toString();
  });
}

/// Formats a per-500m pace field (e.g. "status1.current_pace",
/// "status1.average_pace") - both already reported by the erg itself, rather than something
/// we'd need to derive from power.
Stream<String>? getPaceDataStream(ErgometerStore? ergstore, String datakey) {
  return ergstore?.erg?.monitorForData({datakey}).map((event) {
    return durationToSplit(event[datakey] as Duration, includeTenths: false);
  });
}

Stream<String>? getDurationDataStream(
    ErgometerStore? ergstore, String datakey) {
  return ergstore?.erg?.monitorForData({datakey}).map((event) {
    return durationFormatter(event[datakey] as Duration);
  });
}
