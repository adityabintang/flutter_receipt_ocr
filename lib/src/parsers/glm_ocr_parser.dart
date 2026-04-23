import 'dart:convert';

import '../exceptions/ocr_exception.dart';
import '../models/item_line.dart';
import '../models/merchant_info.dart';
import '../models/receipt_data.dart';
import '../models/summary_info.dart';
import '../models/transaction_info.dart';
import 'receipt_parser.dart';

/// Parser specifically designed for GLM-OCR layout parsing responses.
///
/// Extracts structured receipt data from GLM-OCR's markdown results and layout details.
class GLMOCRParser implements ReceiptParser {
  @override
  Future<ReceiptData> parse(
    String rawOutput, {
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Parse the GLM-OCR response - handle both markdown string and JSON formats
      String mdResults = '';

      // Try to parse as JSON first (for structured response)
      try {
        final glmResponse = jsonDecode(rawOutput) as Map<String, dynamic>;
        mdResults = glmResponse['md_results'] as String? ?? '';
      } catch (e) {
        // If JSON parsing fails, treat rawOutput as markdown text directly
        mdResults = rawOutput;
      }

      final layoutDetails = <List>[];

      // Use markdown results as the full text
      final fullText = mdResults;

      // Extract merchant info
      final merchant = _extractMerchantInfo(fullText);

      // Extract transaction info
      final transaction = _extractTransactionInfo(fullText);

      // Extract items
      final items = _extractItems(fullText);

      // Extract summary
      final summary = _extractSummary(fullText);

      // Create receipt metadata
      final receiptMetadata = ReceiptMetadata(
        rawLlmOutput: rawOutput,
        processingTimeMs: 0,
        modelUsed: 'glm-ocr',
        additionalData: {
          ...?metadata,
        },
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
      throw ParsingException('Failed to parse GLM-OCR response', e, rawOutput);
    }
  }

  /// Extract merchant info from text.
  MerchantInfo _extractMerchantInfo(String text) {
    String? merchantName;
    String? address;
    String? phone;

    final lines = text.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Try to find merchant name (look for store-like keywords or first significant line)
      if (merchantName == null && trimmed.length > 3) {
        // Skip markdown headers and common keywords
        if (!trimmed.startsWith('#') &&
            !trimmed.toLowerCase().contains('total') &&
            !trimmed.toLowerCase().contains('price') &&
            !trimmed.toLowerCase().contains('qty')) {
          merchantName = trimmed;
        }
      }

      // Look for address patterns
      if (address == null && RegExp(r'\d+.*(?:street|st|avenue|ave|road|rd|lane|ln)').hasMatch(trimmed.toLowerCase())) {
        address = trimmed;
      }

      // Look for phone number
      if (phone == null) {
        final phoneMatch = RegExp(r'\(?(\d{3})\)?[\s.-]?(\d{3})[\s.-]?(\d{4})').firstMatch(trimmed);
        if (phoneMatch != null) {
          phone = phoneMatch.group(0);
        }
      }
    }

    return MerchantInfo(
      name: merchantName ?? 'Unknown Store',
      address: address,
      phone: phone,
      confidenceScores: {
        'name': merchantName != null ? 85 : 50,
        if (address != null) 'address': 80,
        if (phone != null) 'phone': 90,
      },
    );
  }

  /// Extract transaction info from text.
  TransactionInfo _extractTransactionInfo(String text) {
    DateTime? date;
    String? time;
    String? paymentMethod;
    String? transactionId;

    // Extract date patterns
    final dateMatch = RegExp(r'(\d{4}[-/]\d{2}[-/]\d{2}|\d{2}[-/]\d{2}[-/]\d{4})').firstMatch(text);
    if (dateMatch != null) {
      final dateStr = dateMatch.group(0)!;
      date = DateTime.tryParse(dateStr.replaceAll('/', '-'));
    }

    // Extract time
    final timeMatch = RegExp(r'(\d{1,2}):(\d{2})(?::(\d{2}))?').firstMatch(text);
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
    }

