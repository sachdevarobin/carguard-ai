import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key, required this.inspectionId});

  final int inspectionId;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  bool _started = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _started = true;
      _error = null;
    });
    try {
      final repo = ref.read(inspectionRepositoryProvider);
      await repo.analyzeInspection(widget.inspectionId);
      ref.invalidate(inspectionDetailProvider(widget.inspectionId));
      ref.invalidate(inspectionsProvider);
      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        context.go('/inspection/${widget.inspectionId}/results');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(analysisProgressProvider(widget.inspectionId));

    return Scaffold(
      appBar: AppBar(title: const Text('AI Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Analyzing Vehicle...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI Analysis Complete will appear when processing finishes.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            progress.when(
              data: (steps) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: steps
                    .map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Icon(
                              step.done ? Icons.check_circle : Icons.hourglass_top,
                              color: step.done ? AppColors.success : AppColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(step.label, style: const TextStyle(fontSize: 16))),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Progress unavailable: $e'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.critical)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _runAnalysis, child: const Text('Retry')),
            ] else if (_started) ...[
              const Spacer(),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}
