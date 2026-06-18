import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ai/analysis_summary.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/navigation/photo_retake.dart';
import '../../../core/navigation/restart_inspection.dart';
import '../../../core/providers/providers.dart';

class InspectionProgressScreen extends ConsumerWidget {
  const InspectionProgressScreen({super.key, required this.inspectionId});

  final int inspectionId;

  void _openStep(BuildContext context, InspectionStep step) {
    if (step.id == 'exterior' || step.photoCategories.isNotEmpty) {
      context.push('/inspection/$inspectionId/exterior');
      return;
    }
    if (step.photoCategory != null) {
      context.push(
        '/inspection/$inspectionId/capture/${step.photoCategory}'
        '?title=${Uri.encodeComponent(step.title)}'
        '&hint=${Uri.encodeComponent(step.description)}',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(inspectionDetailProvider(inspectionId));
    final steps = ref.watch(inspectionStepsProvider(inspectionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Journey'),
        actions: [
          IconButton(
            tooltip: 'Restart inspection',
            onPressed: () => confirmRestartInspection(context, ref, inspectionId: inspectionId),
            icon: const Icon(Icons.restart_alt_outlined),
          ),
        ],
      ),
      body: inspection.when(
        data: (detail) {
          return steps.when(
            data: (journeySteps) {
              final uploadedCategories = detail.photos.map((photo) => photo.category).toSet();
              final retakePhotos = photosNeedingRetake(detail.photos);
              final photoCategories = journeySteps
                  .expand((step) => step.requiredPhotoCategories)
                  .toSet();
              final completedCount = photoCategories.where(uploadedCategories.contains).length;
              final progress = photoCategories.isEmpty
                  ? 0
                  : (completedCount / photoCategories.length * 100).round();

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            detail.displayName,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: progress / 100,
                                  strokeWidth: 10,
                                  backgroundColor: Colors.grey.shade200,
                                  color: AppColors.primary,
                                ),
                                Text(
                                  '$progress%',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('Complete each step to unlock AI analysis'),
                        ],
                      ),
                    ),
                  ),
                  if (retakePhotos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${retakePhotos.length} photo${retakePhotos.length == 1 ? '' : 's'} need retake',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...retakePhotos.map(
                              (photo) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(categoryLabel(photo.category)),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FilledButton.tonal(
                                        onPressed: () async {
                                          await openPhotoRetake(
                                            context,
                                            inspectionId: inspectionId,
                                            category: photo.category,
                                          );
                                          ref.invalidate(inspectionDetailProvider(inspectionId));
                                        },
                                        child: const Text('Retake'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ...journeySteps.map((step) {
                    final isPhotoStep = step.requiredPhotoCategories.isNotEmpty;
                    final isDone = step.isComplete(uploadedCategories);
                    final subtitle = step.id == 'exterior' && isPhotoStep
                        ? '${uploadedCategories.where(step.requiredPhotoCategories.contains).length} of ${step.requiredPhotoCategories.length} sides captured'
                        : step.description;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDone
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.warning.withValues(alpha: 0.15),
                          child: Icon(
                            isDone ? Icons.check : Icons.radio_button_unchecked,
                            color: isDone ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        title: Text(step.title),
                        subtitle: Text(subtitle),
                        trailing: isPhotoStep
                            ? const Icon(Icons.camera_alt_outlined)
                            : const Icon(Icons.checklist_rtl),
                        onTap: isPhotoStep ? () => _openStep(context, step) : null,
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.push('/inspection/$inspectionId/analysis'),
                    child: const Text('Run AI Analysis'),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load steps: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load inspection: $e')),
      ),
    );
  }
}