    // Extract transaction ID
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
        if (date != null) 'date': 85,
        if (time != null) 'time': 80,
        if (paymentMethod != null) 'paymentMethod': 75,
        if (transactionId != null) 'transactionId': 80,
      },
    );
  }

  /// Extract items from text.
  List<ItemLine> _extractItems(String text) {
    final items = <ItemLine>[];
    final lines = text.split('\n');

    for (final line in lines) {
      if (line.isEmpty || line.startsWith('#')) continue;

      // Look for lines with price patterns (quantity x price = total)
      final priceMatches = RegExp(r'\d+(?:\.\d{2})?').allMatches(line).toList();

      // Need at least 2 numbers (usually unit price and total)
      if (priceMatches.length >= 2) {
        // Extract item name (text before numbers)
        final itemName = line
            .replaceAll(RegExp(r'\d+(?:\.\d{2})?'), '')
            .replaceAll(RegExp(r'[^\w\s]'), '')
            .trim();

        if (itemName.isNotEmpty && itemName.length > 2) {
          try {
            final quantity = 1.0; // Default quantity
            final price = double.tryParse(priceMatches.last.group(0)!) ?? 0.0;

            if (price > 0) {
              items.add(ItemLine(
                name: itemName,
                quantity: quantity,
                unitPrice: price,
                totalPrice: price,
                confidenceScores: {
                  'name': 75,
                  'quantity': 50,
                  'unitPrice': 80,
                  'totalPrice': 80,
                },
              ));
            }
          } catch (e) {
            // Skip invalid items
          }
        }
      }
    }

    return items;
  }

  /// Extract summary info from text.
  SummaryInfo _extractSummary(String text) {
    double subtotal = 0;
    double tax = 0;
    double serviceCharge = 0;
    double grandTotal = 0;

    bool foundSubtotal = false;
    bool foundTax = false;
    bool foundService = false;
    bool foundTotal = false;

    double parseNumber(String numStr) {
      String normalized = numStr.trim().replaceAll(RegExp(r'[Rp€\$£₹\s]', caseSensitive: false), '');

      if (normalized.contains(',') && normalized.contains('.')) {
        final lastCommaIdx = normalized.lastIndexOf(',');
        final lastPeriodIdx = normalized.lastIndexOf('.');
        if (lastCommaIdx > lastPeriodIdx) {
          normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
        } else {
          normalized = normalized.replaceAll(',', '');
        }
      } else if (normalized.contains(',')) {
        final parts = normalized.split(',');
        if (parts.length == 2 && parts.last.length == 2) {
          normalized = normalized.replaceAll(',', '.');
        } else {
          normalized = normalized.replaceAll(',', '');
        }
      }

      return double.tryParse(normalized) ?? 0;
    }

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

      final isExplicitTotal = lower.contains('grand total') ||
          lower.contains('total harga') ||
          lower.contains('total bayar') ||
          lower.contains('jumlah bayar') ||
          lower.contains('amount due') ||
          lower.contains('total due');
      final isGenericTotal = RegExp(r'\btotal\b').hasMatch(lower) &&
          !lower.contains('subtotal') &&
          !lower.contains('sub total');

      if (isExplicitTotal || (isGenericTotal && !foundTotal)) {
        final value = extractLastNumber(line);
        if (value != null) {
          if (isExplicitTotal || value > grandTotal) {
            grandTotal = value;
            foundTotal = true;
          }
        }
      }
    }

    // Fallback: use largest currency-tagged number if grand total not found
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

    // Calculate if needed
    if (subtotal == 0 && grandTotal > 0) {
      subtotal = grandTotal - tax - serviceCharge;
    }
    if (grandTotal == 0) {
      grandTotal = subtotal + tax + serviceCharge;
    }

    return SummaryInfo(
      subtotal: subtotal,
      tax: tax,
      serviceCharge: serviceCharge > 0 ? serviceCharge : null,
      grandTotal: grandTotal,
      confidenceScores: {
        'subtotal': foundSubtotal ? 85 : 50,
        'tax': foundTax ? 85 : 50,
        if (serviceCharge > 0) 'serviceCharge': foundService ? 80 : 40,
        'grandTotal': foundTotal ? 90 : (grandTotal > 0 ? 60 : 50),
      },
    );
  }
}
