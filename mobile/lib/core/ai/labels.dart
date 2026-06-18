String retakeTitle(String category) {
  const titles = {
    'front': 'Front photo needs retake',
    'rear': 'Rear photo needs retake',
    'left': 'Left side photo needs retake',
    'right': 'Right side photo needs retake',
    'dashboard': 'Dashboard photo needs retake',
    'odometer': 'Odometer photo needs retake',
    'vin': 'VIN photo needs retake',
    'tyre': 'Tyre photo needs retake',
  };
  return titles[category] ?? '${category[0].toUpperCase()}${category.substring(1)} photo needs retake';
}

String retakeDescription(String category, Map<String, dynamic> payload) {
  const issueMessages = {
    'vin_not_found': 'VIN sticker not readable — capture the full 17-character VIN in focus.',
    'odometer_not_found': 'Odometer digits not readable — zoom in on the speedometer display.',
    'tyre_dot_not_found': 'Tyre DOT code not visible — photograph the sidewall DOT marking.',
    'blurry_image': 'Photo appears blurry — hold steady and tap to focus.',
    'low_confidence': 'Image quality too low — use brighter light and fill the frame.',
  };

  final errors = (payload['errors'] as List?)?.cast<String>() ?? [];
  for (final code in errors) {
    if (issueMessages.containsKey(code)) return issueMessages[code]!;
  }

  final confidence = payload['confidence'] as int?;
  if (confidence != null && confidence < 55) {
    return 'AI confidence was only $confidence% for this $category photo. Retake with better focus and lighting.';
  }

  final message = payload['message'] as String?;
  if (message != null && (message.toLowerCase().contains('could not') || message.toLowerCase().contains('not readable'))) {
    return message;
  }

  return 'Could not analyze this $category photo reliably. Retake with the subject centered and well lit.';
}

String humanizeWarning(String code) {
  const labels = {'warning_indicator': 'Dashboard warning indicator'};
  return labels[code] ?? code.replaceAll('_', ' ');
}
