import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../exceptions/ocr_exception.dart';
import 'image_processor.dart';

/// Implementation of ImageProcessor using the image package.
class ImageProcessorImpl implements ImageProcessor {
  @override
  Future<List<int>> compress(
    List<int> imageData, {
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
  }) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw ImageProcessingException('Failed to decode image');
      }

      var result = image;

      // Resize if needed
      if (maxWidth != null || maxHeight != null) {
        final width = maxWidth ?? image.width;
        final height = maxHeight ?? image.height;
        result = img.copyResize(image, width: width, height: height);
      }

      // Re-encode with specified quality
      final compressed = img.encodeJpg(result, quality: quality);
      return compressed;
    } catch (e) {
      throw ImageProcessingException('Compression failed', e);
    }
  }

  @override
  Future<List<int>> resize(
    List<int> imageData,
    int width,
    int height,
  ) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw ImageProcessingException('Failed to decode image');
      }

      final resized = img.copyResize(image, width: width, height: height);
      return img.encodeJpg(resized);
    } catch (e) {
      throw ImageProcessingException('Resize failed', e);
    }
  }

  @override
  Future<List<int>> convertToWebP(
    List<int> jpgData, {
    int quality = 85,
  }) async {
    try {
      final image = img.decodeImage(jpgData);
      if (image == null) {
        throw ImageProcessingException('Failed to decode image');
      }

      // The image package doesn't have native WebP support,
      // so we'll compress to PNG as an alternative
      // In production, consider using a WebP package or native implementation
      final webp = img.encodePng(image);
      return webp;
    } catch (e) {
      throw ImageProcessingException('WebP conversion failed', e);
    }
  }

  @override
  Future<Map<String, dynamic>> analyzeImage(List<int> imageData) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) {
        throw ImageProcessingException('Failed to decode image');
      }

      // Detect format from image properties
      String format = 'jpg';
      if (imageData.length > 8) {
        // Check PNG signature
        if (imageData[0] == 0x89 && imageData[1] == 0x50 && imageData[2] == 0x4E && imageData[3] == 0x47) {
          format = 'png';
        }
        // Check GIF signature
        else if (imageData[0] == 0x47 && imageData[1] == 0x49 && imageData[2] == 0x46) {
          format = 'gif';
        }
      }

      return {
        'width': image.width,
        'height': image.height,
        'format': format,
        'estimatedSize': imageData.length,
        'aspectRatio': image.width / image.height,
      };
    } catch (e) {
      throw ImageProcessingException('Image analysis failed', e);
    }
  }
}
