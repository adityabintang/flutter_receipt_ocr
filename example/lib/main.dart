import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ocr_receipt/flutter_ocr_receipt.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Receipt OCR Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ReceiptOcrScreen(),
    );
  }
}

class ReceiptOcrScreen extends StatefulWidget {
  const ReceiptOcrScreen({super.key});

  @override
  State<ReceiptOcrScreen> createState() => _ReceiptOcrScreenState();
}

class _ReceiptOcrScreenState extends State<ReceiptOcrScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final FlutterReceiptOcr _ocr = FlutterReceiptOcr.mock();

  XFile? _selectedImage;
  ReceiptData? _recognizedReceipt;
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = image;
          _recognizedReceipt = null;
          _errorMessage = null;
        });
        await _recognizeReceipt();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _recognizeReceipt() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final imageBytes = await _selectedImage!.readAsBytes();
      final receipt = await _ocr.recognizeReceipt(imageBytes);

      setState(() {
        _recognizedReceipt = receipt;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'OCR failed: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt OCR Demo'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_selectedImage!.path),
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'No image selected',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isProcessing)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error',
                        style: TextStyle(
                          color: Colors.red[900],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[900]),
                      ),
                    ],
                  ),
                )
              else if (_recognizedReceipt != null)
                _buildReceiptDisplay(_recognizedReceipt!)
              else if (_selectedImage != null)
                const Center(
                  child: Text('Tap the camera or gallery button to recognize the receipt'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptDisplay(ReceiptData receipt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          'Confidence Score',
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: receipt.overallConfidence / 100,
                        // minRadius: 60,
                        strokeWidth: 8,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          receipt.overallConfidence >= 80
                              ? Colors.green
                              : receipt.overallConfidence >= 60
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                      Text(
                        '${receipt.overallConfidence}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildSection(
          'Merchant Information',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField('Name', receipt.merchant.name,
                  receipt.merchant.confidenceScores['name']),
              if (receipt.merchant.address != null)
                _buildField('Address', receipt.merchant.address!,
                    receipt.merchant.confidenceScores['address']),
              if (receipt.merchant.phone != null)
                _buildField('Phone', receipt.merchant.phone!,
                    receipt.merchant.confidenceScores['phone']),
            ],
          ),
        ),
        if (receipt.transaction.date != null ||
            receipt.transaction.time != null ||
            receipt.transaction.paymentMethod != null)
          _buildSection(
            'Transaction Information',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (receipt.transaction.date != null)
                  _buildField(
                    'Date',
                    receipt.transaction.date.toString().split(' ')[0],
                    receipt.transaction.confidenceScores['date'],
                  ),
                if (receipt.transaction.time != null)
                  _buildField('Time', receipt.transaction.time!,
                      receipt.transaction.confidenceScores['time']),
                if (receipt.transaction.paymentMethod != null)
                  _buildField(
                    'Payment Method',
                    receipt.transaction.paymentMethod!,
                    receipt.transaction.confidenceScores['paymentMethod'],
                  ),
              ],
            ),
          ),
        _buildSection(
          'Items (${receipt.items.length})',
          Column(
            children: receipt.items
                .map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Qty: ${item.quantity}'),
                            Text('Price: \$${item.totalPrice.toStringAsFixed(2)}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        _buildSection(
          'Summary',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField('Subtotal', '\$${receipt.summary.subtotal.toStringAsFixed(2)}',
                  receipt.summary.confidenceScores['subtotal']),
              _buildField(
                'Tax',
                '\$${receipt.summary.tax.toStringAsFixed(2)}',
                receipt.summary.confidenceScores['tax'],
              ),
              if (receipt.summary.serviceCharge != null)
                _buildField(
                  'Service Charge',
                  '\$${receipt.summary.serviceCharge!.toStringAsFixed(2)}',
                  receipt.summary.confidenceScores['serviceCharge'],
                ),
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '\$${receipt.summary.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildSection(
          'Processing Info',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Model: ${receipt.metadata.modelUsed}'),
              Text('Time: ${receipt.metadata.processingTimeMs}ms'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildField(String label, String value, int? confidence) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('$label:'),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (confidence != null)
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: SizedBox(
                width: 40,
                child: LinearProgressIndicator(
                  value: confidence / 100,
                  minHeight: 4,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    confidence >= 80
                        ? Colors.green
                        : confidence >= 60
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
