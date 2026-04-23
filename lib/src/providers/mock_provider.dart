import 'dart:convert';

import 'base_ocr_provider.dart';

/// Mock OCR provider that returns sample receipt data for testing.
class MockProvider extends BaseOcrProvider {
  @override
  String get providerName => 'mock';

  @override
  Future<String> processImage(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 100));
    return _getSampleReceiptJson();
  }

  @override
  Future<Map<String, dynamic>> processImageStructured(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 100));
    return jsonDecode(_getSampleReceiptJson()) as Map<String, dynamic>;
  }

  /// Get sample receipt JSON for testing.
  String _getSampleReceiptJson() {
    return jsonEncode({
      'merchant': {
        'name': 'Sample Coffee Shop',
        'address': '123 Main Street, New York, NY 10001',
        'phone': '(555) 123-4567',
      },
      'transaction': {
        'date': '2024-04-23',
        'time': '14:30',
        'paymentMethod': 'credit',
        'transactionId': 'TXN-20240423-001',
      },
      'items': [
        {
          'name': 'Espresso',
          'quantity': 1,
          'unitPrice': 3.50,
          'totalPrice': 3.50,
        },
        {
          'name': 'Croissant',
          'quantity': 2,
          'unitPrice': 4.25,
          'totalPrice': 8.50,
        },
        {
          'name': 'Cappuccino',
          'quantity': 1,
          'unitPrice': 4.50,
          'totalPrice': 4.50,
        },
      ],
      'summary': {
        'subtotal': 16.50,
        'tax': 1.32,
        'serviceCharge': 0.50,
        'grandTotal': 18.32,
      },
    });
  }
}
