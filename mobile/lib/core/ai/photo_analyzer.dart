import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'exterior/exterior_damage_analyzer.dart';
import 'parsers/odometer_parser.dart';
import 'parsers/tyre_parser.dart';
import 'parsers/vin_parser.dart';
import 'vin/vin_enrichment_service.dart';
import 'vin/vin_image_processor.dart';
import 'vin/vin_ocr_pipeline.dart';

const _passConfidence = 68;

class PhotoAnalysisResult {
  const PhotoAnalysisResult({
    required this.confidence,
    required this.message,
    required this.data,
    this.needsRetake = false,
    this.errors = const [],
  });

  final int confidence;
  final String message;
  final Map<String, dynamic> data;
  final bool needsRetake;
  final List<String> errors;

  Map<String, dynamic> toJson() => {
        'confidence': confidence,
        'message': message,
        'needs_retake': needsRetake,
        'source': 'mlkit',
        'validation_strict': true,
        ...data,
        if (errors.isNotEmpty) 'errors': errors,
      };
}

class OnDevicePhotoAnalyzer {
  TextRecognizer? _recognizer;

  TextRecognizer get _textRecognizer =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
    await ExteriorDamageAnalyzer.instance.dispose();
  }

  Future<PhotoAnalysisResult> analyze(String category, String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return PhotoAnalysisResult(
        confidence: 0,
        message: 'Image file missing.',
        data: {},
        needsRetake: true,
        errors: ['file_missing'],
      );
    }

    if (category == 'vin') {
      return _analyzeVinImage(imagePath);
    }

    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _textRecognizer.processImage(input);
    final text = recognized.text.trim();
    final ocrConfidence = _ocrStrength(recognized, text);

    return switch (category) {
      'odometer' => _analyzeOdometer(text, ocrConfidence),
      'tyre' => _analyzeTyre(text, ocrConfidence),
      'dashboard' => _analyzeDashboard(text, ocrConfidence),
      'front' || 'rear' || 'left' || 'right' => await _analyzeExterior(category, imagePath, text),
      _ => _reject('Unknown photo category.', ['unknown_category']),
    };
  }

  double _ocrStrength(RecognizedText recognized, String text) {
    if (text.isEmpty) return 0;
    var elements = 0;
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        elements += line.elements.length;
      }
    }
    if (elements == 0) return text.length >= 8 ? 45 : 15;
    return (elements * 8 + text.length).clamp(20, 95).toDouble();
  }

  PhotoAnalysisResult _reject(String message, List<String> errors, {Map<String, dynamic>? data}) {
    return PhotoAnalysisResult(
      confidence: 0,
      message: message,
      data: data ?? {},
      needsRetake: true,
      errors: errors,
    );
  }

  Future<PhotoAnalysisResult> _analyzeVinImage(String imagePath) async {
    final processor = VinImageProcessor();
    final variants = await processor.buildVariants(imagePath);
    final parsed = await runVinOcrPipeline(
      recognizer: _textRecognizer,
      variants: variants
          .map((v) => (path: v.path, label: v.label, weight: v.weight))
          .toList(),
    );

    return await _vinResultFromParse(parsed);
  }

  Future<PhotoAnalysisResult> _vinResultFromParse(VinParseResult parsed) async {
    final enriched = parsed.vin != null
        ? await VinEnrichmentService.instance.enrich(
            parsed.vin!,
            modelYear: parsed.manufacturingYear,
            baseDetails: parsed.details,
          )
        : <String, dynamic>{};

    if (!parsed.isValid) {
      return _reject(
        parsed.rejectionReason ?? 'VIN not readable. Frame the full 17-character sticker with "VIN" label.',
        parsed.checkDigitValid ? ['vin_context_weak'] : ['vin_not_found', 'vin_check_digit_failed'],
        data: {
          if (enriched.isNotEmpty) ...enriched,
          ...vinParseMetaToJson(parsed),
        },
      );
    }

    final make = enriched['make'] ?? '';
    final model = enriched['model'] ?? '';
    final year = enriched['model_year'] ?? parsed.manufacturingYear;

    return PhotoAnalysisResult(
      confidence: parsed.confidence,
      message:
          'VIN verified (${parsed.consensusPasses} OCR passes) — $make $model $year'.trim(),
      data: {
        ...enriched,
        ...vinParseMetaToJson(parsed),
        'manufacturing_year': year,
        'confidence': parsed.confidence,
      },
      needsRetake: parsed.confidence < _passConfidence,
    );
  }

  PhotoAnalysisResult _analyzeOdometer(String text, double ocrConfidence) {
    final parsed = parseOdometer(text, ocrConfidence: ocrConfidence, strict: true);

    if (parsed.odometerKm == null || parsed.rejectionReason != null) {
      return _reject(
        parsed.rejectionReason ?? 'Odometer digits not readable. Zoom in on the cluster display.',
        ['odometer_not_found'],
        data: {'ocr_text': text},
      );
    }

    final km = parsed.odometerKm!;
    return PhotoAnalysisResult(
      confidence: parsed.confidence,
      message: 'Odometer: $km km — ${parsed.pdiVerdict ?? 'verify with paperwork'}',
      data: {
        'odometer_km': km,
        'pdi_verdict': parsed.pdiVerdict,
        'ocr_text': text,
      },
      needsRetake: parsed.confidence < _passConfidence || km > 150,
      errors: km > 150 ? ['odometer_too_high_pdi'] : const [],
    );
  }

  PhotoAnalysisResult _analyzeTyre(String text, double ocrConfidence) {
    final parsed = parseTyreDot(text, ocrConfidence: ocrConfidence);

    if (!parsed.isValid || parsed.rejectionReason != null) {
      return _reject(
        parsed.rejectionReason ?? 'Tyre DOT code not visible. Photograph the sidewall DOT marking.',
        ['tyre_dot_not_found'],
        data: {
          ...tyreDetailsToJson(parsed),
          'ocr_text': text,
        },
      );
    }

    final age = parsed.ageMonths ?? 0;
    return PhotoAnalysisResult(
      confidence: parsed.confidence,
      message: parsed.ageVerdict ?? 'Tyre age analysed.',
      data: {
        ...tyreDetailsToJson(parsed),
        'ocr_text': text,
      },
      needsRetake: parsed.confidence < _passConfidence,
      errors: age > 12 ? ['tyre_too_old'] : const [],
    );
  }

  bool _hasDashboardContext(String text) {
    final lower = text.toLowerCase();
    const keywords = [
      'rpm', 'km', 'kmh', 'km/h', 'fuel', 'temp', 'gear', 'park', 'drive',
      'odo', 'trip', 'speed', 'battery', 'ready', 'neutral', 'sport', 'eco',
    ];
    return keywords.any(lower.contains);
  }

  PhotoAnalysisResult _analyzeDashboard(String text, double ocrConfidence) {
    if (text.length < 8 || !_hasDashboardContext(text)) {
      return _reject(
        'This does not look like a dashboard/cluster photo. Random car exterior shots are rejected.',
        ['dashboard_context_missing'],
        data: {'ocr_text': text},
      );
    }

    final lower = text.toLowerCase();
    final warningKeywords = ['check engine', 'abs', 'airbag', 'warning', 'fault', 'malfunction'];
    final warnings = warningKeywords.where(lower.contains).toList();
    final odometer = parseOdometer(text, ocrConfidence: ocrConfidence, strict: false);

    if (warnings.isNotEmpty) {
      return PhotoAnalysisResult(
        confidence: 72,
        message: 'Possible dashboard warning text detected.',
        data: {
          'warning_lights': warnings,
          'odometer_km': odometer.odometerKm,
          'ocr_text': text,
        },
        needsRetake: false,
        errors: ['dashboard_warning_text'],
      );
    }

    return PhotoAnalysisResult(
      confidence: odometer.confidence > 0 ? odometer.confidence : ocrConfidence.round(),
      message: 'Dashboard recognised. Visually confirm all warning lamps are off.',
      data: {
        'warning_lights': <String>[],
        'odometer_km': odometer.odometerKm,
        'pdi_verdict': odometer.pdiVerdict,
        'ocr_text': text,
      },
      needsRetake: ocrConfidence < 40,
    );
  }

  Future<PhotoAnalysisResult> _analyzeExterior(String category, String imagePath, String text) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    if (bytes.length < 25000) {
      return _reject(
        'Photo too small or not detailed enough. Capture the full $category with good lighting.',
        ['image_too_small'],
      );
    }

    Size? size;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
    } catch (_) {
      return _reject('Could not read image file.', ['image_decode_failed']);
    }

    if (size.width < 640 || size.height < 480) {
      return _reject(
        'Resolution too low (${size.width.round()}×${size.height.round()}). Move closer.',
        ['low_resolution'],
        data: {'width': size.width.round(), 'height': size.height.round()},
      );
    }

    final damage = await ExteriorDamageAnalyzer.instance.analyze(
      imagePath,
      category: category,
    );

    return PhotoAnalysisResult(
      confidence: damage.confidence,
      message: damage.message,
      data: {
        ...damage.toPayload(
          width: size.width.round(),
          height: size.height.round(),
          category: category,
        ),
        'ocr_text': text,
      },
      needsRetake: damage.damageDetected && damage.confidence < _passConfidence,
      errors: damage.damageDetected ? ['exterior_damage_detected'] : const [],
    );
  }
}