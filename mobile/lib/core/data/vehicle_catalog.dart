import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

class VehicleCatalog {
  VehicleCatalog._();
  static final VehicleCatalog instance = VehicleCatalog._();

  List<VehicleMake>? _cache;

  Future<List<VehicleMake>> loadMakes() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/data/vehicles.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final makes = (json['makes'] as List<dynamic>)
        .map((item) => VehicleMake.fromJson(item as Map<String, dynamic>))
        .toList();
    _cache = makes;
    return makes;
  }

  List<String> featuresFor(String make, String model, String variant) {
    if (_cache == null) return [];
    for (final m in _cache!) {
      if (m.name.toLowerCase() != make.toLowerCase()) continue;
      for (final mod in m.models) {
        if (mod.name.toLowerCase() != model.toLowerCase()) continue;
        for (final v in mod.variants) {
          if (v.name.toLowerCase() == variant.toLowerCase()) {
            return v.features;
          }
        }
      }
    }
    return [];
  }

  List<InspectionStep> journeySteps(String make, String model, String variant) {
    final features = featuresFor(make, model, variant);
    final steps = _baseSteps.map((s) => InspectionStep(
          id: s.id,
          title: s.title,
          description: s.description,
          photoCategory: s.photoCategory,
          photoCategories: List.from(s.photoCategories),
          checklist: List.from(s.checklist),
        )).toList();

    if (features.isNotEmpty) {
      final accessories = steps.firstWhere((s) => s.id == 'accessories');
      accessories.checklist.insertAll(0, features);
      final dashboard = steps.firstWhere((s) => s.id == 'dashboard');
      dashboard.checklist.add('Confirm features: ${features.take(3).join(', ')}');
    }
    return steps;
  }

  static final List<InspectionStep> _baseSteps = [
    const InspectionStep(
      id: 'exterior',
      title: 'Exterior',
      description: 'Capture all four sides of the vehicle.',
      photoCategories: ['front', 'rear', 'left', 'right'],
      checklist: ['Check panel gaps', 'Look for paint mismatch', 'Inspect glass and mirrors'],
    ),
    const InspectionStep(
      id: 'dashboard',
      title: 'Dashboard',
      description: 'Photograph the instrument cluster and infotainment screen.',
      photoCategory: 'dashboard',
      checklist: ['Verify warning lights are off', 'Check screen responsiveness'],
    ),
    const InspectionStep(
      id: 'odometer',
      title: 'Odometer',
      description: 'Capture a clear photo of the odometer reading.',
      photoCategory: 'odometer',
      checklist: ['Reading should typically be under 50 km'],
    ),
    const InspectionStep(
      id: 'tyres',
      title: 'Tyres',
      description: 'Photograph the tyre sidewall DOT code.',
      photoCategory: 'tyre',
      checklist: ['Check manufacturing week/year', 'Verify all four tyres match'],
    ),
    const InspectionStep(
      id: 'vin',
      title: 'VIN Verification',
      description: 'Capture the VIN sticker on the door jamb or windshield.',
      photoCategory: 'vin',
      checklist: ['Match VIN with invoice'],
    ),
    const InspectionStep(
      id: 'documents',
      title: 'Documents',
      description: 'Verify RC, insurance, and delivery paperwork.',
      checklist: ['Invoice VIN match', 'Insurance policy present'],
    ),
    const InspectionStep(
      id: 'accessories',
      title: 'Accessories',
      description: 'Confirm all variant-specific accessories are present.',
      checklist: ['Floor mats', 'Tool kit', 'Spare wheel'],
    ),
  ];
}
