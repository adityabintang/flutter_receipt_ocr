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
      final priceMatches = RegExp(r'(\d+(?:\.\d{2})?)').allMatches(line).toList();
      if (priceMatches.length >= 2) {
        // Assume last two numbers are quantity and price
        final matches = priceMatches;
        if (matches.length >= 2) {
          final itemName = line
              .replaceAll(RegExp(r'\d+(?:\.\d{2})?'), '')
              .replaceAll(RegExp(r'[^\w\s]'), '')
              .trim();

          if (itemName.isNotEmpty) {
            final quantity = matches.length >= 2 ? double.tryParse(matches[matches.length - 2].group(0)!) ?? 1.0 : 1.0;
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

    bool foundSubtotal = false;
    bool foundTax = false;
    bool foundService = false;
    bool foundTotal = false;

    // Helper to parse numbers with various international formats
    double parseNumber(String numStr) {
      String normalized = numStr.trim().replaceAll(RegExp(r'[Rp€\$£₹\s]', caseSensitive: false), '');

      // Handle different decimal separators
      if (normalized.contains(',') && normalized.contains('.')) {
        final lastCommaIdx = normalized.lastIndexOf(',');
        final lastPeriodIdx = normalized.lastIndexOf('.');
        if (lastCommaIdx > lastPeriodIdx) {
          // European format: 1.234,56
          normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
        } else {
          // US format: 1,234.56
          normalized = normalized.replaceAll(',', '');
        }
      } else if (normalized.contains(',')) {
        final parts = normalized.split(',');
        // Decimal if exactly 2 digits after single comma
        if (parts.length == 2 && parts.last.length == 2) {
          normalized = normalized.replaceAll(',', '.');
        } else {
          normalized = normalized.replaceAll(',', '');
        }
      }

      return double.tryParse(normalized) ?? 0;
    }

    // Extract last number from a line (handles formats like "256,680" or "1,234.56" or "20.87")
    double? extractLastNumber(String line) {
      final numberPattern = RegExp(r'\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?');
      final matches = numberPattern.allMatches(line).toList();
      if (matches.isEmpty) return null;
      final value = parseNumber(matches.last.group(0)!);
      return value > 0 ? value : null;
    }

    final lines = text.split('\n');

    for (final line in lines) {
      final lower = line.toLowerCase().trim();
      if (lower.isEmpty) continue;

      // Subtotal (check before total to avoid "subtotal" matching "total")
      if (!foundSubtotal &&
          (lower.contains('subtotal') ||
              lower.contains('sub total') ||
              lower.contains('sub-total') ||
              lower.contains('total before'))) {
        final value = extractLastNumber(line);
        if (value != null) {
          subtotal = value;
          foundSubtotal = true;
        }
        continue;
      }

      // Tax (PPN = Indonesian VAT, Pajak = Indonesian tax)
      if (!foundTax &&
          (lower.contains('sales tax') ||
              RegExp(r'\btax\b').hasMatch(lower) ||
              RegExp(r'\bppn\b').hasMatch(lower) ||
              RegExp(r'\bpajak\b').hasMatch(lower))) {
        final value = extractLastNumber(line);
        if (value != null) {
          tax = value;
          foundTax = true;
        }
        continue;
      }

      // Service charge (biaya layanan = Indonesian service fee)
      if (!foundService &&
          (lower.contains('service charge') ||
              lower.contains('service-charge') ||
              lower.contains('gratuity') ||
              lower.contains('biaya layanan') ||
              RegExp(r'\btip\b').hasMatch(lower))) {
        final value = extractLastNumber(line);
        if (value != null) {
          serviceCharge = value;
          foundService = true;
        }
        continue;
      }

      // Grand total (prioritize explicit grand total keywords)
      final isExplicitTotal = lower.contains('grand total') ||
          lower.contains('total harga') || // Indonesian: total price
          lower.contains('total bayar') || // Indonesian: total to pay
          lower.contains('jumlah bayar') || // Indonesian: amount to pay
          lower.contains('amount due') ||
          lower.contains('total due');
      final isGenericTotal = RegExp(r'\btotal\b').hasMatch(lower) &&
          !lower.contains('subtotal') &&
          !lower.contains('sub total');

      if (isExplicitTotal || (isGenericTotal && !foundTotal)) {
        final value = extractLastNumber(line);
        if (value != null) {
          // Explicit total always wins; otherwise take highest
          if (isExplicitTotal || value > grandTotal) {
            grandTotal = value;
            foundTotal = true;
          }
        }
      }
    }

    // Fallback: if still no grand total, find the largest number on a line containing any currency indicator
    if (!foundTotal) {
      for (final line in lines) {
        if (RegExp(r'Rp\.?|[\$€£₹]', caseSensitive: false).hasMatch(line)) {
          final value = extractLastNumber(line);
          if (value != null && value > grandTotal) {
            grandTotal = value;
          }
        }
      }
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
        'subtotal': foundSubtotal ? 75 : 50,
        'tax': foundTax ? 75 : 50,
        if (serviceCharge > 0) 'serviceCharge': foundService ? 70 : 40,
        'grandTotal': foundTotal ? 80 : 50,
      },
    );
  }
}
