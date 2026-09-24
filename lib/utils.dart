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

Stream<String>? getSplitDataStream(ErgometerStore? ergstore, String datakey) {
  return ergstore?.erg?.monitorForData({datakey}).map((event) {
    var watts = event[datakey] as num;
    return wattsToSplit(watts.toDouble(), includeTenths: false);
  });
}

Stream<String>? getDurationDataStream(
    ErgometerStore? ergstore, String datakey) {
  return ergstore?.erg?.monitorForData({datakey}).map((event) {
    return durationFormatter(event[datakey] as Duration);
  });
}
