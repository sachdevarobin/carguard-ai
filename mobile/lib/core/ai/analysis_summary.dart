import 'dart:convert';

import '../models/models.dart';

/// Human-readable lines from stored per-photo analysis JSON.
List<String> summarizePhotoAnalysis(InspectionPhoto photo) {
  if (photo.analysisJson == null || photo.analysisJson!.isEmpty) {
    return ['No analysis stored for this photo.'];
  }

  final data = jsonDecode(photo.analysisJson!) as Map<String, dynamic>;
  final lines = <String>[];

  if (data['needs_retake'] == true) {
    lines.add(data['message'] as String? ?? 'Retake required — photo did not pass validation.');
    return lines;
  }

  final message = data['message'] as String?;
  if (message != null && message.isNotEmpty) lines.add(message);

  if (data['vin'] != null) {
    lines.add('VIN: ${data['vin']}');
    if (data['check_digit_valid'] == true) lines.add('Check digit: valid');
    if (data['manufacturer'] != null) lines.add('Manufacturer: ${data['manufacturer']}');
    if (data['country'] != null) lines.add('Country: ${data['country']}');
    if (data['model_year'] != null) lines.add('Model year: ${data['model_year']}');
    if (data['vehicle_category'] != null) lines.add('Type: ${data['vehicle_category']}');
    if (data['plant_code'] != null) lines.add('Plant code: ${data['plant_code']}');
  }

  if (data['odometer_km'] != null) {
    lines.add('Odometer: ${data['odometer_km']} km');
    if (data['pdi_verdict'] != null) lines.add('${data['pdi_verdict']}');
  }

  if (data['manufacturing_week'] != null) {
    if (data['tyre_brand'] != null) lines.add('Brand: ${data['tyre_brand']}');
    if (data['tyre_size'] != null) lines.add('Size: ${data['tyre_size']}');
    if (data['dot_code'] != null) lines.add('DOT: ${data['dot_code']}');
    if (data['manufactured_label'] != null) lines.add('Manufactured: ${data['manufactured_label']}');
    if (data['age_months'] != null) lines.add('Age: ${data['age_months']} months');
    if (data['age_verdict'] != null) lines.add('${data['age_verdict']}');
  }

  final warnings = (data['warning_lights'] as List?)?.cast<String>() ?? [];
  if (warnings.isNotEmpty) lines.add('Warning text: ${warnings.join(', ')}');

  final confidence = data['confidence'];
  if (confidence != null) lines.add('AI confidence: $confidence%');

  if (lines.isEmpty) lines.add('Photo saved — no structured data extracted.');
  return lines;
}

String categoryLabel(String category) => switch (category) {
      'front' => 'Front exterior',
      'rear' => 'Rear exterior',
      'left' => 'Left side',
      'right' => 'Right side',
      'vin' => 'VIN sticker',
      'odometer' => 'Odometer',
      'tyre' => 'Tyre sidewall',
      'dashboard' => 'Dashboard',
      _ => category,
    };
