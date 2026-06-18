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
  Uint8List? _previewBytes;
  bool _uploading = false;
  String? _lastAnalysisMessage;

  Future<void> _capture(ImageSource source) async {
    final image = await _picker.pickImage(source: source, imageQuality: 85);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _preview = image;
      _previewBytes = bytes;
    });
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
          _previewBytes = null;
          _lastAnalysisMessage = null;
        });
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_previewBytes != null)
                  Image.memory(_previewBytes!, fit: BoxFit.cover)
                else
                  Container(
                    color: const Color(0xFF111827),
                    child: const Center(
                      child: Icon(Icons.directions_car_filled_outlined, size: 120, color: Colors.white24),
                    ),
                  ),
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: MediaQuery.of(context).size.height * 0.45,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: _lastAnalysisMessage != null ? 80 : 24,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
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
                  onPressed: _preview == null || _uploading ? null : _upload,
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
