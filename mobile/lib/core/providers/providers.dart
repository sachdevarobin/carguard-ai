import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/inspection_repository.dart';
import '../models/models.dart';

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  final repo = InspectionRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final vehiclesProvider = FutureProvider((ref) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return repo.fetchVehicles();
});

final inspectionsProvider = FutureProvider((ref) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return repo.fetchInspections();
});

final inspectionDetailProvider =
    FutureProvider.family<InspectionDetail, int>((ref, id) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return repo.fetchInspection(id);
});

final inspectionStepsProvider = FutureProvider.family<List<InspectionStep>, int>((ref, id) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  final inspection = await repo.fetchInspection(id);
  return repo.fetchInspectionSteps(
    make: inspection.make,
    model: inspection.model,
    variant: inspection.variant,
  );
});

final analysisProgressProvider =
    FutureProvider.family<List<AnalysisProgressStep>, int>((ref, id) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return repo.fetchAnalysisProgress(id);
});
