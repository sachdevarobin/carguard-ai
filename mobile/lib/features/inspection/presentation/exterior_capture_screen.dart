import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/photo_retake.dart';
import '../../../core/providers/providers.dart';

class ExteriorSide {
  const ExteriorSide({
    required this.category,
    required this.title,
    required this.hint,
    required this.icon,
  });

  final String category;
  final String title;
  final String hint;
  final IconData icon;
}

const exteriorSides = [
  ExteriorSide(
    category: 'front',
    title: 'Front View',
    hint: 'Place the entire front of the vehicle inside the frame.',
    icon: Icons.directions_car_filled_outlined,
  ),
  ExteriorSide(
    category: 'rear',
    title: 'Rear View',
    hint: 'Capture the full rear including bumper and tail lights.',
    icon: Icons.directions_car_filled_outlined,
  ),
  ExteriorSide(
    category: 'left',
    title: 'Left Side',
    hint: 'Stand to the left and capture the full side profile.',
    icon: Icons.directions_car_filled_outlined,
  ),
  ExteriorSide(
    category: 'right',
    title: 'Right Side',
    hint: 'Stand to the right and capture the full side profile.',
    icon: Icons.directions_car_filled_outlined,
  ),
];

class ExteriorCaptureScreen extends ConsumerWidget {
  const ExteriorCaptureScreen({super.key, required this.inspectionId});

  final int inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(inspectionDetailProvider(inspectionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exterior Photos')),
      body: inspection.when(
        data: (detail) {
          final uploaded = detail.photos.map((photo) => photo.category).toSet();
          final completed = exteriorSides.where((side) => uploaded.contains(side.category)).length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Capture all four sides',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$completed of ${exteriorSides.length} sides captured',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: completed / exteriorSides.length,
                        backgroundColor: Colors.grey.shade200,
                        color: AppColors.primary,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...exteriorSides.map((side) {
                final existing = detail.photos.where((p) => p.category == side.category).firstOrNull;
                final isDone = existing != null;
                final needsRetake = existing != null && photoNeedsRetake(existing);
                final subtitle = needsRetake
                    ? (retakeReason(existing) ?? 'Retake needed — tap to recapture')
                    : isDone
                        ? 'Captured'
                        : side.hint;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openPhotoRetake(
                      context,
                      inspectionId: inspectionId,
                      category: side.category,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: needsRetake
                                ? AppColors.critical.withValues(alpha: 0.15)
                                : isDone
                                    ? AppColors.success.withValues(alpha: 0.15)
                                    : AppColors.primary.withValues(alpha: 0.12),
                            child: Icon(
                              needsRetake
                                  ? Icons.warning_amber_rounded
                                  : isDone
                                      ? Icons.check
                                      : side.icon,
                              color: needsRetake
                                  ? AppColors.critical
                                  : isDone
                                      ? AppColors.success
                                      : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(side.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                                ),
                                if (needsRetake) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: FilledButton(
                                      onPressed: () => openPhotoRetake(
                                        context,
                                        inspectionId: inspectionId,
                                        category: side.category,
                                      ),
                                      child: const Text('Retake'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!needsRetake)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                isDone ? Icons.check_circle : Icons.camera_alt_outlined,
                                color: isDone ? AppColors.success : AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: completed == exteriorSides.length ? () => context.pop() : null,
                child: Text(
                  completed == exteriorSides.length ? 'Exterior Complete' : 'Capture all sides to continue',
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load inspection: $error')),
      ),
    );
  }
}
