import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Skærmen der åbner kameraet og scanner en stregkode.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Controlleren styrer kamera, lommelygte og kameraskift.
  final MobileScannerController _controller = MobileScannerController();

  // Forhindrer at den samme stregkode bliver behandlet flere gange.
  bool _isHandlingBarcode = false;

  @override
  void dispose() {
    // Kamera-controlleren ryddes op, når skærmen lukkes.
    _controller.dispose();
    super.dispose();
  }

  // Kaldes automatisk, når kameraet finder en stregkode.
  void _handleBarcode(BarcodeCapture capture) {
    if (_isHandlingBarcode) {
      return;
    }

    // Hvis scanneren ikke fandt nogen stregkoder, stopper funktionen.
    if (capture.barcodes.isEmpty) {
      return;
    }

    // Henter den første fundne stregkode.
    final barcode = capture.barcodes.first;
    final value = barcode.rawValue;

    // Tomme værdier skal ikke sendes tilbage.
    if (value == null || value.trim().isEmpty) {
      return;
    }

    // Sender stregkoden tilbage til den skærm, der åbnede scanneren.
    _isHandlingBarcode = true;
    Navigator.pop(context, value.trim());
  }

  // Giver brugeren mulighed for at skrive stregkoden manuelt.
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

    // Hvis brugeren annullerer eller skriver tom tekst, sker der ingenting.
    if (barcode == null || barcode.isEmpty || !mounted) {
      return;
    }

    // Sender den manuelt skrevne stregkode tilbage.
    Navigator.pop(context, barcode);
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold viser appbar og kamera-indholdet.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan stregkode'),
        actions: [
          // Knap til at tænde og slukke lommelygten.
          IconButton(
            onPressed: _controller.toggleTorch,
            tooltip: 'Lommelygte',
            icon: const Icon(Icons.flashlight_on),
          ),
          // Knap til at skifte mellem forside- og bagsidekamera.
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
          // Selve kamera-scanneren.
          MobileScanner(controller: _controller, onDetect: _handleBarcode),
          // Den hvide ramme viser hvor brugeren skal holde stregkoden.
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
          // Nederste tekstboks med instruktion og manuel indtastning.
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
