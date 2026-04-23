import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ocr_receipt_platform_interface.dart';

/// An implementation of [FlutterOcrReceiptPlatform] that uses method channels.
class MethodChannelFlutterOcrReceipt extends FlutterOcrReceiptPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ocr_receipt');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
