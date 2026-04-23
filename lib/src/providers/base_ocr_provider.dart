/// Base class for OCR providers that interface with LLM APIs.
abstract class BaseOcrProvider {
  /// Get the name/identifier of this provider.
  String get providerName;

  /// Process an image and return raw text response from the LLM.
  ///
  /// [imageData] - Raw image bytes
  /// [systemPrompt] - Optional system prompt to override default
  /// [userPrompt] - Optional user prompt to override default
  /// Returns raw LLM response as string.
  Future<String> processImage(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  });

  /// Process an image and return structured JSON response from the LLM.
  ///
  /// [imageData] - Raw image bytes
  /// [systemPrompt] - Optional system prompt to override default
  /// [userPrompt] - Optional user prompt to override default
  /// Returns parsed JSON response as Map.
  Future<Map<String, dynamic>> processImageStructured(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  });

  /// Get default system prompt for receipt OCR.
  String getDefaultSystemPrompt() {
    return '''You are an expert receipt OCR assistant. Your task is to extract structured information from receipt images.
You must return valid JSON matching the following schema:
{
  "merchant": {
    "name": "store name",
    "address": "store address (optional)",
    "phone": "store phone (optional)"
  },
  "transaction": {
    "date": "YYYY-MM-DD format",
    "time": "HH:MM format (optional)",
    "paymentMethod": "cash/credit/debit/mobile (optional)",
    "transactionId": "receipt ID (optional)"
  },
  "items": [
    {
      "name": "item description",
      "quantity": 1.0,
      "unitPrice": 9.99,
      "totalPrice": 9.99
    }
  ],
  "summary": {
    "subtotal": 9.99,
    "tax": 0.80,
    "serviceCharge": 0.00,
    "grandTotal": 10.79
  }
}
Ensure all numeric values are valid numbers. If a field is not found, omit it (except for mandatory fields).''';
  }

  /// Get default user prompt for receipt OCR.
  String getDefaultUserPrompt() {
    return '''Please extract and structure all information from this receipt image. Return only valid JSON, no additional text.''';
  }
}
