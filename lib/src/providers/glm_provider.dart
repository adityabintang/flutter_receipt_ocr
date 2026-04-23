import 'dart:convert';

import 'package:http/http.dart' as http;

import '../exceptions/ocr_exception.dart';
import 'base_ocr_provider.dart';

/// OCR provider that uses Zhipu AI GLM-OCR API (Layout Parsing).
///
/// Uses the official GLM-OCR model through the layout parsing endpoint:
/// POST https://api.z.ai/api/paas/v4/layout_parsing
///
/// Get your API key at: https://z.ai/manage-apikey/apikey-list
class GLMProvider extends BaseOcrProvider {
  final String apiKey;
  final String apiEndpoint;

  /// Create a GLM-OCR provider.
  ///
  /// [apiKey] - API key for GLM-OCR service from https://z.ai
  /// [apiEndpoint] - Optional API endpoint (defaults to official Zhipu AI endpoint)
  GLMProvider({
    required this.apiKey,
    this.apiEndpoint = 'https://api.z.ai/api/paas/v4/layout_parsing',
  });

  @override
  String get providerName => 'glm-ocr';

  @override
  Future<String> processImage(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    try {
      // Convert image to base64
      final base64Image = base64Encode(imageData);

      final client = http.Client();
      try {
        // Make request to GLM-OCR Layout Parsing API
        final response = await client.post(
          Uri.parse(apiEndpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'glm-ocr',
            'file': 'data:image/jpeg;base64,$base64Image',
            'return_crop_images': false,
            'need_layout_visualization': false,
          }),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode != 200) {
          throw InferenceException(
            'GLM-OCR API request failed',
            response.body,
            response.statusCode,
          );
        }

        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Return markdown results which contains the OCR text
        final mdResults = jsonResponse['md_results'] as String? ?? '';
        if (mdResults.isEmpty) {
          throw InferenceException(
            'No OCR results returned from GLM-OCR',
            null,
            response.statusCode,
          );
        }

        return mdResults;
      } finally {
        client.close();
      }
    } catch (e) {
      if (e is InferenceException) {
        rethrow;
      }
      throw InferenceException('Failed to process image with GLM-OCR', e);
    }
  }

  @override
  Future<Map<String, dynamic>> processImageStructured(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    try {
      // Convert image to base64
      final base64Image = base64Encode(imageData);

      final client = http.Client();
      try {
        // Make request with layout details enabled for structured data
        final response = await client.post(
          Uri.parse(apiEndpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'glm-ocr',
            'file': 'data:image/jpeg;base64,$base64Image',
            'return_crop_images': true,
            'need_layout_visualization': false,
          }),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode != 200) {
          throw InferenceException(
            'GLM-OCR API request failed',
            response.body,
            response.statusCode,
          );
        }

        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Return the full structured response with layout details
        return {
          'id': jsonResponse['id'],
          'created': jsonResponse['created'],
          'model': jsonResponse['model'],
          'md_results': jsonResponse['md_results'],
          'layout_details': jsonResponse['layout_details'] ?? [],
          'data_info': jsonResponse['data_info'],
          'usage': jsonResponse['usage'],
          'request_id': jsonResponse['request_id'],
        };
      } finally {
        client.close();
      }
    } catch (e) {
      if (e is InferenceException) {
        rethrow;
      }
      throw InferenceException('Failed to process image with GLM-OCR', e);
    }
  }
}
