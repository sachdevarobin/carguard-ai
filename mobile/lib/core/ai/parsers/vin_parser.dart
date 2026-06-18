import 'vin_decoder.dart';
import '../vin/vin_ocr_types.dart';

class VinParseResult {
  const VinParseResult({
    this.vin,
    this.manufacturingYear,
    this.confidence = 0,
    this.checkDigitValid = false,
    this.anchored = false,
    this.details,
    this.rejectionReason,
    this.consensusPasses = 0,
    this.ocrSnippet,
    this.alternateCandidates = const [],
  });

  final String? vin;
  final int? manufacturingYear;
  final int confidence;
  final bool checkDigitValid;
  final bool anchored;
  final VinDetails? details;
  final String? rejectionReason;
  final int consensusPasses;
  final String? ocrSnippet;
  final List<String> alternateCandidates;

  bool get isValid =>
      vin != null && checkDigitValid && manufacturingYear != null && rejectionReason == null;
}

// ISO 3779 — letters I, O, Q never appear in VIN
const _vinAlphabet = 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789';

final _vinStrict = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
final _vinAnchorPattern = RegExp(r'VIN\s*[:#]?\s*([A-HJ-NPR-Z0-9]{17})', caseSensitive: false);

/// Common OCR misreads — only map characters that are *never* valid in a VIN (I, O, Q).
const _ocrSubstitutions = {
  'O': '0',
  'o': '0',
  'Q': '0',
  'q': '0',
  'I': '1',
  'i': '1',
  '|': '1',
  'U': 'V', // U is not in the VIN alphabet
  'u': 'V',
};

String _normalize(String text) => text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

String _applyOcrFixes(String raw) {
  final buffer = StringBuffer();
  for (final ch in raw.split('')) {
    buffer.write(_ocrSubstitutions[ch] ?? ch);
  }
  return _normalize(buffer.toString());
}

bool _isValidVinChar(String c) => _vinAlphabet.contains(c);

bool _plausibleWmi(String vin) {
  if (vin.length < 3) return false;
  final first = vin[0];
  // Valid ISO 3779 geographic markers
  const validFirst = '123456789ABCDEFGHJKLMNPRSTUVWXYZ';
  return validFirst.contains(first) && _isValidVinChar(vin[1]) && _isValidVinChar(vin[2]);
}

bool _plausibleNewCarYear(int? year) {
  if (year == null) return false;
  final now = DateTime.now().year;
  return year >= now - 3 && year <= now + 1;
}

class _ScoredCandidate {
  _ScoredCandidate({
    required this.vin,
    required this.anchored,
    required this.score,
    required this.source,
  });

  final String vin;
  final bool anchored;
  final double score;
  final String source;
}

int _baseScore(String vin, {required bool anchored}) {
  var score = 0;
  if (anchored) score += 30;
  if (isValidVinCheckDigit(vin)) score += 45;
  final details = decodeVin(vin);
  if (details.modelYear != null) score += 12;
  if (_plausibleNewCarYear(details.modelYear)) score += 15;
  if (details.manufacturer != null) score += 12;
  if (_plausibleWmi(vin)) score += 10;
  return score;
}

