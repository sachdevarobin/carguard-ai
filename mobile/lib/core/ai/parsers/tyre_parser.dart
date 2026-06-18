class TyreParseResult {
  const TyreParseResult({
    this.manufacturingWeek,
    this.manufacturingYear,
    this.ageMonths,
    this.confidence = 0,
    this.brand,
    this.size,
    this.dotRaw,
    this.manufacturedLabel,
    this.ageVerdict,
    this.dotLabelFound = false,
    this.rejectionReason,
  });

  final int? manufacturingWeek;
  final int? manufacturingYear;
  final int? ageMonths;
  final int confidence;
  final String? brand;
  final String? size;
  final String? dotRaw;
  final String? manufacturedLabel;
  final String? ageVerdict;
  final bool dotLabelFound;
  final String? rejectionReason;

  bool get isValid => manufacturingWeek != null && dotLabelFound;
}

const _tyreBrands = [
  'MICHELIN', 'BRIDGESTONE', 'GOODYEAR', 'MRF', 'CEAT', 'APOLLO', 'JK TYRE',
  'YOKOHAMA', 'CONTINENTAL', 'PIRELLI', 'DUNLOP', 'FIRESTONE', 'HANKOOK',
];

final _sizePattern = RegExp(r'\b(\d{3})\s*/\s*(\d{2})\s*R\s*(\d{2})\b', caseSensitive: false);
final _dotWithLabel = RegExp(r'DOT[\sA-Z0-9]*?(\d{2})(\d{2})\b', caseSensitive: false);
final _dotTail = RegExp(r'(?:DOT\s*)?[A-Z0-9]{4,12}(\d{2})(\d{2})\b', caseSensitive: false);

String? _detectBrand(String text) {
  final upper = text.toUpperCase();
  for (final brand in _tyreBrands) {
    if (upper.contains(brand)) return brand[0] + brand.substring(1).toLowerCase();
  }
  return null;
}

String? _detectSize(String text) {
  final match = _sizePattern.firstMatch(text);
  if (match == null) return null;
  return '${match.group(1)}/${match.group(2)}R${match.group(3)}';
}

int _fullYear(int yy) => yy <= 89 ? 2000 + yy : 1900 + yy;

String _ageVerdict(int ageMonths) {
  if (ageMonths <= 6) return 'Fresh — within 6-month PDI norm';
  if (ageMonths <= 12) return 'Acceptable — verify with dealer';
  if (ageMonths <= 24) return 'Aged — ask dealer to replace or discount';
  return 'Too old for a new car delivery — escalate with dealer';
}

TyreParseResult parseTyreDot(String text, {double ocrConfidence = 0}) {
  final upper = text.toUpperCase();
  final dotLabelFound = upper.contains('DOT');

  if (text.trim().length < 6) {
    return const TyreParseResult(
      rejectionReason: 'Too little text — photograph the tyre sidewall DOT code.',
    );
  }

  if (!dotLabelFound) {
    return TyreParseResult(
      brand: _detectBrand(text),
      size: _detectSize(text),
      dotLabelFound: false,
      rejectionReason: 'No "DOT" marking found. Random car photos cannot pass — shoot the sidewall DOT.',
    );
  }

  RegExpMatch? match = _dotWithLabel.firstMatch(upper);
  match ??= _dotTail.firstMatch(upper);

  if (match == null) {
    return TyreParseResult(
      brand: _detectBrand(text),
      size: _detectSize(text),
      dotLabelFound: true,
      rejectionReason: 'DOT label seen but week/year code not readable. Fill frame with the DOT block.',
    );
  }

  final week = int.parse(match.group(1)!);
  final yy = int.parse(match.group(2)!);
  if (week < 1 || week > 53) {
    return TyreParseResult(
      dotLabelFound: true,
      rejectionReason: 'Invalid manufacturing week ($week). Retake the DOT code clearly.',
    );
  }

  final fullYear = _fullYear(yy);
  final now = DateTime.now();
  if (fullYear > now.year + 1) {
    return TyreParseResult(
      dotLabelFound: true,
      rejectionReason: 'Manufacturing year $fullYear is in the future — likely OCR error.',
    );
  }

  final month = (week ~/ 4 + 1).clamp(1, 12);
  final manufactured = DateTime(fullYear, month, 15);
  final ageMonths = ((now.year - manufactured.year) * 12 + (now.month - manufactured.month))
      .clamp(0, 999);

  final brand = _detectBrand(text);
  final size = _detectSize(text);
  var confidence = (ocrConfidence * 0.4 + 55).round();
  if (brand != null) confidence += 8;
  if (size != null) confidence += 8;
  confidence = confidence.clamp(50, 94);

  return TyreParseResult(
    manufacturingWeek: week,
    manufacturingYear: fullYear,
    ageMonths: ageMonths,
    confidence: confidence,
    brand: brand,
    size: size,
    dotRaw: 'DOT …${match.group(1)}${match.group(2)}',
    manufacturedLabel: 'Week $week, $fullYear (${_monthName(month)} $fullYear approx.)',
    ageVerdict: _ageVerdict(ageMonths),
    dotLabelFound: true,
  );
}

String _monthName(int month) => const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ][month - 1];

Map<String, dynamic> tyreDetailsToJson(TyreParseResult r) => {
      if (r.manufacturingWeek != null) 'manufacturing_week': r.manufacturingWeek,
      if (r.manufacturingYear != null) 'manufacturing_year': r.manufacturingYear,
      if (r.ageMonths != null) 'age_months': r.ageMonths,
      if (r.brand != null) 'tyre_brand': r.brand,
      if (r.size != null) 'tyre_size': r.size,
      if (r.dotRaw != null) 'dot_code': r.dotRaw,
      if (r.manufacturedLabel != null) 'manufactured_label': r.manufacturedLabel,
      if (r.ageVerdict != null) 'age_verdict': r.ageVerdict,
      'dot_label_found': r.dotLabelFound,
    };
