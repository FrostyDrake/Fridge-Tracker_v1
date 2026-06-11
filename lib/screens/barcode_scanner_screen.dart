import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _isHandlingBarcode = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isHandlingBarcode) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }

    final barcode = capture.barcodes.first;
    final value = barcode.rawValue;

    if (value == null || value.trim().isEmpty) {
      return;
    }

    _isHandlingBarcode = true;
    Navigator.pop(context, value.trim());
  }

  Future<void> _enterBarcodeManually() async {
    final controller = TextEditingController();
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Skriv stregkode'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Stregkode',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuller'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Brug'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (barcode == null || barcode.isEmpty || !mounted) {
      return;
    }

    Navigator.pop(context, barcode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan stregkode'),
        actions: [
          IconButton(
            onPressed: _controller.toggleTorch,
            tooltip: 'Lommelygte',
            icon: const Icon(Icons.flashlight_on),
          ),
          IconButton(
            onPressed: _controller.switchCamera,
            tooltip: 'Skift kamera',
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _handleBarcode),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Hold stregkoden inden for rammen',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _enterBarcodeManually,
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Skriv stregkode'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