List<_ScoredCandidate> _candidatesFromText(String raw, String normalized, String source, double weight) {
  final found = <_ScoredCandidate>[];

  void add(String vin, bool anchored) {
    final v = vin.toUpperCase();
    if (!_vinStrict.hasMatch(v)) return;
    found.add(
      _ScoredCandidate(
        vin: v,
        anchored: anchored,
        score: _baseScore(v, anchored: anchored) * weight,
        source: source,
      ),
    );
  }

  for (final m in _vinAnchorPattern.allMatches(raw)) {
    add(_applyOcrFixes(m.group(1)!), true);
  }

  if (normalized.startsWith('VIN') && normalized.length >= 20) {
    add(_applyOcrFixes(normalized.substring(3, 20)), true);
  }

  // Line-by-line: VIN stickers usually print the code on its own row
  for (final line in raw.split('\n')) {
    final fixed = _applyOcrFixes(line);
    if (fixed.length == 17) add(fixed, line.toUpperCase().contains('VIN'));
    for (final m in RegExp(r'[A-HJ-NPR-Z0-9]{17}').allMatches(fixed)) {
      add(m.group(0)!, line.toUpperCase().contains('VIN'));
    }
  }

  // Sliding window with OCR fixes on normalized blob
  final blob = _applyOcrFixes(normalized);
  for (var i = 0; i <= blob.length - 17; i++) {
    final slice = blob.substring(i, i + 17);
    if (_vinStrict.hasMatch(slice) && isValidVinCheckDigit(slice)) {
      add(slice, normalized.startsWith('VIN') && i <= 3);
    }
  }

  // Fuzzy: try fixing each 17-char window from raw alphanumeric runs
  for (final run in RegExp(r'[A-Za-z0-9|\-]{15,25}').allMatches(raw)) {
    final fixed = _applyOcrFixes(run.group(0)!);
    if (fixed.length >= 17) {
      for (var i = 0; i <= fixed.length - 17; i++) {
        final slice = fixed.substring(i, i + 17);
        if (_vinStrict.hasMatch(slice)) add(slice, false);
      }
    }
  }

  return found;
}

/// Parse from multiple OCR passes with weighted consensus.
VinParseResult parseVinFromOcrPasses(List<VinOcrPassResult> passes) {
  final aggregated = <String, ({double score, bool anchored, int passCount, String source})>{};

  for (final pass in passes) {
    final texts = <String>[pass.fullText, ...pass.lineTexts];
    for (final text in texts) {
      if (text.trim().isEmpty) continue;
      final normalized = _normalize(text);
      for (final c in _candidatesFromText(text, normalized, pass.source, pass.weight)) {
        final prev = aggregated[c.vin];
        aggregated[c.vin] = (
          score: (prev?.score ?? 0) + c.score,
          anchored: (prev?.anchored ?? false) || c.anchored,
          passCount: (prev?.passCount ?? 0) + 1,
          source: prev == null ? pass.source : '${prev.source}+${pass.source}',
        );
      }
    }
  }

  if (aggregated.isEmpty) {
    final snippets = passes
        .map((p) => p.fullText.trim())
        .where((t) => t.isNotEmpty)
        .take(2)
        .join(' | ');
    return VinParseResult(
      rejectionReason: 'No valid VIN pattern found. Centre the 17-character code inside the frame.',
      ocrSnippet: snippets.isEmpty ? null : snippets,
    );
  }

  final ranked = aggregated.entries.toList()
    ..sort((a, b) => b.value.score.compareTo(a.value.score));

  final best = ranked.first;
  final vin = best.key;
  final meta = best.value;
  final details = decodeVin(vin);
  final checkValid = details.checkDigitValid;
  final year = details.modelYear;

  final alternates = ranked.skip(1).take(2).map((e) => e.key).toList();

  final ocrSnippet = passes
      .map((p) => p.lineTexts.where((l) => l.length >= 10).join(' '))
      .where((s) => s.isNotEmpty)
      .take(1)
      .join();

  if (!checkValid) {
    return VinParseResult(
      vin: vin,
      manufacturingYear: year,
      checkDigitValid: false,
      anchored: meta.anchored,
      details: details,
      consensusPasses: meta.passCount,
      ocrSnippet: ocrSnippet,
      alternateCandidates: alternates,
      rejectionReason:
          'Read "$vin" but check-digit failed — likely OCR error. Hold steady and fill the frame.',
    );
  }

  if (year == null) {
    return VinParseResult(
      vin: vin,
      checkDigitValid: true,
      anchored: meta.anchored,
      details: details,
      consensusPasses: meta.passCount,
      rejectionReason: 'Could not decode model year from position 10.',
      ocrSnippet: ocrSnippet,
    );
  }

  if (!_plausibleWmi(vin)) {
    return VinParseResult(
      vin: vin,
      manufacturingYear: year,
      checkDigitValid: true,
      details: details,
      consensusPasses: meta.passCount,
      ocrSnippet: ocrSnippet,
      rejectionReason: 'WMI "${vin.substring(0, 3)}" does not look like a real vehicle identifier.',
    );
  }

  // Require consensus OR strong anchor for customer-facing confidence
  final strongEnough = meta.passCount >= 2 || meta.anchored || meta.score >= 95;
  if (!strongEnough) {
    return VinParseResult(
      vin: vin,
      manufacturingYear: year,
      confidence: meta.score.round().clamp(0, 55),
      checkDigitValid: true,
      anchored: meta.anchored,
      details: details,
      consensusPasses: meta.passCount,
      ocrSnippet: ocrSnippet,
      alternateCandidates: alternates,
      rejectionReason:
          'Low confidence — only one OCR pass matched. Retake with the VIN label visible and in focus.',
    );
  }

  if (!meta.anchored && !_plausibleNewCarYear(year)) {
    return VinParseResult(
      vin: vin,
      manufacturingYear: year,
      confidence: 50,
      checkDigitValid: true,
      anchored: false,
      details: details,
      consensusPasses: meta.passCount,
      ocrSnippet: ocrSnippet,
      rejectionReason:
          'Model year $year seems unusual for a new delivery. Include the "VIN" label and retake.',
    );
  }

  if (alternates.isNotEmpty && ranked.length > 1 && ranked[1].value.score > meta.score * 0.85) {
    return VinParseResult(
      vin: vin,
      manufacturingYear: year,
      confidence: 55,
      checkDigitValid: true,
      anchored: meta.anchored,
      details: details,
      consensusPasses: meta.passCount,
      ocrSnippet: ocrSnippet,
      alternateCandidates: alternates,
      rejectionReason:
          'OCR found conflicting VIN reads. Retake closer — avoid glare and keep only the sticker in frame.',
    );
  }

  var confidence = meta.score.round().clamp(60, 97);
  if (meta.passCount >= 3) confidence = (confidence + 5).clamp(0, 97);
  if (meta.anchored) confidence = (confidence + 4).clamp(0, 97);
  if (details.manufacturer != null) confidence = (confidence + 3).clamp(0, 97);

  return VinParseResult(
    vin: vin,
    manufacturingYear: year,
    confidence: confidence,
    checkDigitValid: true,
    anchored: meta.anchored,
    details: details,
    consensusPasses: meta.passCount,
    ocrSnippet: ocrSnippet,
    alternateCandidates: alternates,
  );
}

