# Flutter Receipt OCR - Implementation Guide

## Architecture Overview

The Flutter Receipt OCR package follows a clean, modular architecture with clear separation of concerns:

```
User Application
    ↓
┌─────────────────────────────────┐
│  FlutterReceiptOcr (Orchestrator)│  - Main public API
│  - recognizeReceipt()            │  - Coordinates pipeline
│  - recognizeMultipleReceipts()   │
└─────────────────┬───────────────┘
                  ↓
    ┌─────────────┴──────────────────┐
    ↓                                 ↓
┌──────────────────┐      ┌─────────────────────┐
│  ImageProcessor  │      │  BaseOcrProvider    │  - Abstract interface
│  - Compress      │      │  - processImage()   │  - Implemented by:
│  - Resize        │      │  - processStructured│    * GLMProvider
│  - Convert       │      └─────────────────────┘    * QwenProvider
└──────────────────┘              ↓                   * MockProvider
                          ┌────────────────┐
                          │  LLM API       │
                          │ (Alibaba GLM,  │
                          │  Alibaba Qwen) │
                          └────────────────┘
    ↓
┌──────────────────────┐
│  ReceiptParser       │  - Abstract interface
│  - parse()           │  - Implemented by:
└──────────────────────┘    * StructuredParser
    ↓                        * FreeformParser
┌──────────────────────┐
│  ReceiptData Model   │
│  - MerchantInfo      │
│  - TransactionInfo   │
│  - ItemLine[]        │
│  - SummaryInfo       │
│  - ReceiptMetadata   │
└──────────────────────┘
    ↓
User Application
```

## Core Components

### 1. FlutterReceiptOcr (Orchestrator)

**Location:** `lib/src/flutter_receipt_ocr.dart`

The main entry point that coordinates the complete OCR pipeline:

1. **Image Preprocessing** - Compresses/optimizes image
2. **LLM Inference** - Sends to provider API
3. **Output Parsing** - Normalizes response
4. **Error Handling** - Fallback strategies

**Key Methods:**
- `recognizeReceipt()` - Single receipt processing
- `recognizeMultipleReceipts()` - Batch processing with optional parallelization
- `isProviderReady()` - Provider health check

**Design Pattern:** Orchestrator/Facade pattern

### 2. ImageProcessor

**Location:** `lib/src/processors/`

Handles all image manipulation operations:

**Interface:**
- `compress()` - Reduce file size while maintaining quality
- `resize()` - Adjust dimensions
- `convertToWebP()` - Format conversion
- `analyzeImage()` - Get image properties

**Implementation:** Uses the `image` package for pure Dart processing

**Design Pattern:** Strategy pattern (Interface-based)

### 3. OCR Providers (BaseOcrProvider)

**Location:** `lib/src/providers/`

**Base Class:** `BaseOcrProvider`
- `processImage()` - Returns raw LLM response
- `processImageStructured()` - Returns parsed JSON Map
- `getDefaultSystemPrompt()` - Default OCR instructions
- `getDefaultUserPrompt()` - Default data extraction prompt

**Implementations:**

#### MockProvider
- For testing without external API calls
- Returns hardcoded sample receipt data
- Useful in CI/CD and offline development

#### GLMProvider
- Integrates with Alibaba GLM API
- Base64 encodes image
- Sends JSON request to GLM endpoint
- Handles rate limiting and timeouts

#### QwenProvider
- Integrates with Alibaba Qwen (Qwen-VL) API
- Similar to GLMProvider but for Qwen endpoint
- Vision model optimized for image understanding

**Design Pattern:** Strategy pattern (pluggable providers)

### 4. Receipt Parser

**Location:** `lib/src/parsers/`

**Base Interface:** `ReceiptParser`
- `parse(rawOutput, metadata)` - Parse LLM output to ReceiptData

**Implementations:**

#### StructuredParser
- Assumes LLM returns valid JSON
- Validates against expected schema
- Calculates per-field confidence scores
- Throws `ParsingException` if validation fails

**Confidence Scoring Logic:**
```
field_confidence = base_confidence - (uncertainty_penalty * variants)

Default base scores:
- Merchant name: 95%
- Address: 80%
- Phone: 80%
- Date: 90%
- Items: 90%
- Prices: 95%
- Total: 95%

Penalties applied for:
- Missing values (0%)
- Unusual characters (-20%)
- Very short values (-40%)
```

#### FreeformParser
- Regex-based parsing for unstructured text
- Pattern matching for:
  - Merchant (store/restaurant keywords)
  - Dates (YYYY-MM-DD, MM/DD/YYYY formats)
  - Times (HH:MM format)
  - Items (lines with price patterns)
  - Totals (keywords: subtotal, tax, total)
- Lower confidence scores (50-75%) due to ambiguity
- Graceful fallback when structured parsing fails

**Design Pattern:** Strategy pattern (pluggable parsers)

### 5. Data Models

**Location:** `lib/src/models/`

#### ReceiptData (Main Model)
- Aggregates all extracted information
- Contains metadata about extraction
- Provides `overallConfidence` (weighted average)
- Validation with error messages

**Weighted Confidence Formula:**
```
overall = merchant.name(0.15) + items(0.40) + 
          summary.total(0.25) + date(0.10) + paymentMethod(0.10)
```

#### Sub-Models
- **MerchantInfo** - Store details
- **TransactionInfo** - Payment details
- **ItemLine** - Individual receipt item
- **SummaryInfo** - Financial summary
- **ReceiptMetadata** - Processing metadata

**Design Pattern:** Composite pattern (nested objects)

### 6. Exception Hierarchy

**Location:** `lib/src/exceptions/ocr_exception.dart`

