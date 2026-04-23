import 'dart:convert';

import 'package:http/http.dart' as http;

import '../exceptions/ocr_exception.dart';
import 'base_ocr_provider.dart';

/// OCR provider that uses Alibaba GLM API.
class GLMProvider extends BaseOcrProvider {
  final String apiKey;
  final String apiEndpoint;

  /// Create a GLM provider.
  ///
  /// [apiKey] - API key for GLM service
  /// [apiEndpoint] - Optional API endpoint (defaults to Alibaba GLM endpoint)
  GLMProvider({
    required this.apiKey,
    this.apiEndpoint = 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
  });

  @override
  String get providerName => 'glm';

  @override
  Future<String> processImage(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    try {
      final base64Image = base64Encode(imageData);
      final systemPromptValue = systemPrompt ?? getDefaultSystemPrompt();
      final userPromptValue = userPrompt ?? getDefaultUserPrompt();

      final client = http.Client();
      try {
        final response = await client.post(
          Uri.parse(apiEndpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': 'glm-4v',
            'messages': [
              {
                'role': 'system',
                'content': systemPromptValue,
              },
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/jpeg;base64,$base64Image',
                    },
                  },
                  {
                    'type': 'text',
                    'text': userPromptValue,
                  },
                ],
              },
            ],
            'temperature': 0.1,
            'top_p': 0.7,
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          throw InferenceException(
            'GLM API request failed',
            response.body,
            response.statusCode,
          );
        }

        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final message = (jsonResponse['choices'] as List?)?[0];
        if (message == null) {
          throw InferenceException('Invalid response structure from GLM API', null, response.statusCode);
        }

        return message['message']['content'] as String? ?? '';
      } finally {
        client.close();
      }
    } catch (e) {
      if (e is InferenceException) {
        rethrow;
      }
      throw InferenceException('Failed to process image with GLM', e);
    }
  }

  @override
  Future<Map<String, dynamic>> processImageStructured(
    List<int> imageData, {
    String? systemPrompt,
    String? userPrompt,
  }) async {
    final response = await processImage(
      imageData,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );

    try {
      // Parse JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) {
        throw ParsingException('No JSON found in GLM response', null, response);
      }

      final jsonStr = jsonMatch.group(0)!;
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      if (e is ParsingException) {
        rethrow;
      }
      throw ParsingException('Failed to parse GLM response as JSON', e, response);
    }
  }
}
