/// Summary/total information for the receipt.
class SummaryInfo {
  /// Subtotal (sum of items before tax and service charge).
  final double subtotal;

  /// Tax amount.
  final double tax;

  /// Service charge (tip, service fee, etc.).
  final double? serviceCharge;

  /// Grand total (subtotal + tax + serviceCharge).
  final double grandTotal;

  /// Confidence scores for each field.
  final Map<String, int> confidenceScores;

  SummaryInfo({
    required this.subtotal,
    required this.tax,
    this.serviceCharge,
    required this.grandTotal,
    Map<String, int>? confidenceScores,
  }) : confidenceScores = confidenceScores ?? {'subtotal': 95, 'tax': 90, 'grandTotal': 95};

  /// Get average confidence score for all fields.
  int get averageConfidence {
    if (confidenceScores.isEmpty) return 0;
    return (confidenceScores.values.fold<int>(0, (sum, score) => sum + score) / confidenceScores.length).toInt();
  }

  /// Verify that grandTotal is consistent with subtotal + tax + serviceCharge.
  bool get isTotalConsistent {
    const tolerance = 0.01;
    final expected = subtotal + tax + (serviceCharge ?? 0);
    return (grandTotal - expected).abs() < tolerance;
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'subtotal': subtotal,
    'tax': tax,
    if (serviceCharge != null) 'serviceCharge': serviceCharge,
    'grandTotal': grandTotal,
    'confidenceScores': confidenceScores,
  };

  /// Create from JSON.
  factory SummaryInfo.fromJson(Map<String, dynamic> json) {
    return SummaryInfo(
      subtotal: (json['subtotal'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      serviceCharge: json['serviceCharge'] != null ? (json['serviceCharge'] as num).toDouble() : null,
      grandTotal: (json['grandTotal'] as num).toDouble(),
      confidenceScores: Map<String, int>.from(json['confidenceScores'] as Map? ?? {}),
    );
  }

  @override
  String toString() => 'SummaryInfo(subtotal=$subtotal, tax=$tax, serviceCharge=$serviceCharge, grandTotal=$grandTotal, avgConfidence=$averageConfidence%)';
}