```
OcrException (base)
├── ImageProcessingException - Image manipulation failures
├── InferenceException - LLM API errors (includes HTTP status)
└── ParsingException - Output parsing failures (includes unparsed data)
```

**Usage:** Allows targeted error handling at application level

## Data Flow

### Complete Pipeline

1. **User Input**
   ```dart
   List<int> imageBytes = await getImage();
   ReceiptData receipt = await ocr.recognizeReceipt(imageBytes);
   ```

2. **Image Processing**
   ```dart
   // ImageProcessor compresses if needed
   List<int> optimizedImage = await imageProcessor.compress(
     imageBytes,
     maxWidth: 1024,
     maxHeight: 1024,
     quality: 85
   );
   ```

3. **LLM Inference**
   ```dart
   // Provider sends to LLM API
   String rawResponse = await provider.processImage(optimizedImage);
   // Response: JSON string with receipt data
   ```

4. **Parsing**
   ```dart
   // Parser normalizes response
   ReceiptData receipt = await parser.parse(
     rawResponse,
     metadata: {'modelUsed': 'glm', 'imageSize': size}
   );
   ```

5. **Validation**
   ```dart
   // ReceiptData validates extracted data
   assert(receipt.isValid);
   assert(receipt.merchant.name.isNotEmpty);
   assert(receipt.items.isNotEmpty);
   ```

6. **Confidence Assessment**
   ```dart
   // Each field has confidence score
   print(receipt.merchant.confidenceScores['name']); // e.g., 95
   print(receipt.overallConfidence);                 // e.g., 87
   ```

## Design Patterns Used

### 1. **Facade Pattern** (Orchestrator)
- `FlutterReceiptOcr` simplifies complex pipeline
- Hides details of image processing, LLM APIs, parsing
- Provides single entry point

### 2. **Strategy Pattern** (Providers & Parsers)
- `BaseOcrProvider` - Pluggable LLM providers
- `ReceiptParser` - Pluggable parsers
- Easy to add new implementations

### 3. **Composite Pattern** (Data Models)
- `ReceiptData` contains nested sub-models
- Type-safe hierarchical structure
- Recursive validation

### 4. **Template Method** (Error Handling)
- Exception hierarchy defines error handling flow
- Specific exceptions for different failure types

### 5. **Factory Pattern** (Instantiation)
- `FlutterReceiptOcr.mock()` factory method
- Convenient creation of test instances

## Error Handling & Resilience

### Fallback Strategy

```dart
try {
  // Primary parsing (structured)
  receipt = await parser.parse(rawOutput);
} catch (e) {
  if (fallbackParser != null) {
    // Fallback to freeform parsing
    receipt = await fallbackParser.parse(rawOutput);
  } else {
    rethrow;
  }
}
```

### Graceful Degradation

- Image compression failures don't stop OCR (original used)
- Parsing failures trigger fallback parser
- Missing optional fields don't invalidate receipt
- Confidence scores allow application-level decisions

## Testing Strategy

### Unit Tests
- Model serialization (`test/models/receipt_data_test.dart`)
- Provider functionality (`test/providers/mock_provider_test.dart`)
- Parser logic (`test/parsers/structured_parser_test.dart`)
- Exception handling

### Integration Tests
- End-to-end pipeline (`test/flutter_ocr_receipt_integration_test.dart`)
- Multiple providers
- Batch processing
- Error scenarios

### Test Fixtures
- Sample receipt images
- Sample LLM JSON responses
- Expected ReceiptData objects

## Performance Considerations

### Image Processing
- Compression reduces LLM input by 50-80%
- Reduces API costs and latency
- Target: <1 second for typical receipt image

### Parsing
- Structured parser: <500ms for typical JSON
- Freeform parser: <1 second with regex matching
- Confidence calculations: O(n) where n = number of fields

### Batch Processing
- Parallel flag allows concurrent processing
- Useful for processing multiple receipts
- Respects LLM API rate limits

## Extension Points

### 1. Custom Providers
```dart
class MyProvider extends BaseOcrProvider {
  @override
  String get providerName => 'my_provider';
  
  @override
  Future<String> processImage(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    // Your implementation
  }
}
```

### 2. Custom Parsers
```dart
class MyParser implements ReceiptParser {
  @override
  Future<ReceiptData> parse(
    String rawOutput, {
    Map<String, dynamic>? metadata,
  }) async {
    // Your implementation
  }
}
```

### 3. Custom Image Processors
```dart
class MyImageProcessor implements ImageProcessor {
  // Override methods for custom processing
}
```

## Deployment Checklist

- [ ] All unit tests pass (`flutter test`)
- [ ] Code coverage >80% (`flutter test --coverage`)
- [ ] No lint warnings (`flutter analyze`)
- [ ] Example app runs on iOS and Android
- [ ] API keys configured for GLM/Qwen
- [ ] Documentation updated
- [ ] Changelog updated
- [ ] Version bumped in pubspec.yaml
- [ ] Package published to pub.dev

## Future Enhancements

1. **Native Image Processing**
   - Platform-specific image optimization
   - Better performance on low-end devices

2. **Batch Processing Optimizations**
   - Dynamic provider selection based on receipt type
   - Smart retry logic for failed items

3. **Caching**
   - Cache parsed receipts
   - Reduce API calls for duplicate images

4. **Advanced Confidence Scoring**
   - Machine learning-based confidence prediction
   - Cross-field validation

5. **More Providers**
   - Claude API
   - GPT-4 Vision
   - Open-source models (Llava, etc.)

6. **Receipt Validation**
   - Checksum validation for prices
   - Tax rate verification
   - Date/time format standardization
