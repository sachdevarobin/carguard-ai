import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../widgets/layout_helpers.dart';

/// Confirms and restarts an inspection (clears photos, findings, score).
Future<void> confirmRestartInspection(
  BuildContext context,
  WidgetRef ref, {
  required int inspectionId,
  bool goToProgress = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.restart_alt_outlined),
      title: const Text('Restart inspection?'),
      content: const FullWidth(
        child: Text(
          'This clears all captured photos, AI results, and scores for this vehicle. '
          'Your make, model, and variant selection are kept.\n\n'
          'This cannot be undone.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Restart'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final repo = ref.read(inspectionRepositoryProvider);
    await repo.restartInspection(inspectionId);
    ref.invalidate(inspectionDetailProvider(inspectionId));
    ref.invalidate(inspectionStepsProvider(inspectionId));
    ref.invalidate(inspectionsProvider);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inspection restarted — capture photos again')),
    );

    if (goToProgress) {
      context.go('/inspection/$inspectionId/progress');
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not restart: $error')),
      );
    }
  }
}
