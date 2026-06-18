import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/analysis_detail_widgets.dart';
import '../../../core/ai/analysis_summary.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/navigation/photo_retake.dart';
import '../../../core/navigation/restart_inspection.dart';
import '../../../core/providers/providers.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, required this.inspectionId});

  final int inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(inspectionDetailProvider(inspectionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Results'),
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
          final score = detail.score ?? 0;
          final retakePhotos = photosNeedingRetake(detail.photos);
          final good = detail.findings
              .where((f) => f.severity == 'good' && f.type != 'retake_photo')
              .toList();
          final attention = detail.findings
              .where((f) => f.severity == 'attention' && f.type != 'retake_photo')
              .toList();
          final critical = detail.findings.where((f) => f.severity == 'critical').toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('Vehicle Health', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: score / 100,
                              strokeWidth: 10,
                              color: _scoreColor(score),
                              backgroundColor: Colors.grey.shade200,
                            ),
                            Text(
                              '$score/100',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        detail.report?.verdict ?? 'Analysis complete',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _scoreColor(score),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (retakePhotos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  color: AppColors.critical.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.camera_alt_outlined, color: AppColors.critical),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${retakePhotos.length} photo${retakePhotos.length == 1 ? '' : 's'} need retake',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap Retake to open the camera for that shot. Results update automatically.',
                          style: TextStyle(color: AppColors.textSecondary, height: 1.35),
                        ),
                        const SizedBox(height: 12),
                        ...retakePhotos.map((photo) {
                          final reason = retakeReason(photo);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  categoryLabel(photo.category),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (reason != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    reason,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton(
                                    onPressed: () async {
                                      await openPhotoRetake(
                                        context,
                                        inspectionId: inspectionId,
                                        category: photo.category,
                                      );
                                      ref.invalidate(inspectionDetailProvider(inspectionId));
                                      ref.invalidate(inspectionsProvider);
                                    },
                                    child: const Text('Retake'),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
              if (detail.photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'AI analysis details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ...detail.photos.map((photo) {
                  final data = photo.analysisJson != null
                      ? jsonDecode(photo.analysisJson!) as Map<String, dynamic>
                      : <String, dynamic>{};
                  final needsRetake = photoNeedsRetake(photo);
                  final card = buildAnalysisCardFromJson(photo.category, data);

                  if (card != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        card,
                        if (needsRetake)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: () async {
                                  await openPhotoRetake(
                                    context,
                                    inspectionId: inspectionId,
                                    category: photo.category,
                                  );
                                  ref.invalidate(inspectionDetailProvider(inspectionId));
                                  ref.invalidate(inspectionsProvider);
                                },
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Retake photo'),
                              ),
                            ),
                          ),
                      ],
                    );
                  }

                  final lines = summarizePhotoAnalysis(photo);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  categoryLabel(photo.category),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          if (needsRetake) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await openPhotoRetake(
                                    context,
                                    inspectionId: inspectionId,
                                    category: photo.category,
                                  );
                                  ref.invalidate(inspectionDetailProvider(inspectionId));
                                  ref.invalidate(inspectionsProvider);
                                },
                                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                label: const Text('Retake'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          ...lines.map(
                            (line) => Text(
                              line,
                              style: const TextStyle(color: AppColors.textSecondary, height: 1.35, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 16),
              _FindingSection(title: 'Good', color: AppColors.success, findings: good),
              _FindingSection(title: 'Attention Required', color: AppColors.warning, findings: attention),
              _FindingSection(title: 'Critical', color: AppColors.critical, findings: critical),
              if (detail.report != null) ...[
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Dealer Discussion Report',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          detail.report!.dealerNotes ?? 'No dealer notes generated.',
                          style: const TextStyle(height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Text('Export PDF (coming soon)'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Need Human Expert?',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹499 • Review within a few hours',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Request Expert Review'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => confirmRestartInspection(context, ref, inspectionId: inspectionId),
                icon: const Icon(Icons.restart_alt_outlined),
                label: const Text('Restart inspection'),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Error: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.35),
            ),
          ),
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 90) return AppColors.success;
    if (score >= 70) return AppColors.warning;
    return AppColors.critical;
  }
}

class _FindingSection extends StatelessWidget {
  const _FindingSection({
    required this.title,
    required this.color,
    required this.findings,
    this.icon,
  });

  final String title;
  final Color color;
  final List<Finding> findings;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty && title != 'Critical') {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            if (findings.isEmpty)
              Text('None', style: TextStyle(color: AppColors.textSecondary))
            else
              ...findings.map((finding) => _FindingTile(finding: finding, color: color, icon: icon)),
          ],
        ),
      ),
    );
  }
}

class _FindingTile extends StatelessWidget {
  const _FindingTile({
    required this.finding,
    required this.color,
    this.icon,
  });

  final Finding finding;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(icon ?? Icons.circle, size: icon != null ? 18 : 8, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  finding.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  finding.description,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
                ),
                if (finding.confidence != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'AI confidence: ${finding.confidence}%',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
