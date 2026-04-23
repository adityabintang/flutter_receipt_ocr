## [0.0.1] - 2026-04-23

### Added

#### Core Features
- `FlutterReceiptOcr` orchestrator for complete OCR pipeline
- Receipt data extraction with 90%+ accuracy target
- Per-field confidence scoring (0-100%)
- Image optimization (compression, resizing, format conversion)

#### Data Models
- `ReceiptData` - Main receipt container
- `MerchantInfo` - Store/merchant information
- `TransactionInfo` - Payment and transaction details
- `ItemLine` - Individual receipt line items
- `SummaryInfo` - Financial summary (subtotal, tax, total)
- `ConfidenceScore` - Field-level confidence tracking
- `ReceiptMetadata` - Processing metadata

#### LLM Providers
- `BaseOcrProvider` - Abstract provider interface
- `MockProvider` - Test provider with sample data
- `GLMProvider` - Alibaba GLM API integration
- `QwenProvider` - Alibaba Qwen (Qwen-VL) API integration

#### Image Processing
- `ImageProcessor` - Abstract interface
- `ImageProcessorImpl` - Pure Dart implementation
- Compression with quality control
- Resizing with aspect ratio options
- Format detection and analysis

#### Parsers
- `ReceiptParser` - Abstract parser interface
- `StructuredParser` - JSON-based parsing
- `FreeformParser` - Regex-based fallback parsing
- Automatic fallback on parsing failures
- Confidence score calculation

#### Error Handling
- `OcrException` - Base exception class
- `ImageProcessingException` - Image handling errors
- `InferenceException` - LLM API errors
- `ParsingException` - Parsing failures

#### Example Application
- Complete Flutter demo app with image picker
- Receipt OCR processing demo
- Results display with confidence visualization

#### Testing
- Unit tests for models, providers, and parsers
- Integration tests for complete pipeline
- Mock provider for testing without API keys
