import '../flutter_ocr_receipt_platform_interface.dart';
import 'exceptions/ocr_exception.dart';
import 'models/receipt_data.dart';
import 'parsers/freeform_parser.dart';
import 'parsers/receipt_parser.dart';
import 'parsers/structured_parser.dart';
import 'processors/image_processor.dart';
import 'processors/image_processor_impl.dart';
import 'providers/base_ocr_provider.dart';
import 'providers/mock_provider.dart';

/// Main entry point for the Flutter Receipt OCR package.
///
/// Orchestrates the complete OCR pipeline: image processing, LLM inference, and parsing.
class FlutterReceiptOcr {
  /// The OCR provider to use (GLM, Qwen, Mock, etc.).
  final BaseOcrProvider provider;

  /// The image processor for optimization.
  final ImageProcessor imageProcessor;

  /// The receipt parser for normalizing LLM output.
  final ReceiptParser parser;

  /// Optional fallback parser for error handling.
  final ReceiptParser? fallbackParser;

  /// Create a FlutterReceiptOcr instance.
  ///
  /// [provider] - The OCR provider to use
  /// [imageProcessor] - Optional custom image processor (defaults to ImageProcessorImpl)
  /// [parser] - Optional custom parser (defaults to StructuredParser)
  /// [fallbackParser] - Optional fallback parser (defaults to FreeformParser)
  FlutterReceiptOcr({
    required this.provider,
    ImageProcessor? imageProcessor,
    ReceiptParser? parser,
    ReceiptParser? fallbackParser,
  })  : imageProcessor = imageProcessor ?? ImageProcessorImpl(),
        parser = parser ?? StructuredParser(),
        fallbackParser = fallbackParser ?? FreeformParser();

  /// Create a FlutterReceiptOcr instance with mock provider for testing.
  factory FlutterReceiptOcr.mock({
    ImageProcessor? imageProcessor,
    ReceiptParser? parser,
  }) {
    return FlutterReceiptOcr(
      provider: MockProvider(),
      imageProcessor: imageProcessor,
      parser: parser,
    );
  }

  /// Recognize and extract data from a single receipt image.
  ///
  /// [imageData] - Raw image bytes (JPG, PNG, etc.)
  /// [compress] - Whether to compress the image before processing (default: true)
  /// [maxWidth] - Maximum width for compression (optional)
  /// [maxHeight] - Maximum height for compression (optional)
  /// Returns ReceiptData with extracted information and confidence scores.
  Future<ReceiptData> recognizeReceipt(
    List<int> imageData, {
    bool compress = true,
    int? maxWidth,
    int? maxHeight,
  }) async {
    final startTime = DateTime.now();

    try {
      // Step 1: Preprocess image
      List<int> processedImage = imageData;
      if (compress) {
        try {
          processedImage = await imageProcessor.compress(
            imageData,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            quality: 85,
          );
        } catch (e) {
          // Log warning but continue with original image
          print('Warning: Image compression failed, using original: $e');
        }
      }

      // Step 2: Call OCR provider
      final rawOutput = await provider.processImage(processedImage);

      // Step 3: Parse output
      ReceiptData receipt;
      try {
        receipt = await parser.parse(
          rawOutput,
          metadata: {
            'modelUsed': provider.providerName,
            'imageSize': processedImage.length,
            'compressed': compress,
          },
        );
      } on ParsingException catch (e) {
        // Try fallback parser if primary parser fails
        if (fallbackParser != null) {
          print('Warning: Primary parser failed, trying fallback parser: $e');
          receipt = await fallbackParser!.parse(
            rawOutput,
            metadata: {
              'modelUsed': provider.providerName,
              'parserUsed': 'fallback',
              'imageSize': processedImage.length,
              'compressed': compress,
            },
          );
        } else {
          rethrow;
        }
      }

      // Step 4: Update processing time
      final processingTimeMs = DateTime.now().difference(startTime).inMilliseconds;
      receipt.metadata.processingTimeMs = processingTimeMs;

      return receipt;
    } catch (e) {
      if (e is OcrException) {
        rethrow;
      }
      throw InferenceException('Receipt recognition failed', e);
    }
  }

  /// Recognize and extract data from multiple receipt images.
  ///
  /// [images] - List of raw image bytes
  /// [compress] - Whether to compress images before processing (default: true)
  /// [parallel] - Whether to process images in parallel (default: false)
  /// Returns list of ReceiptData objects.
  Future<List<ReceiptData>> recognizeMultipleReceipts(
    List<List<int>> images, {
    bool compress = true,
    bool parallel = false,
  }) async {
    if (parallel) {
      // Process in parallel
      final futures = images.map(
        (image) => recognizeReceipt(image, compress: compress),
      );
      return Future.wait(futures);
    } else {
      // Process sequentially
      final results = <ReceiptData>[];
      for (final image in images) {
        final receipt = await recognizeReceipt(image, compress: compress);
        results.add(receipt);
      }
      return results;
    }
  }

  /// Check if the provider is ready and has valid configuration.
  Future<bool> isProviderReady() async {
    try {
      // Try a simple health check (can be expanded per provider)
      return provider.providerName.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the platform version (backward compatibility method).
  ///
  /// This method is maintained for backward compatibility with the original plugin interface.
  /// In a real application, you would use the receipt OCR methods instead.
  Future<String?> getPlatformVersion() async {
    return FlutterReceiptOcrPlatform.instance.getPlatformVersion();
  }
}
