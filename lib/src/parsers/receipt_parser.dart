import '../models/receipt_data.dart';

/// Interface for parsing raw LLM output into structured ReceiptData.
abstract class ReceiptParser {
  /// Parse raw LLM output into structured receipt data.
  ///
  /// [rawOutput] - Raw text response from LLM
  /// [metadata] - Optional metadata to include in the result
  /// Returns parsed ReceiptData object
  Future<ReceiptData> parse(
    String rawOutput, {
    Map<String, dynamic>? metadata,
  });
}
