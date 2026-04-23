
import 'flutter_ocr_receipt_platform_interface.dart';

class FlutterOcrReceipt {
  Future<String?> getPlatformVersion() {
    return FlutterOcrReceiptPlatform.instance.getPlatformVersion();
  }
}
