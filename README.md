# Flutter Receipt OCR

A high-level Flutter package for extracting structured data from receipt images using multiple LLM providers (GLM, Qwen, etc.). The package abstracts away complexity of image optimization, LLM integration, and output parsing.

## Features

- 🎯 **Multi-Provider Support** - Seamlessly switch between GLM, Qwen, and custom providers
- 🖼️ **Automatic Image Optimization** - Compress, resize, and convert images without manual intervention
- 🧠 **Intelligent Parsing** - Structured and freeform parsers with automatic fallback
- 📊 **Confidence Scoring** - Per-field confidence scores (0-100%) for data validation
- ✅ **Type Safety** - Fully typed Dart models with validation
- 🧪 **Well Tested** - Comprehensive unit and integration tests
- 📱 **Easy Integration** - Simple API with sensible defaults

## Supported Data Fields

### Merchant Information
- Store/merchant name
- Address
- Phone number

### Transaction Details
- Date and time
- Payment method (cash, credit, debit, mobile)
- Transaction/receipt ID

### Items
- Item name/description
- Quantity
- Unit price
- Total price per item

### Summary
- Subtotal
- Tax amount
- Service charge
- Grand total

## Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  flutter_ocr_receipt: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Quick Start

### Using Mock Provider (for testing)

```dart
import 'package:flutter_ocr_receipt/flutter_ocr_receipt.dart';

// Create OCR instance with mock provider (no API key needed)
final ocr = FlutterReceiptOcr.mock();

// Recognize a receipt from image bytes
List<int> imageBytes = await readImageFile();
ReceiptData receipt = await ocr.recognizeReceipt(imageBytes);

// Access extracted data
print('Store: ${receipt.merchant.name}');
print('Total: ${receipt.summary.grandTotal}');
print('Confidence: ${receipt.overallConfidence}%');
```

### Using GLM Provider

```dart
// Create OCR instance with GLM provider
final ocr = FlutterReceiptOcr(
  provider: GLMProvider(apiKey: 'your-api-key'),
);

// Use same API as above
ReceiptData receipt = await ocr.recognizeReceipt(imageBytes);
```

### Using Qwen Provider

```dart
// Create OCR instance with Qwen provider
final ocr = FlutterReceiptOcr(
  provider: QwenProvider(apiKey: 'your-api-key'),
);

// Use same API as above
ReceiptData receipt = await ocr.recognizeReceipt(imageBytes);
```

## API Reference

### FlutterReceiptOcr

Main entry point for the OCR pipeline.

#### Constructor

```dart
FlutterReceiptOcr({
  required BaseOcrProvider provider,
  ImageProcessor? imageProcessor,  // defaults to ImageProcessorImpl
  ReceiptParser? parser,           // defaults to StructuredParser
  ReceiptParser? fallbackParser,   // defaults to FreeformParser
})
```

#### Methods

##### `recognizeReceipt(imageData, {compress, maxWidth, maxHeight})`

Recognize and extract data from a single receipt image.

**Parameters:**
- `imageData` (List<int>) - Raw image bytes (JPG, PNG, etc.)
- `compress` (bool) - Whether to compress image before processing (default: true)
- `maxWidth` (int?) - Maximum width for compression (optional)
- `maxHeight` (int?) - Maximum height for compression (optional)

**Returns:** `Future<ReceiptData>` - Extracted receipt data with confidence scores

**Example:**
```dart
final imageBytes = await File('receipt.jpg').readAsBytes();
final receipt = await ocr.recognizeReceipt(
  imageBytes,
  compress: true,
  maxWidth: 1024,
  maxHeight: 1024,
);
```

##### `recognizeMultipleReceipts(images, {compress, parallel})`

Process multiple receipt images.

**Parameters:**
- `images` (List<List<int>>) - List of image byte arrays
- `compress` (bool) - Whether to compress images (default: true)
- `parallel` (bool) - Process in parallel (default: false)

**Returns:** `Future<List<ReceiptData>>` - List of extracted receipts

**Example:**
```dart
final receipts = await ocr.recognizeMultipleReceipts(
  [imageBytes1, imageBytes2, imageBytes3],
  parallel: true,
);
```

### ReceiptData Model

