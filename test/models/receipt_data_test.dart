import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ocr_receipt/flutter_ocr_receipt.dart';

void main() {
  group('ReceiptData', () {
    test('creates valid ReceiptData with all required fields', () {
      final merchant = MerchantInfo(
        name: 'Test Store',
        address: '123 Main St',
        phone: '555-1234',
      );
      final transaction = TransactionInfo(
        date: DateTime.now(),
        paymentMethod: 'credit',
      );
      final items = [
        ItemLine(
          name: 'Item 1',
          quantity: 1,
          unitPrice: 10.0,
          totalPrice: 10.0,
        ),
      ];
      final summary = SummaryInfo(
        subtotal: 10.0,
        tax: 1.0,
        grandTotal: 11.0,
      );
      final metadata = ReceiptMetadata(
        rawLlmOutput: '{}',
        processingTimeMs: 100,
        modelUsed: 'test',
      );

      final receipt = ReceiptData(
        merchant: merchant,
        transaction: transaction,
        items: items,
        summary: summary,
        metadata: metadata,
      );

      expect(receipt.merchant.name, equals('Test Store'));
      expect(receipt.items.length, equals(1));
      expect(receipt.isValid, isTrue);
    });

    test('overall confidence is calculated correctly', () {
      final merchant = MerchantInfo(
        name: 'Store',
        confidenceScores: {'name': 100},
      );
      final transaction = TransactionInfo(
        confidenceScores: {},
      );
      final items = [
        ItemLine(
          name: 'Item',
          quantity: 1,
          unitPrice: 10.0,
          totalPrice: 10.0,
          confidenceScores: {
            'name': 100,
            'quantity': 100,
            'unitPrice': 100,
            'totalPrice': 100,
          },
        ),
      ];
      final summary = SummaryInfo(
        subtotal: 10.0,
        tax: 0.0,
        grandTotal: 10.0,
        confidenceScores: {
          'subtotal': 100,
          'tax': 100,
          'grandTotal': 100,
        },
      );
      final metadata = ReceiptMetadata(
        rawLlmOutput: '{}',
        processingTimeMs: 100,
        modelUsed: 'test',
      );

      final receipt = ReceiptData(
        merchant: merchant,
        transaction: transaction,
        items: items,
        summary: summary,
        metadata: metadata,
      );

      // With all 100% confidence, overall should be high
      expect(receipt.overallConfidence, greaterThanOrEqualTo(90));
    });

    test('toJson and fromJson round-trip works', () {
      final merchant = MerchantInfo(
        name: 'Test Store',
        address: '123 Main St',
      );
      final transaction = TransactionInfo(
        date: DateTime(2024, 4, 23),
      );
      final items = [
        ItemLine(
          name: 'Item 1',
          quantity: 1,
          unitPrice: 10.0,
          totalPrice: 10.0,
        ),
      ];
      final summary = SummaryInfo(
        subtotal: 10.0,
        tax: 1.0,
        grandTotal: 11.0,
      );
      final metadata = ReceiptMetadata(
        rawLlmOutput: 'raw',
        processingTimeMs: 100,
        modelUsed: 'test',
      );

      final receipt = ReceiptData(
        merchant: merchant,
        transaction: transaction,
        items: items,
        summary: summary,
        metadata: metadata,
      );

      final json = receipt.toJson();
      final restored = ReceiptData.fromJson(json);

      expect(restored.merchant.name, equals(receipt.merchant.name));
      expect(restored.items.length, equals(receipt.items.length));
      expect(restored.summary.grandTotal, equals(receipt.summary.grandTotal));
    });

    test('validation fails for missing merchant name', () {
      final merchant = MerchantInfo(name: '');
      final transaction = TransactionInfo();
      final items = [
        ItemLine(
          name: 'Item',
          quantity: 1,
          unitPrice: 10.0,
          totalPrice: 10.0,
        ),
      ];
      final summary = SummaryInfo(
        subtotal: 10.0,
        tax: 0.0,
        grandTotal: 10.0,
      );
      final metadata = ReceiptMetadata(
        rawLlmOutput: '{}',
        processingTimeMs: 100,
        modelUsed: 'test',
      );

      final receipt = ReceiptData(
        merchant: merchant,
        transaction: transaction,
        items: items,
        summary: summary,
        metadata: metadata,
      );

      expect(receipt.isValid, isFalse);
      expect(receipt.validationErrors.isNotEmpty, isTrue);
    });
  });

  group('MerchantInfo', () {
    test('average confidence is calculated correctly', () {
      final merchant = MerchantInfo(
        name: 'Store',
        confidenceScores: {'name': 100, 'address': 80},
      );

      expect(merchant.averageConfidence, equals(90));
    });

    test('toJson and fromJson round-trip works', () {
      final merchant = MerchantInfo(
        name: 'Test Store',
        address: '123 Main St',
        phone: '555-1234',
        confidenceScores: {'name': 95, 'address': 85, 'phone': 80},
      );

      final json = merchant.toJson();
      final restored = MerchantInfo.fromJson(json);

      expect(restored.name, equals(merchant.name));
      expect(restored.address, equals(merchant.address));
      expect(restored.phone, equals(merchant.phone));
      expect(restored.confidenceScores, equals(merchant.confidenceScores));
    });
  });

  group('ItemLine', () {
    test('price consistency check works', () {
      final item = ItemLine(
        name: 'Item',
        quantity: 2,
        unitPrice: 5.0,
        totalPrice: 10.0,
      );

      expect(item.isPriceConsistent, isTrue);
    });

    test('price inconsistency is detected', () {
      final item = ItemLine(
        name: 'Item',
        quantity: 2,
        unitPrice: 5.0,
        totalPrice: 15.0, // Wrong total
      );

      expect(item.isPriceConsistent, isFalse);
    });
  });

  group('SummaryInfo', () {
    test('total consistency check works', () {
      final summary = SummaryInfo(
        subtotal: 10.0,
        tax: 1.0,
        serviceCharge: 0.5,
        grandTotal: 11.5,
      );

      expect(summary.isTotalConsistent, isTrue);
    });

    test('total inconsistency is detected', () {
      final summary = SummaryInfo(
        subtotal: 10.0,
        tax: 1.0,
        serviceCharge: 0.5,
        grandTotal: 12.0, // Wrong total
      );

      expect(summary.isTotalConsistent, isFalse);
    });
  });
}
