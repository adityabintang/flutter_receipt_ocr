import 'merchant_info.dart';
import 'transaction_info.dart';
import 'item_line.dart';
import 'summary_info.dart';

/// Complete structured data extracted from a receipt.
class ReceiptData {
  /// Merchant information.
  final MerchantInfo merchant;

  /// Transaction information.
  final TransactionInfo transaction;

  /// List of items on the receipt.
  final List<ItemLine> items;

  /// Summary/total information.
  final SummaryInfo summary;

  /// Metadata about the extraction.
  final ReceiptMetadata metadata;

  ReceiptData({
    required this.merchant,
    required this.transaction,
    required this.items,
    required this.summary,
    required this.metadata,
  });

  /// Get overall confidence score (weighted average).
  /// Weights: merchant.name (0.15), items (0.40), summary.grandTotal (0.25), transaction.date (0.10), transaction.paymentMethod (0.10)
  int get overallConfidence {
    double weighted = 0;

    // Merchant name weight: 0.15
    weighted += (merchant.confidenceScores['name'] ?? 0) * 0.15;

    // Items weight: 0.40 (average of all items)
    if (items.isNotEmpty) {
      final itemsAvg = items.fold<double>(0, (sum, item) => sum + item.averageConfidence) / items.length;
      weighted += itemsAvg * 0.40;
    }

    // Grand total weight: 0.25
    weighted += (summary.confidenceScores['grandTotal'] ?? 0) * 0.25;

    // Transaction date weight: 0.10
    weighted += (transaction.confidenceScores['date'] ?? 0) * 0.10;

    // Payment method weight: 0.10
    weighted += (transaction.confidenceScores['paymentMethod'] ?? 0) * 0.10;

    return weighted.toInt();
  }

  /// Validate that mandatory fields are present.
  bool get isValid {
    return merchant.name.isNotEmpty &&
           items.isNotEmpty &&
           summary.grandTotal > 0;
  }

  /// Get validation errors (empty if valid).
  List<String> get validationErrors {
    final errors = <String>[];
    if (merchant.name.isEmpty) {
      errors.add('Merchant name is required');
    }
    if (items.isEmpty) {
      errors.add('At least one item is required');
    }
    if (summary.grandTotal <= 0) {
      errors.add('Grand total must be greater than 0');
    }
    if (!summary.isTotalConsistent) {
      errors.add('Grand total does not match subtotal + tax + service charge');
    }
    return errors;
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'merchant': merchant.toJson(),
    'transaction': transaction.toJson(),
    'items': items.map((item) => item.toJson()).toList(),
    'summary': summary.toJson(),
    'metadata': metadata.toJson(),
    'overallConfidence': overallConfidence,
  };

  /// Create from JSON.
  factory ReceiptData.fromJson(Map<String, dynamic> json) {
    return ReceiptData(
      merchant: MerchantInfo.fromJson(json['merchant'] as Map<String, dynamic>),
      transaction: TransactionInfo.fromJson(json['transaction'] as Map<String, dynamic>),
      items: (json['items'] as List?)?.map((item) => ItemLine.fromJson(item as Map<String, dynamic>)).toList() ?? [],
      summary: SummaryInfo.fromJson(json['summary'] as Map<String, dynamic>),
      metadata: ReceiptMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() => 'ReceiptData(merchant: ${merchant.name}, items: ${items.length}, total: ${summary.grandTotal}, confidence: $overallConfidence%)';
}

/// Metadata about the receipt extraction.
class ReceiptMetadata {
  /// Raw output from the LLM (for debugging/transparency).
  final String rawLlmOutput;

  /// Processing time in milliseconds.
  int processingTimeMs;

  /// Model/provider used for OCR.
  final String modelUsed;

  /// Optional additional information.
  final Map<String, dynamic>? additionalData;

  ReceiptMetadata({
    required this.rawLlmOutput,
    required int processingTimeMs,
    required this.modelUsed,
    this.additionalData,
  }) : processingTimeMs = processingTimeMs;

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
    'rawLlmOutput': rawLlmOutput,
    'processingTimeMs': processingTimeMs,
    'modelUsed': modelUsed,
    if (additionalData != null) 'additionalData': additionalData,
  };

  /// Create from JSON.
  factory ReceiptMetadata.fromJson(Map<String, dynamic> json) {
    return ReceiptMetadata(
      rawLlmOutput: json['rawLlmOutput'] as String,
      processingTimeMs: json['processingTimeMs'] as int,
      modelUsed: json['modelUsed'] as String,
      additionalData: json['additionalData'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'ReceiptMetadata(model: $modelUsed, processingTime: ${processingTimeMs}ms)';
}
