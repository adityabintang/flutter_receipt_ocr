/// Interface for image processing operations.
abstract class ImageProcessor {
  /// Compress image data while maintaining quality.
  ///
  /// [imageData] - Raw image bytes
  /// [maxWidth] - Maximum width (optional)
  /// [maxHeight] - Maximum height (optional)
  /// [quality] - Quality level 0-100 (default: 85)
  /// Returns compressed image bytes.
  Future<List<int>> compress(
    List<int> imageData, {
    int? maxWidth,
    int? maxHeight,
    int quality = 85,
  });

  /// Resize image to specific dimensions.
  ///
  /// [imageData] - Raw image bytes
  /// [width] - Target width
  /// [height] - Target height
  /// Returns resized image bytes.
  Future<List<int>> resize(
    List<int> imageData,
    int width,
    int height,
  );

  /// Convert JPG image to WebP format.
  ///
  /// [jpgData] - JPG image bytes
  /// [quality] - Quality level 0-100 (default: 85)
  /// Returns WebP image bytes.
  Future<List<int>> convertToWebP(
    List<int> jpgData, {
    int quality = 85,
  });

  /// Analyze image properties without modifying it.
  ///
  /// [imageData] - Raw image bytes
  /// Returns map with: width, height, format, estimatedSize
  Future<Map<String, dynamic>> analyzeImage(List<int> imageData);
}
