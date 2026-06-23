import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/data/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  runZonedGuarded(
    () async {
      await _bootstrap();
      runApp(const ProviderScope(child: CarGuardApp()));
    },
    (error, stack) {
      debugPrint('Uncaught error: $error\n$stack');
    },
  );
}

Future<void> _bootstrap() async {
  try {
    await AppDatabase.instance.database;
  } catch (error, stack) {
    debugPrint('Database open failed, resetting: $error\n$stack');
    try {
      await AppDatabase.instance.reset();
    } catch (resetError) {
      debugPrint('Database reset failed: $resetError');
      rethrow;
    }
  }

  try {
    await initializeDateFormatting('en_IN');
    await initializeDateFormatting('en_US');
  } catch (error) {
    debugPrint('Date locale init skipped: $error');
  }
}
