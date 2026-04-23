import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ocr_receipt/flutter_ocr_receipt.dart';

void main() {
  group('StructuredParser', () {
    late StructuredParser parser;

    setUp(() {
      parser = StructuredParser();
    });

    test('parses valid JSON receipt', () async {
      final jsonData = {
        'merchant': {
          'name': 'Test Store',
          'address': '123 Main St',
          'phone': '555-1234',
        },
        'transaction': {
          'date': '2024-04-23',
          'time': '14:30',
          'paymentMethod': 'credit',
        },
        'items': [
          {
            'name': 'Item 1',
            'quantity': 1,
            'unitPrice': 10.0,
            'totalPrice': 10.0,
          },
        ],
        'summary': {
          'subtotal': 10.0,
          'tax': 1.0,
          'serviceCharge': 0.5,
          'grandTotal': 11.5,
        },
      };

      final jsonString = jsonEncode(jsonData);
      final receipt = await parser.parse(jsonString);

      expect(receipt.merchant.name, equals('Test Store'));
      expect(receipt.items.length, equals(1));
      expect(receipt.summary.grandTotal, equals(11.5));
      expect(receipt.isValid, isTrue);
    });

    test('parses JSON with extra surrounding text', () async {
      final jsonData = {
        'merchant': {'name': 'Test Store'},
        'transaction': {},
        'items': [
          {'name': 'Item', 'quantity': 1, 'unitPrice': 10.0, 'totalPrice': 10.0},
        ],
        'summary': {
          'subtotal': 10.0,
          'tax': 1.0,
          'grandTotal': 11.0,
        },
      };

      final jsonString = 'Some text before ${jsonEncode(jsonData)} and after';
      final receipt = await parser.parse(jsonString);

      expect(receipt.merchant.name, equals('Test Store'));
      expect(receipt.isValid, isTrue);
    });

    test('throws ParsingException for invalid JSON', () async {
      const invalidJson = 'This is not JSON at all';

      expect(
        () => parser.parse(invalidJson),
        throwsA(isA<ParsingException>()),
      );
    });

    test('handles missing optional fields', () async {
      final jsonData = {
        'merchant': {'name': 'Store'},
        'transaction': {},
        'items': [
          {'name': 'Item', 'quantity': 1, 'unitPrice': 10.0, 'totalPrice': 10.0},
        ],
        'summary': {
          'subtotal': 10.0,
          'tax': 0.0,
          'grandTotal': 10.0,
        },
      };

      final receipt = await parser.parse(jsonEncode(jsonData));

      expect(receipt.merchant.address, isNull);
      expect(receipt.transaction.date, isNull);
      expect(receipt.summary.serviceCharge, isNull);
    });

    test('calculates confidence scores', () async {
      final jsonData = {
        'merchant': {'name': 'Store'},
        'transaction': {'date': '2024-04-23'},
        'items': [
          {'name': 'Item', 'quantity': 1, 'unitPrice': 10.0, 'totalPrice': 10.0},
        ],
        'summary': {
          'subtotal': 10.0,
          'tax': 0.0,
          'grandTotal': 10.0,
        },
      };

      final receipt = await parser.parse(jsonEncode(jsonData));

      expect(receipt.merchant.confidenceScores['name'], greaterThan(0));
      expect(receipt.overallConfidence, greaterThan(0));
      expect(receipt.overallConfidence, lessThanOrEqualTo(100));
    });

    test('validates receipt after parsing', () async {
      final jsonData = {
        'merchant': {'name': ''}, // Empty merchant name
        'transaction': {},
        'items': [
          {'name': 'Item', 'quantity': 1, 'unitPrice': 10.0, 'totalPrice': 10.0},
        ],
        'summary': {
          'subtotal': 10.0,
          'tax': 0.0,
          'grandTotal': 10.0,
        },
      };

      expect(
        () => parser.parse(jsonEncode(jsonData)),
        throwsA(isA<ParsingException>()),
      );
    });

    test('handles numeric string values', () async {
      final jsonData = {
        'merchant': {'name': 'Store'},
        'transaction': {},
        'items': [
          {
            'name': 'Item',
            'quantity': '1',
            'unitPrice': '10.0',
            'totalPrice': '10.0',
          },
        ],
        'summary': {
          'subtotal': '10.0',
          'tax': '0.0',
          'grandTotal': '10.0',
        },
      };

      final receipt = await parser.parse(jsonEncode(jsonData));

      expect(receipt.items.first.quantity, equals(1.0));
      expect(receipt.summary.subtotal, equals(10.0));
    });
  });
}
