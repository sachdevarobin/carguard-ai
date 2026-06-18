import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/data/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.database;
  await initializeDateFormatting('en_IN');
  await initializeDateFormatting('en_US');

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };

  runZonedGuarded(
    () => runApp(const ProviderScope(child: CarGuardApp())),
    (error, stack) {
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}
