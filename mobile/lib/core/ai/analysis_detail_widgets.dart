import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../widgets/layout_helpers.dart';

/// Rich key-value rows for analysis dialogs and results.
class AnalysisDetailCard extends StatelessWidget {
  const AnalysisDetailCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.rows,
    this.icon,
    this.accentColor,
    this.needsRetake = false,
  });

  final String title;
  final String subtitle;
  final List<({String label, String value})> rows;
  final IconData? icon;
  final Color? accentColor;
  final bool needsRetake;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? (needsRetake ? AppColors.warning : AppColors.primary);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon ?? Icons.analytics_outlined, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => DetailField(label: row.label, value: row.value),
            ),
          ],
        ),
      ),
    );
  }
}

AnalysisDetailCard? buildAnalysisCardFromJson(String category, Map<String, dynamic> data) {
  final needsRetake = data['needs_retake'] == true;

  if (category == 'vin' && data['vin'] != null) {
    final source = _vinSourceLabel(data['decode_source'] as String?);
    final rows = <({String label, String value})>[
      (label: 'VIN', value: '${data['vin']}'),
      (label: 'Check digit', value: data['check_digit_valid'] == true ? 'Valid ✓' : 'Invalid'),
      (label: 'Make', value: '${data['make'] ?? '—'}'),
      (label: 'Model', value: '${data['model'] ?? '—'}'),
      (label: 'Model year', value: '${data['model_year'] ?? '—'}'),
      (label: 'Manufacturer', value: '${data['manufacturer'] ?? '—'}'),
      (label: 'Body / type', value: '${data['body_class'] ?? data['vehicle_type'] ?? '—'}'),
      (label: 'Fuel', value: '${data['fuel_type'] ?? '—'}'),
      (label: 'Engine', value: '${data['engine'] ?? '—'}'),
      (label: 'Drive', value: '${data['drive_type'] ?? '—'}'),
      (label: 'Built in', value: '${data['plant_country'] ?? data['country'] ?? '—'}'),
      (label: 'Plant', value: '${data['plant_city'] ?? data['plant_code'] ?? '—'}'),
      (label: 'Region', value: '${data['region'] ?? '—'}'),
      (label: 'WMI', value: '${data['wmi'] ?? '—'}'),
      (label: 'Data source', value: source),
      if (data['ocr_passes_matched'] != null)
        (label: 'OCR passes', value: '${data['ocr_passes_matched']} agreed'),
      if (data['anchored_to_vin_label'] == true)
        (label: 'VIN label', value: 'Visible in photo'),
      (label: 'Confidence', value: '${data['confidence'] ?? '—'}%'),
    ];
    return AnalysisDetailCard(
      title: 'VIN decoded',
      subtitle: data['message'] as String? ?? 'Vehicle identification number',
      rows: rows,
      icon: Icons.qr_code_2_outlined,
      needsRetake: needsRetake,
    );
  }

  if (category == 'tyre' && data['manufacturing_week'] != null) {
    final rows = <({String label, String value})>[
      if (data['tyre_brand'] != null) (label: 'Brand', value: '${data['tyre_brand']}'),
      if (data['tyre_size'] != null) (label: 'Size', value: '${data['tyre_size']}'),
      if (data['dot_code'] != null) (label: 'DOT code', value: '${data['dot_code']}'),
      if (data['manufactured_label'] != null) (label: 'Made', value: '${data['manufactured_label']}'),
      if (data['age_months'] != null) (label: 'Age', value: '${data['age_months']} months'),
      if (data['age_verdict'] != null) (label: 'PDI verdict', value: '${data['age_verdict']}'),
      (label: 'Confidence', value: '${data['confidence'] ?? '—'}%'),
    ];
    return AnalysisDetailCard(
      title: 'Tyre analysis',
      subtitle: data['message'] as String? ?? 'Sidewall DOT decode',
      rows: rows,
      icon: Icons.tire_repair_outlined,
      accentColor: (data['age_months'] as int? ?? 0) > 6 ? AppColors.warning : AppColors.success,
      needsRetake: needsRetake,
    );
  }

  if (category == 'odometer' && data['odometer_km'] != null) {
    final km = data['odometer_km'] as int;
    return AnalysisDetailCard(
      title: 'Odometer',
      subtitle: data['message'] as String? ?? 'Cluster reading',
      rows: [
        (label: 'Reading', value: '$km km'),
        if (data['pdi_verdict'] != null) (label: 'PDI verdict', value: '${data['pdi_verdict']}'),
        (label: 'Confidence', value: '${data['confidence'] ?? '—'}%'),
      ],
      icon: Icons.speed_outlined,
      accentColor: km > 50 ? AppColors.warning : AppColors.success,
      needsRetake: needsRetake,
    );
  }

  if (const {'front', 'rear', 'left', 'right'}.contains(category) && data['automated_check'] == true) {
    final damage = data['damage_detected'] == true;
    final types = (data['damage_types'] as List?)?.cast<String>() ?? const [];
    final count = data['damage_count'] as int? ?? 0;
    final rows = <({String label, String value})>[
      (label: 'AI scan', value: damage ? 'Damage flagged' : 'No damage flagged'),
      if (types.isNotEmpty) (label: 'Findings', value: types.join(', ')),
      if (count > 0) (label: 'Regions', value: '$count area(s)'),
      (label: 'Model', value: 'YOLO11n on-device'),
      (label: 'Confidence', value: '${data['confidence'] ?? '—'}%'),
      (label: 'Note', value: 'Always verify paint and panels in person.'),
    ];
    return AnalysisDetailCard(
      title: '${category[0].toUpperCase()}${category.substring(1)} exterior',
      subtitle: data['message'] as String? ?? 'Panel damage scan',
      rows: rows,
      icon: Icons.directions_car_outlined,
      accentColor: damage ? AppColors.warning : AppColors.success,
      needsRetake: needsRetake,
    );
  }

  return null;
}

List<({String label, String value})> detailRowsFromResult(Map<String, dynamic> data, String category) {
  final card = buildAnalysisCardFromJson(category, data);
  return card?.rows ?? [];
}

String _vinSourceLabel(String? source) => switch (source) {
      'nhtsa_live' => 'NHTSA vPIC (live)',
      'nhtsa_cached' => 'NHTSA vPIC (cached)',
      'offline_registry' => 'Offline WMI registry',
      'iso3779' => 'ISO 3779 structure',
      _ => 'Combined decode',
    };
