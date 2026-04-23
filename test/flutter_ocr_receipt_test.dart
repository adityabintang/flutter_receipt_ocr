import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ocr_receipt/flutter_ocr_receipt.dart';
import 'package:flutter_ocr_receipt/flutter_ocr_receipt_platform_interface.dart';
import 'package:flutter_ocr_receipt/flutter_ocr_receipt_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterOcrReceiptPlatform
    with MockPlatformInterfaceMixin
    implements FlutterOcrReceiptPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterOcrReceiptPlatform initialPlatform = FlutterOcrReceiptPlatform.instance;

  test('$MethodChannelFlutterOcrReceipt is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterOcrReceipt>());
  });

  test('getPlatformVersion', () async {
    FlutterOcrReceipt flutterOcrReceiptPlugin = FlutterOcrReceipt();
    MockFlutterOcrReceiptPlatform fakePlatform = MockFlutterOcrReceiptPlatform();
    FlutterOcrReceiptPlatform.instance = fakePlatform;

    expect(await flutterOcrReceiptPlugin.getPlatformVersion(), '42');
  });
}
