/// Base exception for OCR-related errors.
abstract class OcrException implements Exception {
  final String message;
  final dynamic originalError;

  OcrException(this.message, [this.originalError]);

  @override
  String toString() => 'OcrException: $message${originalError != null ? '\nCaused by: $originalError' : ''}';
}

/// Exception thrown during image processing.
class ImageProcessingException extends OcrException {
  ImageProcessingException(String message, [dynamic originalError]) : super(message, originalError);

  @override
  String toString() => 'ImageProcessingException: $message${originalError != null ? '\nCaused by: $originalError' : ''}';
}

/// Exception thrown during LLM inference.
class InferenceException extends OcrException {
  final int? statusCode;

  InferenceException(String message, [dynamic originalError, this.statusCode]) : super(message, originalError);

  @override
  String toString() => 'InferenceException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}${originalError != null ? '\nCaused by: $originalError' : ''}';
}

/// Exception thrown during receipt data parsing.
class ParsingException extends OcrException {
  final String? unparsedData;

  ParsingException(String message, [dynamic originalError, this.unparsedData]) : super(message, originalError);

  @override
  String toString() {
    final preview = unparsedData != null ? unparsedData!.substring(0, (unparsedData!.length < 100 ? unparsedData!.length : 100)) : null;
    return 'ParsingException: $message${preview != null ? '\nUnparsed data: $preview' : ''}${originalError != null ? '\nCaused by: $originalError' : ''}';
  }
}
