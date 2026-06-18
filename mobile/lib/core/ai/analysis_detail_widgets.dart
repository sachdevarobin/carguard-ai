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
    final rows = <({String label, String value})>[
      (label: 'VIN', value: '${data['vin']}'),
      (label: 'Check digit', value: data['check_digit_valid'] == true ? 'Valid ✓' : 'Invalid'),
      if (data['model_year'] != null) (label: 'Model year', value: '${data['model_year']}'),
      if (data['country'] != null) (label: 'Country', value: '${data['country']}'),
      if (data['region'] != null) (label: 'Region', value: '${data['region']}'),
      if (data['manufacturer'] != null) (label: 'Manufacturer', value: '${data['manufacturer']}'),
      if (data['vehicle_category'] != null) (label: 'Vehicle type', value: '${data['vehicle_category']}'),
      if (data['wmi'] != null) (label: 'WMI', value: '${data['wmi']}'),
      if (data['plant_code'] != null) (label: 'Plant code', value: '${data['plant_code']}'),
      if (data['ocr_passes_matched'] != null)
        (label: 'OCR passes', value: '${data['ocr_passes_matched']} agreed'),
      if (data['anchored_to_vin_label'] == true)
        (label: 'VIN label', value: 'Visible in photo'),
      if (data['ocr_snippet'] != null && '${data['ocr_snippet']}'.isNotEmpty)
        (label: 'Raw text', value: '${data['ocr_snippet']}'),
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

  return null;
}

List<({String label, String value})> detailRowsFromResult(Map<String, dynamic> data, String category) {
  final card = buildAnalysisCardFromJson(category, data);
  return card?.rows ?? [];
}
