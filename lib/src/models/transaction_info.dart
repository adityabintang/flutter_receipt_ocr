/// Transaction/payment information.
class TransactionInfo {
  /// Transaction date.
  final DateTime? date;

  /// Transaction time (HH:MM format).
  final String? time;

  /// Payment method (cash, credit card, mobile payment, etc.).
  final String? paymentMethod;

  /// Transaction/receipt ID.
  final String? transactionId;

  /// Confidence scores for each field.
  final Map<String, int> confidenceScores;

  TransactionInfo({
    this.date,
    this.time,
    this.paymentMethod,
    this.transactionId,
    Map<String, int>? confidenceScores,
  }) : confidenceScores = confidenceScores ?? {};

  /// Get average confidence score for all fields.
  int get averageConfidence {
    if (confidenceScores.isEmpty) return 0;
    return (confidenceScores.values.fold<int>(0, (sum, score) => sum + score) / confidenceScores.length).toInt();
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    if (date != null) 'date': date!.toIso8601String(),
    if (time != null) 'time': time,
    if (paymentMethod != null) 'paymentMethod': paymentMethod,
    if (transactionId != null) 'transactionId': transactionId,
    'confidenceScores': confidenceScores,
  };

  /// Create from JSON.
  factory TransactionInfo.fromJson(Map<String, dynamic> json) {
    return TransactionInfo(
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      time: json['time'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      transactionId: json['transactionId'] as String?,
      confidenceScores: Map<String, int>.from(json['confidenceScores'] as Map? ?? {}),
    );
  }

  @override
  String toString() => 'TransactionInfo(date: $date, time: $time, paymentMethod: $paymentMethod, id: $transactionId, avgConfidence: $averageConfidence%)';
}
