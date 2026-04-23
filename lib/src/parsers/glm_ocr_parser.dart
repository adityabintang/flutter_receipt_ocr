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
      // Parse the GLM-OCR response
      Map<String, dynamic> glmResponse;
      try {
        glmResponse = jsonDecode(rawOutput) as Map<String, dynamic>;
      } catch (e) {
        throw ParsingException('Failed to parse GLM-OCR JSON response', e, rawOutput);
      }

      final mdResults = glmResponse['md_results'] as String? ?? '';
      final layoutDetails = (glmResponse['layout_details'] as List?)?.cast<List>() ?? [];

      // Extract text content from layout details
      final textElements = <String>[];
      for (final layout in layoutDetails) {
        if (layout is List && layout.isNotEmpty) {
          for (final element in layout) {
            if (element is Map<String, dynamic>) {
              final label = element['label'] as String? ?? '';
              final content = element['content'] as String? ?? '';

              if (label == 'text' && content.isNotEmpty) {
                textElements.add(content);
              }
            }
          }
        }
      }

      // Combine markdown results and extracted text
      final fullText = '$mdResults\n${textElements.join('\n')}';

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
          'glm_response_id': glmResponse['id'],
          'num_pages': glmResponse['data_info']?['num_pages'],
          'usage': glmResponse['usage'],
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

    // Extract subtotal
    final subtotalMatch = RegExp(
      r'(?:subtotal|sub[\s-]?total|total before)[:\s]+\$?(\d+(?:\.\d{2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (subtotalMatch != null) {
      subtotal = double.tryParse(subtotalMatch.group(1)!) ?? 0;
    }

    // Extract tax
    final taxMatch = RegExp(
      r'(?:tax|sales[\s-]?tax)[:\s]+\$?(\d+(?:\.\d{2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (taxMatch != null) {
      tax = double.tryParse(taxMatch.group(1)!) ?? 0;
    }

    // Extract service charge
    final serviceMatch = RegExp(
      r'(?:service[\s-]?charge|tip|gratuity)[:\s]+\$?(\d+(?:\.\d{2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (serviceMatch != null) {
      serviceCharge = double.tryParse(serviceMatch.group(1)!) ?? 0;
    }

    // Extract grand total
    final totalMatches = RegExp(
      r'(?:grand[\s-]?total|total|amount[\s-]?due)[:\s]+\$?(\d+(?:\.\d{2})?)',
      caseSensitive: false,
    ).allMatches(text);
    if (totalMatches.isNotEmpty) {
      grandTotal = double.tryParse(totalMatches.last.group(1)!) ?? 0;
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
        'subtotal': subtotalMatch != null ? 85 : 50,
        'tax': taxMatch != null ? 85 : 50,
        if (serviceCharge > 0) 'serviceCharge': serviceMatch != null ? 80 : 40,
        'grandTotal': totalMatches.isNotEmpty ? 90 : 50,
      },
    );
  }
}
