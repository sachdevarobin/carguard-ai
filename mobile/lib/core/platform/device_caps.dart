import 'dart:io';

import 'package:flutter/foundation.dart';

/// True when running on the iOS Simulator (no camera, ML Kit is much slower).
bool get isIosSimulator {
  if (kIsWeb || !Platform.isIOS) return false;
  return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
      Platform.environment.containsKey('SIMULATOR_UDID');
}
