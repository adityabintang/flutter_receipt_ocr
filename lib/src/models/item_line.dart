/// A single line item on the receipt.
class ItemLine {
  /// Item name/description.
  final String name;

  /// Quantity purchased.
  final double quantity;

  /// Unit price per item.
  final double unitPrice;

  /// Total price for this line (quantity * unitPrice).
  final double totalPrice;

  /// Confidence scores for each field.
  final Map<String, int> confidenceScores;

  ItemLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    Map<String, int>? confidenceScores,
  }) : confidenceScores = confidenceScores ?? {'name': 95, 'quantity': 90, 'unitPrice': 90, 'totalPrice': 95};

  /// Get average confidence score for all fields.
  int get averageConfidence {
    if (confidenceScores.isEmpty) return 0;
    return (confidenceScores.values.fold<int>(0, (sum, score) => sum + score) / confidenceScores.length).toInt();
  }

  /// Verify that totalPrice is consistent with quantity * unitPrice.
  bool get isPriceConsistent {
    const tolerance = 0.01;
    return (totalPrice - (quantity * unitPrice)).abs() < tolerance;
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'totalPrice': totalPrice,
    'confidenceScores': confidenceScores,
  };

  /// Create from JSON.
  factory ItemLine.fromJson(Map<String, dynamic> json) {
    return ItemLine(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      confidenceScores: Map<String, int>.from(json['confidenceScores'] as Map? ?? {}),
    );
  }

  @override
  String toString() => 'ItemLine($name: qty=$quantity, unitPrice=$unitPrice, total=$totalPrice, avgConfidence=$averageConfidence%)';
}
