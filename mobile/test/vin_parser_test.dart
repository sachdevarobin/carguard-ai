import 'package:flutter_test/flutter_test.dart';

import 'package:carguard_ai/core/ai/parsers/vin_decoder.dart';
import 'package:carguard_ai/core/ai/parsers/vin_parser.dart';
import 'package:carguard_ai/core/ai/vin/vin_ocr_types.dart';

void main() {
  group('VIN decoder', () {
    test('valid Honda VIN passes check digit', () {
      const vin = '1HGBH41JXMN109186';
      expect(isValidVinCheckDigit(vin), isTrue);
      final d = decodeVin(vin);
      expect(d.modelYear, 2021);
      expect(d.manufacturer, isNotNull);
    });

    test('Indian Maruti WMI resolves manufacturer', () {
      const vin = 'MA3ERLF1S00458086';
      final d = decodeVin(vin);
      expect(d.wmi, 'MA3');
      expect(d.manufacturer, contains('Maruti'));
      expect(d.country, 'India');
    });
  });

  group('VIN OCR parse', () {
    test('accepts anchored VIN label text', () {
      const text = 'VEHICLE IDENTIFICATION\nVIN: 1HGBH41JXMN109186\nMADE IN USA';
      final result = parseVin(text);
      expect(result.vin, '1HGBH41JXMN109186');
      expect(result.checkDigitValid, isTrue);
      expect(result.anchored, isTrue);
      expect(result.isValid, isTrue);
    });

    test('fixes common OCR misreads (O→0, I→1)', () {
      const text = 'VIN 1HGBH41JXMN1O9186';
      final result = parseVin(text);
      expect(result.vin, '1HGBH41JXMN109186');
      expect(result.checkDigitValid, isTrue);
    });

    test('rejects invalid check digit', () {
      // Corrupt check-digit position (index 8) while keeping OCR-safe chars
      const text = 'VIN 1HGBH41JXMN209186';
      final result = parseVin(text);
      expect(result.vin, '1HGBH41JXMN209186');
      expect(result.checkDigitValid, isFalse);
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, isNotNull);
    });

    test('rejects too little text', () {
      final result = parseVin('abc');
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, contains('Too little text'));
    });

    test('multi-pass consensus boosts confidence', () {
      const vin = '1HGBH41JXMN109186';
      final passes = [
        VinOcrPassResult(
          source: 'enhanced',
          fullText: 'VIN $vin',
          lineTexts: ['VIN $vin'],
          weight: 1.25,
        ),
        VinOcrPassResult(
          source: 'frame_crop',
          fullText: vin,
          lineTexts: [vin],
          weight: 1.6,
        ),
      ];
      final result = parseVinFromOcrPasses(passes);
      expect(result.isValid, isTrue);
      expect(result.consensusPasses, greaterThanOrEqualTo(2));
      expect(result.confidence, greaterThanOrEqualTo(60));
    });
  });
}
