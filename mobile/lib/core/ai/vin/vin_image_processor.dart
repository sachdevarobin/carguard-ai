import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../platform/device_caps.dart';

/// Preprocessed image variants for multi-pass VIN OCR.
class VinImageVariant {
  const VinImageVariant({required this.label, required this.path, required this.weight});

  final String label;
  final String path;
  final double weight;
}

/// Contrast-enhanced copies of the user-cropped VIN photo (no extra auto-crop).
class VinImageProcessor {
  static const _maxDimension = 2200;
  static const _simulatorMaxDimension = 1400;

  int get _maxDim => isIosSimulator ? _simulatorMaxDimension : _maxDimension;

  Future<List<VinImageVariant>> buildVariants(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return [VinImageVariant(label: 'original', path: sourcePath, weight: 1.0)];
    }

    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final variants = <VinImageVariant>[];

    Future<String> write(img.Image image, String name) async {
      final path = p.join(tempDir.path, 'vin_${stamp}_$name.jpg');
      await File(path).writeAsBytes(Uint8List.fromList(img.encodeJpg(image, quality: 92)));
      return path;
    }

    final base = _resize(decoded);
    variants.add(VinImageVariant(label: 'original', path: await write(base, 'orig'), weight: 1.0));

    final gray = img.grayscale(base);
    final contrast = img.adjustColor(gray, contrast: 1.55, brightness: 1.08, gamma: 0.92);
    variants.add(
      VinImageVariant(label: 'enhanced', path: await write(contrast, 'enh'), weight: 1.3),
    );

    if (!isIosSimulator) {
      final inverted = img.invert(contrast);
      variants.add(
        VinImageVariant(label: 'inverted', path: await write(inverted, 'inv'), weight: 1.15),
      );

      if (base.width < 1400) {
        final upscaled = img.copyResize(base, width: (base.width * 1.6).round());
        final upContrast = img.adjustColor(img.grayscale(upscaled), contrast: 1.7, brightness: 1.08);
        variants.add(
          VinImageVariant(label: 'upscaled', path: await write(upContrast, 'up'), weight: 1.2),
        );
      }
    }

    return variants;
  }

  img.Image _resize(img.Image image) {
    final longest = image.width > image.height ? image.width : image.height;
    if (longest <= _maxDim) return image;
    final scale = _maxDim / longest;
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.linear,
    );
  }
}
