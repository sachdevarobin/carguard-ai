class OdometerParseResult {
  const OdometerParseResult({
    this.odometerKm,
    this.confidence = 0,
    this.rejectionReason,
    this.pdiVerdict,
  });

  final int? odometerKm;
  final int confidence;
  final String? rejectionReason;
  final String? pdiVerdict;
}

final _kmPattern = RegExp(r'(\d{1,3}(?:[,\s]\d{3})*|\d{1,6})\s*(?:km|kms|kilometers?)?', caseSensitive: false);

bool _hasOdometerContext(String text) {
  final lower = text.toLowerCase();
  const keywords = [
    'km', 'odo', 'odometer', 'trip', 'mph', 'km/h', 'kmph', 'speed',
    'rpm', 'fuel', 'range', 'total', 'distance',
  ];
  if (keywords.any(lower.contains)) return true;
  return RegExp(r'\d{1,3}[,.]\d{3}').hasMatch(text);
}

OdometerParseResult parseOdometer(String text, {double ocrConfidence = 0, bool strict = false}) {
  if (text.trim().length < 2) {
    return const OdometerParseResult(
      rejectionReason: 'No digits visible — zoom in on the odometer display.',
    );
  }

  if (strict && !_hasOdometerContext(text)) {
    return const OdometerParseResult(
      rejectionReason:
          'This does not look like an odometer/cluster photo. Random images are rejected.',
    );
  }

  final candidates = <int>[];

  for (final match in _kmPattern.allMatches(text)) {
    final digits = match.group(1)!.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isNotEmpty) candidates.add(int.parse(digits));
  }

  if (candidates.isEmpty) {
    for (final match in RegExp(r'\b\d{1,6}\b').allMatches(text)) {
      final value = int.tryParse(match.group(0)!);
      if (value != null && value <= 500000) candidates.add(value);
    }
  }

  if (candidates.isEmpty) {
    return const OdometerParseResult(
      rejectionReason: 'Could not read odometer digits.',
    );
  }

  final plausible = candidates.where((v) => v <= 500).toList();
  if (strict && plausible.isEmpty) {
    return OdometerParseResult(
      odometerKm: candidates.reduce((a, b) => a < b ? a : b),
      rejectionReason:
          'Reading looks too high for a new-car PDI (>${candidates.reduce((a, b) => a < b ? a : b)} km). Retake the cluster photo.',
    );
  }

  final chosen = plausible.isEmpty
      ? candidates.reduce((a, b) => a < b ? a : b)
      : plausible.reduce((a, b) => a < b ? a : b);

  var confidence = (ocrConfidence * 0.5 + 50).round();
  if (strict && _hasOdometerContext(text)) confidence += 15;
  if (chosen <= 50) confidence += 10;
  if (chosen <= 10) confidence += 5;
  confidence = confidence.clamp(45, 94);

  final pdiVerdict = switch (chosen) {
    <= 10 => 'Excellent for new delivery',
    <= 50 => 'Normal for dealer-run / test drive',
    <= 150 => 'High for PDI — confirm with dealer',
    _ => 'Unusually high — verify paperwork',
  };

  return OdometerParseResult(
    odometerKm: chosen,
    confidence: confidence,
    pdiVerdict: pdiVerdict,
  );
}