/// Single-text fallback (tests / simple callers).
VinParseResult parseVin(String text, {double ocrConfidence = 0}) {
  if (text.trim().length < 8) {
    return const VinParseResult(rejectionReason: 'Too little text — photograph the VIN sticker closely.');
  }
  return parseVinFromOcrPasses([
    VinOcrPassResult(
      source: 'single',
      fullText: text,
      lineTexts: text.split('\n'),
      weight: 1.0 + (ocrConfidence / 200),
    ),
  ]);
}

Map<String, dynamic> vinDetailsToJson(VinDetails d) => {
      'vin': d.vin,
      'check_digit_valid': d.checkDigitValid,
      'model_year': d.modelYear,
      'country': d.country,
      'region': d.region,
      'manufacturer': d.manufacturer,
      'vehicle_category': d.vehicleCategory,
      'plant_code': d.plantCode,
      'wmi': d.wmi,
    };

Map<String, dynamic> vinParseMetaToJson(VinParseResult r) => {
      if (r.consensusPasses > 0) 'ocr_passes_matched': r.consensusPasses,
      if (r.ocrSnippet != null && r.ocrSnippet!.isNotEmpty) 'ocr_snippet': r.ocrSnippet,
      if (r.alternateCandidates.isNotEmpty) 'alternate_reads': r.alternateCandidates,
      'anchored_to_vin_label': r.anchored,
    };
