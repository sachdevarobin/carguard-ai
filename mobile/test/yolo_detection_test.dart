import 'package:flutter_test/flutter_test.dart';
import 'package:carguard_ai/core/ai/exterior/yolo_detection.dart';

void main() {
  test('parseYoloDamageOutput keeps high-confidence box', () {
    const anchors = 8400;
    const channels = 18;
    final output = List<double>.filled(channels * anchors, 0);

    const i = 120;
    output[0 * anchors + i] = 320;
    output[1 * anchors + i] = 320;
    output[2 * anchors + i] = 80;
    output[3 * anchors + i] = 60;
    output[(4 + 8) * anchors + i] = 0.82; // door dent

    final meta = LetterboxMeta(
      scale: 1,
      padX: 0,
      padY: 0,
      origWidth: 640,
      origHeight: 480,
      inputSize: 640,
    );

    final boxes = parseYoloDamageOutput(output: output, meta: meta);
    expect(boxes, isNotEmpty);
    expect(boxes.first.label, 'Door dent');
    expect(boxes.first.confidence, greaterThan(0.8));
  });

  test('parseYoloDamageOutput drops low-confidence noise', () {
    const anchors = 8400;
    const channels = 18;
    final output = List<double>.filled(channels * anchors, 0);

    const i = 42;
    output[0 * anchors + i] = 100;
    output[1 * anchors + i] = 100;
    output[2 * anchors + i] = 40;
    output[3 * anchors + i] = 40;
    output[(4 + 3) * anchors + i] = 0.35;

    final meta = LetterboxMeta(
      scale: 1,
      padX: 0,
      padY: 0,
      origWidth: 640,
      origHeight: 480,
      inputSize: 640,
    );

    final boxes = parseYoloDamageOutput(output: output, meta: meta);
    expect(boxes, isEmpty);
  });
}