Complete structured data extracted from a receipt.

```dart
class ReceiptData {
  MerchantInfo merchant;        // Store information
  TransactionInfo transaction;  // Payment details
  List<ItemLine> items;         // Receipt line items
  SummaryInfo summary;          // Total information
  ReceiptMetadata metadata;     // Processing metadata
  
  int get overallConfidence;    // Weighted confidence (0-100)
  bool get isValid;             // Validation status
  List<String> get validationErrors;
  
  Map<String, dynamic> toJson();
  factory ReceiptData.fromJson(Map<String, dynamic> json);
}
```

### Confidence Scoring

Each field includes a confidence score (0-100%) indicating extraction reliability:

```dart
final score = receipt.merchant.confidenceScores['name'];  // e.g., 95
if (score < 80) {
  // Consider manual verification
}
```

**Overall Confidence** (weighted average):
- Merchant name: 15%
- Items: 40%
- Grand total: 25%
- Transaction date: 10%
- Payment method: 10%

## Error Handling

The package provides custom exceptions for different failure scenarios:

```dart
import 'package:flutter_ocr_receipt/flutter_ocr_receipt.dart';

try {
  final receipt = await ocr.recognizeReceipt(imageBytes);
} on ImageProcessingException catch (e) {
  print('Image processing failed: ${e.message}');
} on InferenceException catch (e) {
  print('LLM API error: ${e.message} (HTTP ${e.statusCode})');
} on ParsingException catch (e) {
  print('Parsing failed: ${e.message}');
} on OcrException catch (e) {
  print('OCR error: ${e.message}');
}
```

## Custom Providers

Implement your own LLM provider by extending `BaseOcrProvider`:

```dart
class MyCustomProvider extends BaseOcrProvider {
  @override
  String get providerName => 'my_provider';

  @override
  Future<String> processImage(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    // Your LLM integration logic
    // Return raw LLM response
  }

  @override
  Future<Map<String, dynamic>> processImageStructured(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    // Return parsed JSON as Map
  }
}

// Use custom provider
final ocr = FlutterReceiptOcr(
  provider: MyCustomProvider(),
);
```

## Custom Parsers

Implement custom parsing logic by extending `ReceiptParser`:

```dart
class MyParser implements ReceiptParser {
  @override
  Future<ReceiptData> parse(
    String rawOutput, {
    Map<String, dynamic>? metadata,
  }) async {
    // Your custom parsing logic
    // Return ReceiptData
  }
}

// Use custom parser
final ocr = FlutterReceiptOcr(
  provider: GLMProvider(apiKey: 'key'),
  parser: MyParser(),
);
```

## Example App

A complete example app is included demonstrating:
- Image selection (camera/gallery)
- Receipt OCR processing
- Formatted results display
- Confidence visualization

Run the example:

```bash
cd example
flutter run
```

## Testing

Run unit and integration tests:

```bash
flutter test
```

Test coverage:

```bash
flutter test --coverage
```

## Architecture

The package follows a modular, layered architecture:

1. **ImageProcessor** - Optimizes images for LLM processing
2. **OCR Providers** - Interface with LLM APIs
3. **Parser** - Normalizes LLM output to structured data
4. **Orchestrator** - Coordinates the complete pipeline

See [IMPLEMENTATION.md](IMPLEMENTATION.md) for detailed architectural documentation.

## Performance

Typical processing times (excluding LLM inference):
- Image compression: <1 second
- Parsing: <500ms
- Total with LLM: 2-10 seconds (depending on provider and network)

## Accuracy

The package targets **90%+ accuracy** through:
- Optimized prompting strategies
- Structured JSON output from LLMs
- Confidence scoring and validation
- Fallback parsing for robustness

## Limitations

- LLM quality depends on image quality and receipt format
- Complex receipts may have lower accuracy
- Requires valid API keys for GLM and Qwen providers
- Mock provider only returns sample data for testing

## Contributing

Contributions are welcome! Please feel free to submit pull requests.

## License

This project is licensed under the MIT License - see LICENSE file for details.

## Support

For issues, feature requests, or questions:
1. Check the [example app](example/lib/main.dart)
2. Review test files in `test/`
3. File an issue on GitHub
