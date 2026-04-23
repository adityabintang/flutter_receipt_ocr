/// Represents the confidence score for a specific field.
class ConfidenceScore {
  /// The name of the field.
  final String field;

  /// The confidence score (0-100).
  final int score;

  /// Optional reason for the confidence score.
  final String? reason;

  ConfidenceScore({
    required this.field,
    required this.score,
    this.reason,
  }) : assert(score >= 0 && score <= 100, 'Score must be between 0 and 100');

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'field': field,
    'score': score,
    if (reason != null) 'reason': reason,
  };

  /// Create from JSON.
  factory ConfidenceScore.fromJson(Map<String, dynamic> json) {
    return ConfidenceScore(
      field: json['field'] as String,
      score: json['score'] as int,
      reason: json['reason'] as String?,
    );
  }

  @override
  String toString() => 'ConfidenceScore($field: $score%)${reason != null ? ' - $reason' : ''}';
}
