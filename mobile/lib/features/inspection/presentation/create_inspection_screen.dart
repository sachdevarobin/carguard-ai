import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/providers.dart';

class CreateInspectionScreen extends ConsumerStatefulWidget {
  const CreateInspectionScreen({super.key});

  @override
  ConsumerState<CreateInspectionScreen> createState() => _CreateInspectionScreenState();
}

class _CreateInspectionScreenState extends ConsumerState<CreateInspectionScreen> {
  final _dealerController = TextEditingController();
  VehicleMake? _selectedMake;
  VehicleModel? _selectedModel;
  VehicleVariant? _selectedVariant;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _dealerController.dispose();
    super.dispose();
  }

  Future<void> _startInspection() async {
    if (_selectedMake == null || _selectedModel == null || _selectedVariant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select make, model, and variant')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(inspectionRepositoryProvider);
      final inspection = await repo.createInspection(
        make: _selectedMake!.name,
        model: _selectedModel!.name,
        variant: _selectedVariant!.name,
        dealerName: _dealerController.text.trim().isEmpty ? null : _dealerController.text.trim(),
      );
      ref.invalidate(inspectionsProvider);
      if (mounted) context.go('/inspection/${inspection.id}/progress');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create inspection: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Inspection')),
      body: vehicles.when(
        data: (makes) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _StepHeader(step: 1, title: 'Vehicle', subtitle: 'Select your delivery vehicle'),
            const SizedBox(height: 12),
            _SelectionCard(
              title: 'Make',
              value: _selectedMake?.name,
              children: makes
                  .map(
                    (make) => ActionChip(
                      label: Text(make.name),
                      onPressed: () => setState(() {
                        _selectedMake = make;
                        _selectedModel = null;
                        _selectedVariant = null;
                      }),
                    ),
                  )
                  .toList(),
            ),
            if (_selectedMake != null) ...[
              const SizedBox(height: 12),
              _SelectionCard(
                title: 'Model',
                value: _selectedModel?.name,
                children: _selectedMake!.models
                    .map(
                      (model) => ActionChip(
                        label: Text(model.name),
                        onPressed: () => setState(() {
                          _selectedModel = model;
                          _selectedVariant = null;
                        }),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_selectedModel != null) ...[
              const SizedBox(height: 12),
              _SelectionCard(
                title: 'Variant',
                value: _selectedVariant?.name,
                children: _selectedModel!.variants
                    .map(
                      (variant) => ActionChip(
                        label: Text(variant.name),
                        onPressed: () => setState(() => _selectedVariant = variant),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_selectedVariant != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Variant checklist preview', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ..._selectedVariant!.features.map(
                        (feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(child: Text(feature)),
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
            TextField(
              controller: _dealerController,
              decoration: const InputDecoration(labelText: 'Dealer name (optional)'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _startInspection,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Start Inspection Journey'),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load vehicles: $error')),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.title, required this.subtitle});

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text('$step', style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ],
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.title,
    required this.value,
    required this.children,
  });

  final String title;
  final String? value;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (value != null) ...[
              const SizedBox(height: 4),
              Text(value!, style: const TextStyle(color: AppColors.primary)),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: children),
          ],
        ),
      ),
    );
  }
}
