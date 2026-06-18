import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/assistant/presentation/assistant_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/inspection/presentation/analysis_screen.dart';
import '../../features/inspection/presentation/create_inspection_screen.dart';
import '../../features/inspection/presentation/inspection_progress_screen.dart';
import '../../features/inspection/presentation/exterior_capture_screen.dart';
import '../../features/inspection/presentation/photo_capture_screen.dart';
import '../../features/inspection/presentation/results_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/inspections',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/assistant',
          builder: (context, state) => const AssistantScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/inspection/new',
      builder: (context, state) => const CreateInspectionScreen(),
    ),
    GoRoute(
      path: '/inspection/:id/progress',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return InspectionProgressScreen(inspectionId: id);
      },
    ),
    GoRoute(
      path: '/inspection/:id/exterior',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ExteriorCaptureScreen(inspectionId: id);
      },
    ),
    GoRoute(
      path: '/inspection/:id/capture/:category',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final category = state.pathParameters['category']!;
        final title = state.uri.queryParameters['title'] ?? 'Capture Photo';
        final hint = state.uri.queryParameters['hint'] ?? 'Align the vehicle inside the frame';
        return PhotoCaptureScreen(
          inspectionId: id,
          category: category,
          title: title,
          hint: hint,
        );
      },
    ),
    GoRoute(
      path: '/inspection/:id/analysis',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AnalysisScreen(inspectionId: id);
      },
    ),
    GoRoute(
      path: '/inspection/:id/results',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ResultsScreen(inspectionId: id);
      },
    ),
  ],
);
