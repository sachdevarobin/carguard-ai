import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// YOLO11 car-damage classes (vineetsarpal/yolov11n-car-damage).
const carDamageClassLabels = <String>[
  'Front windscreen damage',
  'Headlight damage',
  'Rear windscreen damage',
  'Running board damage',
  'Side mirror damage',
  'Taillight damage',
  'Bonnet dent',
  'Boot dent',
  'Door dent',
  'Fender dent',
  'Front bumper dent',
  'Quarter panel dent',
  'Rear bumper dent',
  'Roof dent',
];

class DamageBox {
  const DamageBox({
    required this.classIndex,
    required this.label,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final int classIndex;
  final String label;
  final double confidence;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  double get width => (x2 - x1).clamp(0, double.infinity);
  double get height => (y2 - y1).clamp(0, double.infinity);
  double get area => width * height;

  Map<String, dynamic> toJson(int imageWidth, int imageHeight) => {
        'class': label,
        'confidence': (confidence * 100).round(),
        'x1': x1.round(),
        'y1': y1.round(),
        'x2': x2.round(),
        'y2': y2.round(),
        'x_norm': (x1 / imageWidth).clamp(0, 1),
        'y_norm': (y1 / imageHeight).clamp(0, 1),
        'w_norm': (width / imageWidth).clamp(0, 1),
        'h_norm': (height / imageHeight).clamp(0, 1),
      };
}

class LetterboxMeta {
  const LetterboxMeta({
    required this.scale,
    required this.padX,
    required this.padY,
    required this.origWidth,
    required this.origHeight,
    required this.inputSize,
  });

  final double scale;
  final double padX;
  final double padY;
  final int origWidth;
  final int origHeight;
  final int inputSize;
}

class LetterboxInput {
  const LetterboxInput(this.tensor, this.meta);

  final Float32List tensor;
  final LetterboxMeta meta;
}

LetterboxInput letterboxImage(img.Image source, {int inputSize = 640}) {
  final scale = math.min(inputSize / source.width, inputSize / source.height);
  final newW = (source.width * scale).round().clamp(1, inputSize);
  final newH = (source.height * scale).round().clamp(1, inputSize);
  final padX = (inputSize - newW) / 2;
  final padY = (inputSize - newH) / 2;

  final resized = img.copyResize(source, width: newW, height: newH);
  final canvas = img.Image(width: inputSize, height: inputSize);
  img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
  img.compositeImage(canvas, resized, dstX: padX.round(), dstY: padY.round());

  final plane = inputSize * inputSize;
  final tensor = Float32List(3 * plane);
  for (var y = 0; y < inputSize; y++) {
    for (var x = 0; x < inputSize; x++) {
      final pixel = canvas.getPixel(x, y);
      final idx = y * inputSize + x;
      tensor[idx] = pixel.r / 255.0;
      tensor[plane + idx] = pixel.g / 255.0;
      tensor[(2 * plane) + idx] = pixel.b / 255.0;
    }
  }

  return LetterboxInput(
    tensor,
    LetterboxMeta(
      scale: scale,
      padX: padX,
      padY: padY,
      origWidth: source.width,
      origHeight: source.height,
      inputSize: inputSize,
    ),
  );
}

List<double> flattenOutput(dynamic raw) {
  if (raw is List) {
    if (raw.isEmpty) return const [];
    if (raw.first is num) {
      return raw.cast<num>().map((v) => v.toDouble()).toList();
    }
    return raw.expand(flattenOutput).map((v) => (v as num).toDouble()).toList();
  }
  if (raw is num) return [raw.toDouble()];
  return const [];
}

/// Parses YOLO11 output `[1, 4 + nc, anchors]` with conservative filtering.
List<DamageBox> parseYoloDamageOutput({
  required List<double> output,
  required LetterboxMeta meta,
  double confidenceThreshold = 0.68,
  double iouThreshold = 0.45,
  double minAreaFraction = 0.004,
  int maxDetections = 5,
}) {
  const numClasses = 14;
  const channels = 4 + numClasses;
  const anchors = 8400;

  if (output.length < channels * anchors) return const [];

  final imageArea = meta.origWidth * meta.origHeight;
  final minArea = imageArea * minAreaFraction;
  final candidates = <DamageBox>[];

  for (var i = 0; i < anchors; i++) {
    var bestClass = -1;
    var bestScore = 0.0;

    for (var c = 0; c < numClasses; c++) {
      final score = output[(4 + c) * anchors + i];
      if (score > bestScore) {
        bestScore = score;
        bestClass = c;
      }
    }

    if (bestScore < confidenceThreshold || bestClass < 0) continue;

    final cx = output[0 * anchors + i];
    final cy = output[1 * anchors + i];
    final w = output[2 * anchors + i];
    final h = output[3 * anchors + i];

    final x1Lb = cx - w / 2;
    final y1Lb = cy - h / 2;
    final x2Lb = cx + w / 2;
    final y2Lb = cy + h / 2;

    final x1 = ((x1Lb - meta.padX) / meta.scale).clamp(0, meta.origWidth.toDouble()).toDouble();
    final y1 = ((y1Lb - meta.padY) / meta.scale).clamp(0, meta.origHeight.toDouble()).toDouble();
    final x2 = ((x2Lb - meta.padX) / meta.scale).clamp(0, meta.origWidth.toDouble()).toDouble();
    final y2 = ((y2Lb - meta.padY) / meta.scale).clamp(0, meta.origHeight.toDouble()).toDouble();

    final box = DamageBox(
      classIndex: bestClass,
      label: carDamageClassLabels[bestClass],
      confidence: bestScore,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
    );

    if (box.width < 10 || box.height < 10) continue;
    if (box.area < minArea) continue;

    candidates.add(box);
  }

  candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
  return nonMaxSuppression(candidates, iouThreshold).take(maxDetections).toList();
}

List<DamageBox> nonMaxSuppression(List<DamageBox> boxes, double iouThreshold) {
  final kept = <DamageBox>[];
  final working = List<DamageBox>.from(boxes);

  while (working.isNotEmpty) {
    final current = working.removeAt(0);
    kept.add(current);
    working.removeWhere((other) => iou(current, other) > iouThreshold);
  }

  return kept;
}

double iou(DamageBox a, DamageBox b) {
  final interX1 = math.max(a.x1, b.x1);
  final interY1 = math.max(a.y1, b.y1);
  final interX2 = math.min(a.x2, b.x2);
  final interY2 = math.min(a.y2, b.y2);

  final interW = math.max(0, interX2 - interX1);
  final interH = math.max(0, interY2 - interY1);
  final interArea = interW * interH;
  if (interArea <= 0) return 0;

  final union = a.area + b.area - interArea;
  if (union <= 0) return 0;
  return interArea / union;
}
