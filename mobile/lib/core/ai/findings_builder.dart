import '../models/models.dart';
import 'labels.dart';

const _exteriorCategories = {'front', 'rear', 'left', 'right'};

class BuiltReport {
  const BuiltReport({
    required this.findings,
    required this.score,
    required this.summary,
    required this.recommendations,
    required this.dealerNotes,
    required this.verdict,
  });

  final List<Finding> findings;
  final int score;
  final String summary;
  final String recommendations;
  final String dealerNotes;
  final String verdict;
}

List<Finding> buildFindings({
  required int inspectionId,
  required String variant,
  required int featureCount,
  required List<({String category, Map<String, dynamic> payload})> photoResults,
}) {
  final findings = <Finding>[];
  var nextId = 1;

  void add({
    required String type,
    required String severity,
    required String title,
    required String description,
    int? confidence,
  }) {
    findings.add(
      Finding(
        id: nextId++,
        type: type,
        severity: severity,
        title: title,
        description: description,
        confidence: confidence,
      ),
    );
  }

  add(
    type: 'variant_checklist',
    severity: 'good',
    title: 'Variant features loaded',
    description: 'Checklist prepared for $variant with $featureCount feature checks.',
    confidence: 100,
  );

  for (final photo in photoResults) {
    final payload = photo.payload;
    final category = photo.category;

    if (payload['needs_retake'] == true) {
      add(
        type: 'retake_photo',
        severity: 'attention',
        title: retakeTitle(category),
        description: retakeDescription(category, payload),
        confidence: payload['confidence'] as int?,
      );
      continue;
    }

    if (category == 'dashboard') {
      final warnings = (payload['warning_lights'] as List?)?.cast<String>() ?? [];
      if (warnings.isNotEmpty) {
        add(
          type: 'dashboard_warning',
          severity: 'attention',
          title: 'Possible dashboard warning',
          description:
              'AI detected: ${warnings.map(humanizeWarning).join(', ')}. Confirm no warning lamps are lit.',
          confidence: payload['confidence'] as int?,
        );
      } else {
        add(
          type: 'dashboard_warning',
          severity: 'good',
          title: 'No warning lights',
          description: 'Dashboard appears clear of warning indicators.',
          confidence: payload['confidence'] as int?,
        );
      }
    }

    if (category == 'odometer' && payload['odometer_km'] != null) {
      final km = payload['odometer_km'] as int;
      add(
        type: 'odometer',
        severity: km <= 50 ? 'good' : 'attention',
        title: 'Odometer reading: $km km',
        description: payload['message'] as String? ?? 'Verify against delivery paperwork.',
        confidence: payload['confidence'] as int?,
      );
    }

    if (category == 'vin' && payload['vin'] != null && payload['needs_retake'] != true) {
      final parts = <String>[
        'VIN ${payload['vin']}',
        if (payload['manufacturer'] != null) 'Maker: ${payload['manufacturer']}',
        if (payload['country'] != null) 'Country: ${payload['country']}',
        if (payload['model_year'] != null) 'Year: ${payload['model_year']}',
        if (payload['vehicle_category'] != null) 'Type: ${payload['vehicle_category']}',
        'Confirm against invoice & RC.',
      ];
      add(
        type: 'vin',
        severity: 'good',
        title: 'VIN verified',
        description: parts.join(' • '),
        confidence: payload['confidence'] as int?,
      );
    }

    if (category == 'tyre' && payload['manufacturing_week'] != null && payload['needs_retake'] != true) {
      final age = payload['age_months'] as int? ?? 0;
      final parts = <String>[
        if (payload['tyre_brand'] != null) 'Brand: ${payload['tyre_brand']}',
        if (payload['tyre_size'] != null) 'Size: ${payload['tyre_size']}',
        if (payload['manufactured_label'] != null) 'Made ${payload['manufactured_label']}',
        payload['age_verdict'] as String? ?? 'Age: $age months',
      ];
      add(
        type: 'tyre_age',
        severity: age <= 6 ? 'good' : 'attention',
        title: 'Tyre ${payload['tyre_brand'] ?? 'sidewall'}: $age months old',
        description: parts.join(' • '),
        confidence: payload['confidence'] as int?,
      );
    }

    if (_exteriorCategories.contains(category)) {
      if (payload['damage_detected'] == true) {
        add(
          type: 'exterior_damage',
          severity: 'attention',
          title: 'Possible damage on $category',
          description: payload['message'] as String? ?? 'Inspect closely before accepting.',
          confidence: payload['confidence'] as int?,
        );
      } else if (payload['automated_check'] == false) {
        add(
          type: 'exterior_photo',
          severity: 'attention',
          title: '${category[0].toUpperCase()}${category.substring(1)} — manual check',
          description: payload['message'] as String? ?? 'Verify panel condition in person.',
          confidence: payload['confidence'] as int?,
        );
      } else {
        add(
          type: 'exterior_damage',
          severity: 'good',
          title: '${category[0].toUpperCase()}${category.substring(1)} panel clear',
          description: payload['message'] as String? ?? 'No obvious damage detected.',
          confidence: payload['confidence'] as int?,
        );
      }
    }
  }

  if (!findings.any((f) => f.type == 'dashboard_warning')) {
    add(
      type: 'dashboard_warning',
      severity: 'attention',
      title: 'Dashboard photo missing',
      description: 'Upload a dashboard photo for warning light analysis.',
    );
  }

  return findings;
}

int calculateScore(List<Finding> findings) {
  var score = 100;
  for (final finding in findings) {
    if (finding.severity == 'critical') score -= 25;
    if (finding.severity == 'attention') score -= 8;
  }
  return score.clamp(0, 100);
}

BuiltReport buildReport({
  required String make,
  required String model,
  required String variant,
  required List<Finding> findings,
}) {
  final score = calculateScore(findings);
  final attention = findings
      .where((f) => f.severity == 'attention' && f.type != 'retake_photo')
      .map((f) => f.title)
      .toList();
  final critical = findings.where((f) => f.severity == 'critical').map((f) => f.title).toList();
  final retakes = findings.where((f) => f.type == 'retake_photo').toList();

  final summary =
      '$make $model $variant scored $score/100. ${attention.length} items need clarification.';

  var recommendations =
      'Ask the dealer to resolve all attention items before signing delivery acceptance.';
  if (retakes.isNotEmpty) {
    recommendations += ' Retake photos where noted below.';
  }

  final dealerLines = <String>[];
  for (final item in attention) {
    dealerLines.add('- Clarify: $item');
  }
  for (final item in critical) {
    dealerLines.add('- Critical: $item');
  }
  if (retakes.isNotEmpty) {
    dealerLines.add('');
    dealerLines.add('Photos to retake:');
    for (final item in retakes) {
      dealerLines.add('- ${item.title}: ${item.description}');
    }
  }
  if (dealerLines.isEmpty) {
    dealerLines.add('- No major dealer discussion points identified.');
  }

  final verdict = critical.isNotEmpty
      ? 'Do not accept until resolved'
      : (attention.isNotEmpty || retakes.isNotEmpty)
          ? 'Accept with clarifications'
          : 'Accept';

  return BuiltReport(
    findings: findings,
    score: score,
    summary: summary,
    recommendations: recommendations,
    dealerNotes: 'Items to clarify before delivery:\n${dealerLines.join('\n')}',
    verdict: verdict,
  );
}
