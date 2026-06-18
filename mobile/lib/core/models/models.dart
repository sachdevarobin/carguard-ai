class VehicleVariant {
  const VehicleVariant({
    required this.id,
    required this.name,
    required this.features,
  });

  final String id;
  final String name;
  final List<String> features;

  factory VehicleVariant.fromJson(Map<String, dynamic> json) {
    return VehicleVariant(
      id: json['id'] as String,
      name: json['name'] as String,
      features: (json['features'] as List<dynamic>).cast<String>(),
    );
  }
}

class VehicleModel {
  const VehicleModel({
    required this.id,
    required this.name,
    required this.variants,
  });

  final String id;
  final String name;
  final List<VehicleVariant> variants;

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      name: json['name'] as String,
      variants: (json['variants'] as List<dynamic>)
          .map((item) => VehicleVariant.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class VehicleMake {
  const VehicleMake({
    required this.id,
    required this.name,
    required this.models,
  });

  final String id;
  final String name;
  final List<VehicleModel> models;

  factory VehicleMake.fromJson(Map<String, dynamic> json) {
    return VehicleMake(
      id: json['id'] as String,
      name: json['name'] as String,
      models: (json['models'] as List<dynamic>)
          .map((item) => VehicleModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class InspectionStep {
  const InspectionStep({
    required this.id,
    required this.title,
    required this.description,
    this.photoCategory,
    this.photoCategories = const [],
    required this.checklist,
  });

  final String id;
  final String title;
  final String description;
  final String? photoCategory;
  final List<String> photoCategories;
  final List<String> checklist;

  List<String> get requiredPhotoCategories {
    if (photoCategories.isNotEmpty) return photoCategories;
    if (photoCategory != null) return [photoCategory!];
    return [];
  }

  bool isComplete(Set<String> uploadedCategories) {
    final required = requiredPhotoCategories;
    if (required.isEmpty) return false;
    return required.every(uploadedCategories.contains);
  }

  factory InspectionStep.fromJson(Map<String, dynamic> json) {
    return InspectionStep(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      photoCategory: json['photo_category'] as String?,
      photoCategories: (json['photo_categories'] as List<dynamic>? ?? []).cast<String>(),
      checklist: (json['checklist'] as List<dynamic>).cast<String>(),
    );
  }
}

class InspectionSummary {
  const InspectionSummary({
    required this.id,
    required this.make,
    required this.model,
    required this.variant,
    required this.status,
    this.score,
    this.dealerName,
    this.deliveryDate,
    required this.createdAt,
  });

  final int id;
  final String make;
  final String model;
  final String variant;
  final String status;
  final int? score;
  final String? dealerName;
  final String? deliveryDate;
  final DateTime createdAt;

  String get displayName => '$make $model $variant';

  factory InspectionSummary.fromJson(Map<String, dynamic> json) {
    return InspectionSummary(
      id: json['id'] as int,
      make: json['make'] as String,
      model: json['model'] as String,
      variant: json['variant'] as String,
      status: json['status'] as String,
      score: json['score'] as int?,
      dealerName: json['dealer_name'] as String?,
      deliveryDate: json['delivery_date'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class InspectionPhoto {
  const InspectionPhoto({
    required this.id,
    required this.category,
    required this.imageUrl,
    required this.userConfirmed,
    this.analysisJson,
  });

  final int id;
  final String category;
  final String imageUrl;
  final bool userConfirmed;
  final String? analysisJson;

  factory InspectionPhoto.fromJson(Map<String, dynamic> json) {
    return InspectionPhoto(
      id: json['id'] as int,
      category: json['category'] as String,
      imageUrl: json['image_url'] as String,
      userConfirmed: json['user_confirmed'] as bool? ?? false,
      analysisJson: json['analysis_json'] as String?,
    );
  }
}

class Finding {
  const Finding({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.confidence,
  });

  final int id;
  final String type;
  final String severity;
  final String title;
  final String description;
  final int? confidence;

  factory Finding.fromJson(Map<String, dynamic> json) {
    return Finding(
      id: json['id'] as int,
      type: json['type'] as String,
      severity: json['severity'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      confidence: json['confidence'] as int?,
    );
  }
}

class InspectionReport {
  const InspectionReport({
    required this.id,
    required this.summary,
    required this.recommendations,
    this.dealerNotes,
    this.verdict,
  });

  final int id;
  final String summary;
  final String recommendations;
  final String? dealerNotes;
  final String? verdict;

  factory InspectionReport.fromJson(Map<String, dynamic> json) {
    return InspectionReport(
      id: json['id'] as int,
      summary: json['summary'] as String,
      recommendations: json['recommendations'] as String,
      dealerNotes: json['dealer_notes'] as String?,
      verdict: json['verdict'] as String?,
    );
  }
}

class InspectionDetail extends InspectionSummary {
  const InspectionDetail({
    required super.id,
    required super.make,
    required super.model,
    required super.variant,
    required super.status,
    super.score,
    super.dealerName,
    super.deliveryDate,
    required super.createdAt,
    required this.photos,
    required this.findings,
    this.report,
  });

  final List<InspectionPhoto> photos;
  final List<Finding> findings;
  final InspectionReport? report;

  factory InspectionDetail.fromJson(Map<String, dynamic> json) {
    return InspectionDetail(
      id: json['id'] as int,
      make: json['make'] as String,
      model: json['model'] as String,
      variant: json['variant'] as String,
      status: json['status'] as String,
      score: json['score'] as int?,
      dealerName: json['dealer_name'] as String?,
      deliveryDate: json['delivery_date'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((item) => InspectionPhoto.fromJson(item as Map<String, dynamic>))
          .toList(),
      findings: (json['findings'] as List<dynamic>? ?? [])
          .map((item) => Finding.fromJson(item as Map<String, dynamic>))
          .toList(),
      report: json['report'] == null
          ? null
          : InspectionReport.fromJson(json['report'] as Map<String, dynamic>),
    );
  }
}

class AnalysisProgressStep {
  const AnalysisProgressStep({required this.label, required this.done});

  final String label;
  final bool done;

  factory AnalysisProgressStep.fromJson(Map<String, dynamic> json) {
    return AnalysisProgressStep(
      label: json['label'] as String,
      done: json['done'] as bool,
    );
  }
}
