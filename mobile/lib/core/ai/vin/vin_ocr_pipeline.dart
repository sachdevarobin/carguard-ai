import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../parsers/vin_parser.dart';
import 'vin_ocr_types.dart';

/// Runs ML Kit on multiple image variants and merges line-level text.
class VinOcrCollector {
  VinOcrCollector(this._recognizer);

  final TextRecognizer _recognizer;

  Future<VinOcrPassResult> runPass(String imagePath, String source, double weight) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(input);
    final lines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.isNotEmpty) lines.add(t);
      }
    }
    return VinOcrPassResult(
      source: source,
      fullText: recognized.text.trim(),
      lineTexts: lines,
      weight: weight,
    );
  }
}

/// Full multi-pass VIN OCR + consensus parse.
Future<VinParseResult> runVinOcrPipeline({
  required TextRecognizer recognizer,
  required List<({String path, String label, double weight})> variants,
}) async {
  final collector = VinOcrCollector(recognizer);
  final passes = <VinOcrPassResult>[];

  for (final v in variants) {
    if (v.path.isEmpty) continue;
    try {
      passes.add(await collector.runPass(v.path, v.label, v.weight));
    } catch (_) {}
  }

  if (passes.isEmpty) {
    return const VinParseResult(rejectionReason: 'OCR could not read this image.');
  }

  return parseVinFromOcrPasses(passes);
}
