import '../exceptions/ocr_exception.dart';
import '../models/item_line.dart';
import '../models/merchant_info.dart';
import '../models/receipt_data.dart';
import '../models/summary_info.dart';
import '../models/transaction_info.dart';
import 'receipt_parser.dart';

/// Parser that handles freeform text responses using regex patterns.
class FreeformParser implements ReceiptParser {
  @override
  Future<ReceiptData> parse(
    String rawOutput, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Extract merchant info
      final merchant = _extractMerchantInfo(rawOutput);

      // Extract transaction info
      final transaction = _extractTransactionInfo(rawOutput);

      // Extract items
      final items = _extractItems(rawOutput);

      // Extract summary
      final summary = _extractSummary(rawOutput);

      // Create receipt metadata
      final receiptMetadata = ReceiptMetadata(
        rawLlmOutput: rawOutput,
        processingTimeMs: 0, // Will be set by orchestrator
        modelUsed: metadata?['modelUsed'] as String? ?? 'freeform',
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
      throw ParsingException('Failed to parse freeform response', e, rawOutput);
    }
  }

  /// Extract merchant info from text using regex patterns.
  MerchantInfo _extractMerchantInfo(String text) {
    // Try to find merchant/store name
    final lines = text.split('\n');
    String? merchantName;
    String? address;
    String? phone;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Look for merchant/store name (usually at beginning)
      if (merchantName == null && (line.toLowerCase().contains('store') ||
          line.toLowerCase().contains('restaurant') ||
          line.toLowerCase().contains('shop'))) {
        merchantName = line;
      }

      // Look for address
      if (address == null && line.contains(RegExp(r'\d+\s+\w+'))) {
        address = line;
      }

      // Look for phone number
      if (phone == null) {
        final phoneMatch = RegExp(r'\(?(\d{3})\)?[\s.-]?(\d{3})[\s.-]?(\d{4})').firstMatch(line);
        if (phoneMatch != null) {
          phone = phoneMatch.group(0);
        }
      }
    }

    // Default merchant name from first line if not found
    if (merchantName == null && lines.isNotEmpty) {
      merchantName = lines.first;
    }

