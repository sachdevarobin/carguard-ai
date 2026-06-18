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

/// Generates OCR-friendly crops and contrast-enhanced copies of a VIN photo.
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
      VinImageVariant(label: 'enhanced', path: await write(contrast, 'enh'), weight: 1.25),
    );

    if (!isIosSimulator) {
      final inverted = img.invert(contrast);
      variants.add(
        VinImageVariant(label: 'inverted', path: await write(inverted, 'inv'), weight: 1.1),
      );
    }

    // Guide-frame crop (matches capture overlay — center 85% × 45%)
    final frame = _cropRelative(base, x: 0.075, y: 0.275, w: 0.85, h: 0.45);
    if (frame.width > 120 && frame.height > 40) {
      final frameGray = img.adjustColor(img.grayscale(frame), contrast: 1.7, brightness: 1.1);
      variants.add(
        VinImageVariant(label: 'frame_crop', path: await write(frameGray, 'frame'), weight: 1.6),
      );

      if (!isIosSimulator && frame.width < 900) {
        final upscaled = img.copyResize(frameGray, width: (frame.width * 1.8).round());
        final upContrast = img.adjustColor(upscaled, contrast: 1.75);
        variants.add(
          VinImageVariant(label: 'upscaled', path: await write(upContrast, 'up'), weight: 1.45),
        );
      }
    }

    // Lower sticker area (door jamb VIN placement)
    if (!isIosSimulator) {
      final lower = _cropRelative(base, x: 0.05, y: 0.45, w: 0.9, h: 0.45);
      if (lower.width > 120 && lower.height > 40) {
        final lowerGray = img.adjustColor(img.grayscale(lower), contrast: 1.65);
        variants.add(
          VinImageVariant(label: 'lower_crop', path: await write(lowerGray, 'lower'), weight: 1.35),
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

  img.Image _cropRelative(img.Image image, {required double x, required double y, required double w, required double h}) {
    final x1 = (image.width * x).round().clamp(0, image.width - 1);
    final y1 = (image.height * y).round().clamp(0, image.height - 1);
    final x2 = (image.width * (x + w)).round().clamp(x1 + 1, image.width);
    final y2 = (image.height * (y + h)).round().clamp(y1 + 1, image.height);
    return img.copyCrop(image, x: x1, y: y1, width: x2 - x1, height: y2 - y1);
  }
}
