import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../ai/analysis_summary.dart';

bool photoNeedsRetake(InspectionPhoto photo) {
  if (photo.analysisJson == null || photo.analysisJson!.isEmpty) return false;
  final data = jsonDecode(photo.analysisJson!) as Map<String, dynamic>;
  return data['needs_retake'] == true;
}

String? retakeReason(InspectionPhoto photo) {
  if (!photoNeedsRetake(photo)) return null;
  final data = jsonDecode(photo.analysisJson!) as Map<String, dynamic>;
  return data['message'] as String? ?? 'Photo needs a clearer retake.';
}

List<InspectionPhoto> photosNeedingRetake(List<InspectionPhoto> photos) =>
    photos.where(photoNeedsRetake).toList();

class PhotoCaptureMeta {
  const PhotoCaptureMeta({required this.title, required this.hint});

  final String title;
  final String hint;
}

PhotoCaptureMeta captureMetaForCategory(String category) {
  return switch (category) {
    'front' => const PhotoCaptureMeta(
        title: 'Front View',
        hint: 'Place the entire front of the vehicle inside the frame.',
      ),
    'rear' => const PhotoCaptureMeta(
        title: 'Rear View',
        hint: 'Capture the full rear including bumper and tail lights.',
      ),
    'left' => const PhotoCaptureMeta(
        title: 'Left Side',
        hint: 'Stand to the left and capture the full side profile.',
      ),
    'right' => const PhotoCaptureMeta(
        title: 'Right Side',
        hint: 'Stand to the right and capture the full side profile.',
      ),
    'dashboard' => const PhotoCaptureMeta(
        title: 'Dashboard',
        hint: 'Photograph the instrument cluster with warning lights visible.',
      ),
    'odometer' => const PhotoCaptureMeta(
        title: 'Odometer',
        hint: 'Zoom in on the odometer digits — reading should be sharp.',
      ),
    'vin' => const PhotoCaptureMeta(
        title: 'VIN Sticker',
        hint: 'Fill the frame with the VIN sticker. Keep the word "VIN" and all 17 characters sharp and horizontal.',
      ),
    'tyre' => const PhotoCaptureMeta(
        title: 'Tyre Sidewall',
        hint: 'Photograph the DOT code on the tyre sidewall.',
      ),
    _ => PhotoCaptureMeta(
        title: categoryLabel(category),
        hint: 'Retake with better lighting and the subject centered.',
      ),
  };
}

Future<void> openPhotoRetake(
  BuildContext context, {
  required int inspectionId,
  required String category,
}) {
  final meta = captureMetaForCategory(category);
  return context.push(
    '/inspection/$inspectionId/capture/$category'
    '?title=${Uri.encodeComponent(meta.title)}'
    '&hint=${Uri.encodeComponent(meta.hint)}',
  );
}
