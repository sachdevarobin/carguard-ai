import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import 'yolo_detection.dart';

class ExteriorDamageResult {
  const ExteriorDamageResult({
    required this.damageDetected,
    required this.confidence,
    required this.message,
    required this.detections,
    required this.modelLoaded,
    this.error,
  });

  final bool damageDetected;
  final int confidence;
  final String message;
  final List<DamageBox> detections;
  final bool modelLoaded;
  final String? error;

  Map<String, dynamic> toPayload({
    required int width,
    required int height,
    required String category,
  }) =>
      {
        'automated_check': modelLoaded,
        'manual_verification_required': !modelLoaded || damageDetected,
        'damage_detected': damageDetected,
        'damage_count': detections.length,
        'damage_types': detections.map((d) => d.label).toSet().toList(),
        'detections': detections.map((d) => d.toJson(width, height)).toList(),
        'model': 'yolov11n-car-damage',
        'category': category,
        'width': width,
        'height': height,
        if (error != null) 'model_error': error,
      };
}

class ExteriorDamageAnalyzer {
  ExteriorDamageAnalyzer._();

  static final ExteriorDamageAnalyzer instance = ExteriorDamageAnalyzer._();

  static const _modelAsset = 'assets/models/car_damage_yolo11n.onnx';

  OrtSession? _session;
  Future<void>? _loading;

  Future<bool> ensureLoaded() async {
    if (_session != null) return true;
    _loading ??= _loadModel();
    try {
      await _loading;
      return _session != null;
    } catch (_) {
      return false;
    } finally {
      _loading = null;
    }
  }

  Future<void> _loadModel() async {
    final ort = OnnxRuntime();
    _session = await ort.createSessionFromAsset(_modelAsset);
  }

  Future<void> dispose() async {
    _session = null;
    _loading = null;
  }

  Future<ExteriorDamageResult> analyze(String imagePath, {required String category}) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return const ExteriorDamageResult(
          damageDetected: false,
          confidence: 0,
          message: 'Could not decode image for damage scan.',
          detections: [],
          modelLoaded: false,
          error: 'decode_failed',
        );
      }

      final loaded = await ensureLoaded();
      if (!loaded || _session == null) {
        return ExteriorDamageResult(
          damageDetected: false,
          confidence: 50,
          message: '$category saved — damage AI model not loaded. Verify panels manually.',
          detections: const [],
          modelLoaded: false,
          error: 'model_not_loaded',
        );
      }

      final letterbox = letterboxImage(decoded);
      final input = await OrtValue.fromList(
        letterbox.tensor,
        [1, 3, letterbox.meta.inputSize, letterbox.meta.inputSize],
      );

      final outputs = await _session!.run({'images': input});
      final raw = outputs['output0'];
      if (raw == null) {
        return const ExteriorDamageResult(
          damageDetected: false,
          confidence: 0,
          message: 'Damage model returned no output.',
          detections: [],
          modelLoaded: true,
          error: 'empty_output',
        );
      }

      final flat = flattenOutput(await raw.asList());
      final detections = parseYoloDamageOutput(
        output: flat,
        meta: letterbox.meta,
      );

      if (detections.isEmpty) {
        return ExteriorDamageResult(
          damageDetected: false,
          confidence: 78,
          message:
              'No dents or scratches detected on $category. On-device AI scan complete — still verify paint and panels in person.',
          detections: const [],
          modelLoaded: true,
        );
      }

      final top = detections.first.confidence;
      final summary = detections
          .take(3)
          .map((d) => '${d.label} (${(d.confidence * 100).round()}%)')
          .join(', ');

      return ExteriorDamageResult(
        damageDetected: true,
        confidence: (top * 100).round().clamp(68, 95),
        message: 'Possible damage on $category: $summary. Inspect closely before accepting.',
        detections: detections,
        modelLoaded: true,
      );
    } catch (e, st) {
      debugPrint('ExteriorDamageAnalyzer error: $e\n$st');
      return ExteriorDamageResult(
        damageDetected: false,
        confidence: 50,
        message: 'Damage scan failed. Verify $category panels manually.',
        detections: const [],
        modelLoaded: false,
        error: e.toString(),
      );
    }
  }
}
