/// One OCR pass over a preprocessed image variant.
class VinOcrPassResult {
  const VinOcrPassResult({
    required this.source,
    required this.fullText,
    required this.lineTexts,
    required this.weight,
  });

  final String source;
  final String fullText;
  final List<String> lineTexts;
  final double weight;
}
