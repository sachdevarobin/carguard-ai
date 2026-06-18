import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ai/findings_builder.dart';
import '../ai/photo_analyzer.dart';
import '../navigation/photo_retake.dart';
import '../models/models.dart';
import 'database.dart';
import 'vehicle_catalog.dart';

class InspectionRepository {
  InspectionRepository({OnDevicePhotoAnalyzer? analyzer}) : _analyzer = analyzer;

  OnDevicePhotoAnalyzer? _analyzer;
  final _catalog = VehicleCatalog.instance;

  OnDevicePhotoAnalyzer get _photoAnalyzer => _analyzer ??= OnDevicePhotoAnalyzer();

  void dispose() => _analyzer?.dispose();

  Future<List<VehicleMake>> fetchVehicles() => _catalog.loadMakes();

  Future<List<InspectionStep>> fetchInspectionSteps({
    required String make,
    required String model,
    required String variant,
  }) async {
    await _catalog.loadMakes();
    return _catalog.journeySteps(make, model, variant);
  }

  Future<InspectionSummary> createInspection({
    required String make,
    required String model,
    required String variant,
    String? dealerName,
    String? deliveryDate,
  }) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('inspections', {
      'make': make,
      'model': model,
      'variant': variant,
      'dealer_name': dealerName,
      'delivery_date': deliveryDate,
      'status': 'draft',
      'created_at': now,
    });
    return InspectionSummary(
      id: id,
      make: make,
      model: model,
      variant: variant,
      status: 'draft',
      dealerName: dealerName,
      deliveryDate: deliveryDate,
      createdAt: DateTime.parse(now),
    );
  }

  Future<List<InspectionSummary>> fetchInspections() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('inspections', orderBy: 'created_at DESC');
    return rows.map(_summaryFromRow).toList();
  }

  Future<InspectionDetail> fetchInspection(int id) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('inspections', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw Exception('Inspection not found');

    final photoRows = await db.query('photos', where: 'inspection_id = ?', whereArgs: [id]);
    final findingRows = await db.query('findings', where: 'inspection_id = ?', whereArgs: [id]);

    final row = rows.first;
    final report = row['summary'] != null
        ? InspectionReport(
            id: id,
            summary: row['summary'] as String,
            recommendations: row['recommendations'] as String? ?? '',
            dealerNotes: row['dealer_notes'] as String?,
            verdict: row['verdict'] as String?,
          )
        : null;

    return InspectionDetail(
      id: id,
      make: row['make'] as String,
      model: row['model'] as String,
      variant: row['variant'] as String,
      status: row['status'] as String,
      score: row['score'] as int?,
      dealerName: row['dealer_name'] as String?,
      deliveryDate: row['delivery_date'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      photos: photoRows.map(_photoFromRow).toList(),
      findings: findingRows.map(_findingFromRow).toList(),
      report: report,
    );
  }

  Future<PhotoAnalysisResult> savePhoto({
    required int inspectionId,
    required String category,
    required List<int> bytes,
    required String filename,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'inspection_photos', '$inspectionId'));
    await photosDir.create(recursive: true);
    final ext = p.extension(filename).replaceAll('.', '');
    final localName = '${category}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final localPath = p.join(photosDir.path, localName);
    await File(localPath).writeAsBytes(bytes);

    final analysis = await _photoAnalyzer.analyze(category, localPath);
    final db = await AppDatabase.instance.database;

    await db.delete(
      'photos',
      where: 'inspection_id = ? AND category = ?',
      whereArgs: [inspectionId, category],
    );

    await db.insert('photos', {
      'inspection_id': inspectionId,
      'category': category,
      'local_path': localPath,
      'analysis_json': jsonEncode(analysis.toJson()),
      'created_at': DateTime.now().toIso8601String(),
    });

    await db.update(
      'inspections',
      {'status': 'in_progress'},
      where: 'id = ?',
      whereArgs: [inspectionId],
    );

    await _syncFindingsFromPhotos(inspectionId);

    return analysis;
  }

  /// Clears all photos, findings, and report data. Keeps vehicle selection.
  Future<void> restartInspection(int id) async {
    final db = await AppDatabase.instance.database;
    final inspection = await fetchInspection(id);

    for (final photo in inspection.photos) {
      try {
        final file = File(photo.imageUrl);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'inspection_photos', '$id'));
    if (await photosDir.exists()) {
      await photosDir.delete(recursive: true);
    }

    await db.delete('photos', where: 'inspection_id = ?', whereArgs: [id]);
    await db.delete('findings', where: 'inspection_id = ?', whereArgs: [id]);
    await db.update(
      'inspections',
      {
        'status': 'draft',
        'score': null,
        'summary': null,
        'recommendations': null,
        'dealer_notes': null,
        'verdict': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Rebuilds findings and score from current photo analysis (e.g. after a retake).
  Future<void> _syncFindingsFromPhotos(int id) async {
    final db = await AppDatabase.instance.database;
    final inspection = await fetchInspection(id);
    if (inspection.photos.isEmpty) return;

    await _catalog.loadMakes();
    final features = _catalog.featuresFor(inspection.make, inspection.model, inspection.variant);

    final photoResults = inspection.photos.map((photo) {
      final payload = photo.analysisJson != null
          ? jsonDecode(photo.analysisJson!) as Map<String, dynamic>
          : <String, dynamic>{};
      return (category: photo.category, payload: payload);
    }).toList();

    final findings = buildFindings(
      inspectionId: id,
      variant: inspection.variant,
      featureCount: features.length,
      photoResults: photoResults,
    );

    final report = buildReport(
      make: inspection.make,
      model: inspection.model,
      variant: inspection.variant,
      findings: findings,
    );

    final stillNeedsRetake = inspection.photos.any(photoNeedsRetake);

    await db.delete('findings', where: 'inspection_id = ?', whereArgs: [id]);
    for (final finding in report.findings) {
      await db.insert('findings', {
        'inspection_id': id,
        'type': finding.type,
        'severity': finding.severity,
        'title': finding.title,
        'description': finding.description,
        'confidence': finding.confidence,
      });
    }

    await db.update(
      'inspections',
      {
        'status': stillNeedsRetake ? 'in_progress' : 'completed',
        'score': report.score,
        'summary': report.summary,
        'recommendations': report.recommendations,
        'dealer_notes': report.dealerNotes,
        'verdict': report.verdict,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<InspectionDetail> analyzeInspection(int id) async {
    await _syncFindingsFromPhotos(id);
    return fetchInspection(id);
  }

  Future<List<AnalysisProgressStep>> fetchAnalysisProgress(int id) async {
    final inspection = await fetchInspection(id);
    final categories = inspection.photos.map((p) => p.category).toSet();
    return [
      AnalysisProgressStep(label: 'VIN detected', done: categories.contains('vin')),
      AnalysisProgressStep(label: 'Odometer extracted', done: categories.contains('odometer')),
      AnalysisProgressStep(label: 'Tyre age calculated', done: categories.contains('tyre')),
      AnalysisProgressStep(label: 'Analyzing body panels', done: categories.contains('front')),
      AnalysisProgressStep(label: 'Generating report', done: inspection.status == 'completed'),
    ];
  }

  InspectionSummary _summaryFromRow(Map<String, Object?> row) => InspectionSummary(
        id: row['id'] as int,
        make: row['make'] as String,
        model: row['model'] as String,
        variant: row['variant'] as String,
        status: row['status'] as String,
        score: row['score'] as int?,
        dealerName: row['dealer_name'] as String?,
        deliveryDate: row['delivery_date'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  InspectionPhoto _photoFromRow(Map<String, Object?> row) => InspectionPhoto(
        id: row['id'] as int,
        category: row['category'] as String,
        imageUrl: row['local_path'] as String,
        userConfirmed: false,
        analysisJson: row['analysis_json'] as String?,
      );

  Finding _findingFromRow(Map<String, Object?> row) => Finding(
        id: row['id'] as int,
        type: row['type'] as String,
        severity: row['severity'] as String,
        title: row['title'] as String,
        description: row['description'] as String,
        confidence: row['confidence'] as int?,
      );
}
