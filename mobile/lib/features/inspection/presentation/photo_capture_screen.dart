import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ai/analysis_detail_widgets.dart';
import '../../../core/ai/photo_analyzer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/widgets/layout_helpers.dart';
import '../../../core/widgets/photo_crop_screen.dart';

class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({
    super.key,
    required this.inspectionId,
    required this.category,
    required this.title,
    required this.hint,
  });

  final int inspectionId;
  final String category;
  final String title;
  final String hint;

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  final _picker = ImagePicker();
  XFile? _preview;
  Uint8List? _originalBytes;
  Uint8List? _previewBytes;
  bool _uploading = false;
  bool _usingCrop = false;
  String? _lastAnalysisMessage;

  Future<void> _capture(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 100,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    // Full photo by default — crop is optional via "Adjust crop".
    setState(() {
      _preview = image;
      _originalBytes = bytes;
      _previewBytes = bytes;
      _usingCrop = false;
      _lastAnalysisMessage = null;
    });
  }

  Future<void> _recrop() async {
    if (_originalBytes == null) return;
    final cropped = await PhotoCropScreen.show(
      context,
      bytes: _originalBytes!,
      hint: widget.hint,
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _previewBytes = cropped;
      _usingCrop = true;
      _lastAnalysisMessage = null;
    });
  }

  Future<void> _useFullPhoto() async {
    if (_originalBytes == null) return;
    setState(() {
      _previewBytes = _originalBytes;
      _usingCrop = false;
      _lastAnalysisMessage = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Using full photo — nothing cropped')),
      );
    }
  }

  Future<void> _upload() async {
    if (_preview == null || _previewBytes == null) return;
    setState(() {
      _uploading = true;
      _lastAnalysisMessage = null;
    });
    try {
      final repo = ref.read(inspectionRepositoryProvider);
      final result = await repo.savePhoto(
        inspectionId: widget.inspectionId,
        category: widget.category,
        bytes: _previewBytes!,
        filename: _preview!.name,
      );
      ref.invalidate(inspectionDetailProvider(widget.inspectionId));
      ref.invalidate(inspectionsProvider);
      if (mounted) {
        setState(() => _lastAnalysisMessage = result.message);
        final stayToRetake = await _showAnalysisDialog(result);
        if (mounted && !stayToRetake) context.pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<bool> _showAnalysisDialog(PhotoAnalysisResult result) {
    final card = buildAnalysisCardFromJson(widget.category, result.toJson());

    return showDialog<bool>(
      context: context,
      barrierDismissible: !result.needsRetake,
      builder: (context) => AlertDialog(
        icon: Icon(
          result.needsRetake ? Icons.warning_amber_rounded : Icons.document_scanner_outlined,
          color: result.needsRetake ? AppColors.warning : AppColors.success,
        ),
        title: Text(result.needsRetake ? 'Did not pass validation' : 'AI analysis'),
        content: DialogBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result.message, style: const TextStyle(height: 1.35)),
              if (card != null) ...[
                const SizedBox(height: 16),
                ...card.rows.map(
                  (row) => DetailField(label: row.label, value: row.value, dense: true),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Strict on-device validation — random car photos are rejected.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          if (result.needsRetake)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Retake now'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(result.needsRetake ? 'Keep this photo' : 'OK'),
          ),
        ],
      ),
    ).then((stay) {
      if (stay == true) {
        setState(() {
          _preview = null;
          _originalBytes = null;
          _previewBytes = null;
          _usingCrop = false;
          _lastAnalysisMessage = null;
        });
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _previewBytes != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          if (hasPreview && _originalBytes != null) ...[
            if (_usingCrop)
              TextButton(
                onPressed: _uploading ? null : _useFullPhoto,
                child: const Text('Full photo'),
              ),
            TextButton(
              onPressed: _uploading ? null : _recrop,
              child: const Text('Adjust crop'),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: Colors.black,
              child: hasPreview
                  ? InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          _previewBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_camera_outlined, size: 72, color: Colors.grey.shade700),
                            const SizedBox(height: 20),
                            Text(
                              widget.hint,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade400, height: 1.4, fontSize: 15),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'The full photo is analyzed — nothing is auto-cropped.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          if (hasPreview)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: Colors.black,
              child: Text(
                _usingCrop
                    ? 'Cropped region will be analyzed. Tap Full photo to use the entire image.'
                    : 'Full photo — pinch to zoom. Tap Adjust crop only if you want a smaller area.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.35),
              ),
            ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : () => _capture(ImageSource.camera),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Camera'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _uploading ? null : () => _capture(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: hasPreview && !_uploading ? _upload : null,
                  child: _uploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Text(widget.category == 'vin' ? 'Scanning VIN…' : 'Scanning with AI…'),
                          ],
                        )
                      : const Text('Save & Analyze'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
