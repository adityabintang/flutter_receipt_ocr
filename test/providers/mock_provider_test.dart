import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ocr_receipt/flutter_ocr_receipt.dart';

void main() {
  group('MockProvider', () {
    late MockProvider provider;

    setUp(() {
      provider = MockProvider();
    });

    test('provider name is mock', () {
      expect(provider.providerName, equals('mock'));
    });

    test('processImage returns valid JSON string', () async {
      final imageData = List<int>.generate(100, (i) => i);

      final result = await provider.processImage(imageData);

      expect(result, isNotEmpty);
      expect(result.contains('merchant'), isTrue);
      expect(result.contains('items'), isTrue);
    });

    test('processImageStructured returns Map', () async {
      final imageData = List<int>.generate(100, (i) => i);

      final result = await provider.processImageStructured(imageData);

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('merchant'), isTrue);
      expect(result.containsKey('items'), isTrue);
      expect(result.containsKey('summary'), isTrue);
    });

    test('sample data has valid structure', () async {
      final imageData = List<int>.generate(100, (i) => i);

      final result = await provider.processImageStructured(imageData);

      expect(result['merchant'], isA<Map>());
      expect(result['merchant']['name'], isA<String>());
      expect(result['items'], isA<List>());
      expect(result['summary'], isA<Map>());
      expect(result['summary']['grandTotal'], isA<num>());
    });

    test('custom prompts are accepted', () async {
      final imageData = List<int>.generate(100, (i) => i);

      final result = await provider.processImage(
        imageData,
        systemPrompt: 'Custom system prompt',
        userPrompt: 'Custom user prompt',
      );

      // Mock ignores custom prompts but should not error
      expect(result, isNotEmpty);
    });
  });
}
