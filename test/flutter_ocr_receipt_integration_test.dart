import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ocr_receipt/flutter_ocr_receipt.dart';

void main() {
  group('FlutterReceiptOcr Integration Tests', () {
    late FlutterReceiptOcr ocr;

    setUp(() {
      // Use mock provider for testing (no external API calls)
      ocr = FlutterReceiptOcr.mock();
    });

    test('recognizeReceipt returns valid ReceiptData', () async {
      final imageData = List<int>.generate(100, (i) => i);

      final receipt = await ocr.recognizeReceipt(imageData);

      expect(receipt, isA<ReceiptData>());
      expect(receipt.merchant.name, isNotEmpty);
      expect(receipt.items, isNotEmpty);
      expect(receipt.summary.grandTotal, greaterThan(0));
      expect(receipt.isValid, isTrue);
    });

    test('recognizeReceipt includes processing metadata', () async {
      final imageData = List<int>.generate(100, (i) => i);

      final receipt = await ocr.recognizeReceipt(imageData);

      expect(receipt.metadata.modelUsed, equals('mock'));
      expect(receipt.metadata.processingTimeMs, greaterThanOrEqualTo(0));
      expect(receipt.metadata.rawLlmOutput, isNotEmpty);
    });

    test('recognizeReceipt with compression works', () async {
      final imageData = List<int>.generate(1000, (i) => i);

      final receipt = await ocr.recognizeReceipt(
        imageData,
        compress: true,
        maxWidth: 512,
        maxHeight: 512,
      );

      expect(receipt, isA<ReceiptData>());
      expect(receipt.isValid, isTrue);
    });

    test('recognizeMultipleReceipts processes multiple images', () async {
      final images = [
        List<int>.generate(100, (i) => i),
        List<int>.generate(100, (i) => i),
        List<int>.generate(100, (i) => i),
      ];

      final receipts = await ocr.recognizeMultipleReceipts(images, parallel: false);

      expect(receipts, isA<List<ReceiptData>>());
      expect(receipts.length, equals(3));
      for (final receipt in receipts) {
        expect(receipt.isValid, isTrue);
      }
    });

    test('recognizeMultipleReceipts with parallel processing', () async {
      final images = [
        List<int>.generate(100, (i) => i),
        List<int>.generate(100, (i) => i),
      ];

      final receipts = await ocr.recognizeMultipleReceipts(
        images,
        parallel: true,
      );

      expect(receipts.length, equals(2));
      for (final receipt in receipts) {
        expect(receipt.isValid, isTrue);
      }
    });

    test('isProviderReady returns true for mock', () async {
      final ready = await ocr.isProviderReady();

      expect(ready, isTrue);
    });

    test('overall confidence is calculated', () async {
      final imageData = List<int>.generate(100, (i) => i);

      final receipt = await ocr.recognizeReceipt(imageData);

      expect(receipt.overallConfidence, greaterThan(0));
      expect(receipt.overallConfidence, lessThanOrEqualTo(100));
    });

    test('receipt has reasonable default values from mock', () async {
      final imageData = List<int>.generate(100, (i) => i);

      final receipt = await ocr.recognizeReceipt(imageData);

      expect(receipt.merchant.name, isNotEmpty);
      expect(receipt.items.isNotEmpty, isTrue);
      expect(receipt.summary.grandTotal, greaterThan(0));
      expect(receipt.summary.tax, greaterThanOrEqualTo(0));
    });

    test('FlutterReceiptOcr.mock creates valid instance', () {
      final mockOcr = FlutterReceiptOcr.mock();

      expect(mockOcr, isA<FlutterReceiptOcr>());
      expect(mockOcr.provider, isA<MockProvider>());
    });

    test('custom provider can be passed to constructor', () {
      final customProvider = MockProvider();
      final customOcr = FlutterReceiptOcr(
        provider: customProvider,
      );

      expect(customOcr.provider, equals(customProvider));
    });
  });
}