    return MerchantInfo(
      name: merchantName ?? 'Unknown Store',
      address: address,
      phone: phone,
      confidenceScores: {
        'name': merchantName != null ? 70 : 50,
        if (address != null) 'address': 60,
        if (phone != null) 'phone': 80,
      },
    );
  }

  /// Extract transaction info from text using regex patterns.
  TransactionInfo _extractTransactionInfo(String text) {
    DateTime? date;
    String? time;
    String? paymentMethod;
    String? transactionId;

    // Extract date (YYYY-MM-DD or MM/DD/YYYY formats)
    final dateMatch = RegExp(r'(\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4})').firstMatch(text);
    if (dateMatch != null) {
      final dateStr = dateMatch.group(0)!;
      date = DateTime.tryParse(dateStr.replaceAll('/', '-'));
    }

    // Extract time (HH:MM format)
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?(\s?[AP]M)?').firstMatch(text);
    if (timeMatch != null) {
      time = '${timeMatch.group(1)}:${timeMatch.group(2)}';
    }

    // Extract payment method
    if (text.toLowerCase().contains('cash')) {
      paymentMethod = 'cash';
    } else if (text.toLowerCase().contains('credit')) {
      paymentMethod = 'credit';
    } else if (text.toLowerCase().contains('debit')) {
      paymentMethod = 'debit';
    } else if (text.toLowerCase().contains('mobile') || text.toLowerCase().contains('apple pay')) {
      paymentMethod = 'mobile';
    }

    // Extract transaction/receipt ID
    final idMatch = RegExp(r'(?:receipt|transaction|id|trans|txn)[#:\s]+(\w+)', caseSensitive: false)
        .firstMatch(text);
    if (idMatch != null) {
      transactionId = idMatch.group(1);
    }

    return TransactionInfo(
      date: date,
      time: time,
      paymentMethod: paymentMethod,
      transactionId: transactionId,
      confidenceScores: {
        if (date != null) 'date': 75,
        if (time != null) 'time': 70,
        if (paymentMethod != null) 'paymentMethod': 70,
        if (transactionId != null) 'transactionId': 75,
      },
    );
  }

  /// Extract items from text using regex patterns.
  List<ItemLine> _extractItems(String text) {
    final items = <ItemLine>[];

    // Look for item lines (usually contain quantity, price patterns)
    final lines = text.split('\n');
    for (final line in lines) {
      if (line.isEmpty) continue;

      // Look for lines with price patterns
      final priceMatch = RegExp(r'(\d+(?:\.\d{2})?)').allMatches(line);
      if (priceMatch.length >= 2) {
        // Assume last two numbers are quantity and price
        final matches = priceMatch.toList();
        if (matches.length >= 2) {
          final itemName = line
              .replaceAll(RegExp(r'\d+(?:\.\d{2})?'), '')
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .trim();

          if (itemName.isNotEmpty) {
            final quantity = double.tryParse(matches[-2].group(0)!) ?? 1.0;
            final price = double.tryParse(matches.last.group(0)!) ?? 0.0;

            items.add(ItemLine(
              name: itemName,
              quantity: quantity,
              unitPrice: price,
              totalPrice: price,
              confidenceScores: {
                'name': 60,
                'quantity': 50,
                'unitPrice': 65,
                'totalPrice': 65,
              },
            ));
          }
        }
      }
    }

    return items;
  }

  /// Extract summary info from text using regex patterns.
  SummaryInfo _extractSummary(String text) {
    double subtotal = 0;
    double tax = 0;
    double serviceCharge = 0;
    double grandTotal = 0;

    // Extract subtotal
    final subtotalMatch = RegExp(r'(?:subtotal|sub total|total before)[:\s]+\$?(\d+(?:\.\d{2})?)', caseSensitive: false)
        .firstMatch(text);
    if (subtotalMatch != null) {
      subtotal = double.tryParse(subtotalMatch.group(1)!) ?? 0;
    }

    // Extract tax
    final taxMatch = RegExp(r'(?:tax|sales tax)[:\s]+\$?(\d+(?:\.\d{2})?)', caseSensitive: false)
        .firstMatch(text);
    if (taxMatch != null) {
      tax = double.tryParse(taxMatch.group(1)!) ?? 0;
    }

    // Extract service charge
    final serviceMatch = RegExp(r'(?:service charge|tip|gratuity)[:\s]+\$?(\d+(?:\.\d{2})?)', caseSensitive: false)
        .firstMatch(text);
    if (serviceMatch != null) {
      serviceCharge = double.tryParse(serviceMatch.group(1)!) ?? 0;
    }

    // Extract grand total (prefer "Total" or "Grand Total")
    final totalMatch = RegExp(r'(?:grand total|total|amount due)[:\s]+\$?(\d+(?:\.\d{2})?)', caseSensitive: false)
        .allMatches(text);
    if (totalMatch.isNotEmpty) {
      // Use the last match (usually the grand total)
      grandTotal = double.tryParse(totalMatch.last.group(1)!) ?? 0;
    }

    // Calculate subtotal if not found
    if (subtotal == 0 && grandTotal > 0) {
      subtotal = grandTotal - tax - serviceCharge;
    }

    // Calculate grand total if not found
    if (grandTotal == 0) {
      grandTotal = subtotal + tax + serviceCharge;
    }

    return SummaryInfo(
      subtotal: subtotal,
      tax: tax,
      serviceCharge: serviceCharge > 0 ? serviceCharge : null,
      grandTotal: grandTotal,
      confidenceScores: {
        'subtotal': subtotalMatch != null ? 75 : 50,
        'tax': taxMatch != null ? 75 : 50,
        if (serviceCharge > 0) 'serviceCharge': serviceMatch != null ? 70 : 40,
        'grandTotal': totalMatch.isNotEmpty ? 80 : 50,
      },
    );
  }
}
