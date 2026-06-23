import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Lets the user choose exactly what region is sent to AI (no silent auto-crop).
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({
    super.key,
    required this.imageBytes,
    required this.hint,
  });

  final Uint8List imageBytes;
  final String hint;

  static Future<Uint8List?> show(
    BuildContext context, {
    required Uint8List bytes,
    required String hint,
  }) {
    return Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoCropScreen(imageBytes: bytes, hint: hint),
      ),
    );
  }

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  final _cropController = CropController();
  var _cropping = false;

  void _applyCrop() {
    if (_cropping) return;
    setState(() => _cropping = true);
    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Select detection area'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cropping ? null : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Drag the corners to include the full sticker or label. '
              'Only the area inside the box is analyzed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, height: 1.35, fontSize: 13),
            ),
          ),
          Expanded(
            child: Crop(
              controller: _cropController,
              image: widget.imageBytes,
              baseColor: Colors.black,
              maskColor: Colors.black.withValues(alpha: 0.55),
              radius: 8,
              initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                size: 1.0,
              ),
              onCropped: (result) {
                if (!mounted) return;
                setState(() => _cropping = false);
                switch (result) {
                  case CropSuccess(:final croppedImage):
                    Navigator.pop(context, croppedImage);
                  case CropFailure(:final cause):
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not crop: $cause')),
                    );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _cropping
                      ? null
                      : () => Navigator.pop(context, widget.imageBytes),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Use full photo (no crop)'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _cropping ? null : _applyCrop,
                  child: _cropping
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Apply crop'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
