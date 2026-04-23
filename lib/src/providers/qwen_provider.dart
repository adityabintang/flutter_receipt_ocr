import 'dart:convert';

import 'package:http/http.dart' as http;

import '../exceptions/ocr_exception.dart';
import 'base_ocr_provider.dart';

/// OCR provider that uses Alibaba Qwen (Qwen-VL) API.
class QwenProvider extends BaseOcrProvider {
  final String apiKey;
  final String apiEndpoint;

  /// Create a Qwen provider.
  ///
  /// [apiKey] - API key for Qwen service
  /// [apiEndpoint] - Optional API endpoint (defaults to Alibaba Qwen endpoint)
  QwenProvider({
    required this.apiKey,
    this.apiEndpoint = 'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation',
  });

  @override
  String get providerName => 'qwen';

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

      final response = await http.post(
        Uri.parse(apiEndpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'X-DashScope-Async': 'enable',
        },
        body: jsonEncode({
          'model': 'qwen-vl-plus',
          'messages': [
            {
              'role': 'system',
              'content': systemPromptValue,
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'image': 'data:image/jpeg;base64,$base64Image',
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
        timeout: const Duration(seconds: 30),
      );

      if (response.statusCode != 200) {
        throw InferenceException(
          'Qwen API request failed',
          response.body,
          response.statusCode,
        );
      }

      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final output = jsonResponse['output'] as Map<String, dynamic>?;
      if (output == null) {
        throw InferenceException('Invalid response structure from Qwen API', null, response.statusCode);
      }

      final choices = output['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        throw InferenceException('No choices in Qwen response', null, response.statusCode);
      }

      final message = choices[0] as Map<String, dynamic>;
      return message['message']['content'] as String? ?? '';
    } catch (e) {
      if (e is InferenceException) {
        rethrow;
      }
      throw InferenceException('Failed to process image with Qwen', e);
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
        throw ParsingException('No JSON found in Qwen response', null, response);
      }

      final jsonStr = jsonMatch.group(0)!;
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      if (e is ParsingException) {
        rethrow;
      }
      throw ParsingException('Failed to parse Qwen response as JSON', e, response);
    }
  }
}
