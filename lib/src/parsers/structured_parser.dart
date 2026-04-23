import 'dart:convert';

import '../exceptions/ocr_exception.dart';
import '../models/item_line.dart';
import '../models/merchant_info.dart';
import '../models/receipt_data.dart';
import '../models/summary_info.dart';
import '../models/transaction_info.dart';
import 'receipt_parser.dart';

/// Parser that handles structured JSON responses from LLM.
class StructuredParser implements ReceiptParser {
  @override
  Future<ReceiptData> parse(
    String rawOutput, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Extract JSON from response (in case there's surrounding text)
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawOutput);
      if (jsonMatch == null) {
        throw ParsingException('No JSON found in LLM output', null, rawOutput);
      }

      final jsonStr = jsonMatch.group(0)!;
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Parse merchant info
      final merchantData = data['merchant'] as Map<String, dynamic>? ?? {};
      final merchant = MerchantInfo(
        name: merchantData['name'] as String? ?? 'Unknown',
        address: merchantData['address'] as String?,
        phone: merchantData['phone'] as String?,
        confidenceScores: {
          'name': _calculateConfidence(merchantData['name'], 95),
          if (merchantData['address'] != null)
            'address': _calculateConfidence(merchantData['address'], 80),
          if (merchantData['phone'] != null)
            'phone': _calculateConfidence(merchantData['phone'], 80),
        },
      );

      // Parse transaction info
      final transactionData = data['transaction'] as Map<String, dynamic>? ?? {};
      final transaction = TransactionInfo(
        date: transactionData['date'] != null
            ? DateTime.tryParse(transactionData['date'] as String)
            : null,
        time: transactionData['time'] as String?,
        paymentMethod: transactionData['paymentMethod'] as String?,
        transactionId: transactionData['transactionId'] as String?,
        confidenceScores: {
          if (transactionData['date'] != null)
            'date': _calculateConfidence(transactionData['date'], 90),
          if (transactionData['time'] != null)
            'time': _calculateConfidence(transactionData['time'], 85),
          if (transactionData['paymentMethod'] != null)
            'paymentMethod': _calculateConfidence(transactionData['paymentMethod'], 85),
          if (transactionData['transactionId'] != null)
            'transactionId': _calculateConfidence(transactionData['transactionId'], 90),
        },
      );

      // Parse items
      final itemsData = data['items'] as List?;
      final items = <ItemLine>[];
      if (itemsData != null) {
        for (final itemData in itemsData) {
          if (itemData is Map<String, dynamic>) {
            items.add(ItemLine(
              name: itemData['name'] as String? ?? 'Unknown Item',
              quantity: _toDouble(itemData['quantity']),
              unitPrice: _toDouble(itemData['unitPrice']),
              totalPrice: _toDouble(itemData['totalPrice']),
              confidenceScores: {
                'name': _calculateConfidence(itemData['name'], 95),
                'quantity': _calculateConfidence(itemData['quantity'], 90),
                'unitPrice': _calculateConfidence(itemData['unitPrice'], 90),
                'totalPrice': _calculateConfidence(itemData['totalPrice'], 95),
              },
            ));
          }
        }
      }

      // Parse summary
      final summaryData = data['summary'] as Map<String, dynamic>? ?? {};
      final summary = SummaryInfo(
        subtotal: _toDouble(summaryData['subtotal']),
        tax: _toDouble(summaryData['tax']),
        serviceCharge: summaryData['serviceCharge'] != null
            ? _toDouble(summaryData['serviceCharge'])
            : null,
        grandTotal: _toDouble(summaryData['grandTotal']),
        confidenceScores: {
          'subtotal': _calculateConfidence(summaryData['subtotal'], 95),
          'tax': _calculateConfidence(summaryData['tax'], 90),
          if (summaryData['serviceCharge'] != null)
            'serviceCharge': _calculateConfidence(summaryData['serviceCharge'], 85),
          'grandTotal': _calculateConfidence(summaryData['grandTotal'], 95),
        },
      );

      // Create receipt metadata
      final receiptMetadata = ReceiptMetadata(
        rawLlmOutput: rawOutput,
        processingTimeMs: 0, // Will be set by orchestrator
        modelUsed: metadata?['modelUsed'] as String? ?? 'structured',
        additionalData: metadata,
      );

      final receipt = ReceiptData(
        merchant: merchant,
        transaction: transaction,
        items: items,
        summary: summary,
        metadata: receiptMetadata,
      );

      // Validate receipt
      if (!receipt.isValid) {
        final errors = receipt.validationErrors;
        throw ParsingException('Receipt validation failed: ${errors.join(', ')}');
      }

      return receipt;
    } on ParsingException {
      rethrow;
    } catch (e) {
      throw ParsingException('Failed to parse structured response', e, rawOutput);
    }
  }

  /// Calculate confidence score for a field value.
  int _calculateConfidence(dynamic value, int baseScore) {
    if (value == null) return 0;
    if (value is String && value.isEmpty) return 0;

    // Reduce confidence for suspicious values
    if (value is String) {
      // Low confidence for very short values (might be OCR error)
      if (value.length < 2) return (baseScore * 0.6).toInt();
      // Penalize values with unusual characters
      if (!RegExp(r'^[a-zA-Z0-9\s\-.,#/@()]+$').hasMatch(value)) {
        return (baseScore * 0.8).toInt();
      }
    }

    return baseScore;
  }

  /// Convert dynamic value to double safely.
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }
}
