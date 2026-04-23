import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ocr_receipt_method_channel.dart';

abstract class FlutterOcrReceiptPlatform extends PlatformInterface {
  /// Constructs a FlutterOcrReceiptPlatform.
  FlutterOcrReceiptPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterOcrReceiptPlatform _instance = MethodChannelFlutterOcrReceipt();

  /// The default instance of [FlutterOcrReceiptPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterOcrReceipt].
  static FlutterOcrReceiptPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterOcrReceiptPlatform] when
  /// they register themselves.
  static set instance(FlutterOcrReceiptPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
