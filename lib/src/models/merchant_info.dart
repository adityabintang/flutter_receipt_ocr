/// Information about the merchant/store.
class MerchantInfo {
  /// Store/merchant name.
  final String name;

  /// Store address.
  final String? address;

  /// Store phone number.
  final String? phone;

  /// Confidence scores for each field.
  final Map<String, int> confidenceScores;

  MerchantInfo({
    required this.name,
    this.address,
    this.phone,
    Map<String, int>? confidenceScores,
  }) : confidenceScores = confidenceScores ?? {'name': 95};

  /// Get average confidence score for all fields.
  int get averageConfidence {
    if (confidenceScores.isEmpty) return 0;
    return (confidenceScores.values.fold<int>(0, (sum, score) => sum + score) / confidenceScores.length).toInt();
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'name': name,
    if (address != null) 'address': address,
    if (phone != null) 'phone': phone,
    'confidenceScores': confidenceScores,
  };

  /// Create from JSON.
  factory MerchantInfo.fromJson(Map<String, dynamic> json) {
    return MerchantInfo(
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      confidenceScores: Map<String, int>.from(json['confidenceScores'] as Map? ?? {}),
    );
  }

  @override
  String toString() => 'MerchantInfo(name: $name, address: $address, phone: $phone, avgConfidence: $averageConfidence%)';
}
