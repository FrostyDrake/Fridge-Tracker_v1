import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/default_expiry_service.dart';
import '../services/fridge_item_service.dart';
import '../services/ocr_product_service.dart';

// Skærmen scanner tekst fra et billede og foreslår en vare.
class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({super.key, required this.userId});

  // Brugerens id bruges, når den scannede vare gemmes i Firestore.
  final String userId;

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  // Form key bruges til at validere bekræftelsesformularen.
  final _formKey = GlobalKey<FormState>();

  // Controllers styrer de felter, som brugeren kan rette før gemning.
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _expiryDateController = TextEditingController();

  // Services håndterer dato-forslag, kamera, OCR og gemning af varen.
  final _expiryService = DefaultExpiryService.instance;
  final _imagePicker = ImagePicker();
  final _ocrService = OcrProductService();
  final _fridgeItemService = FridgeItemService();

  // Indeholder OCR-forslaget, når billedet er blevet analyseret.
  OcrProductSuggestion? _suggestion;

  // Den valgte udløbsdato gemmes separat fra tekstfeltet.
  DateTime? _selectedExpiryDate;

  // Sikrer at brugerens egen dato ikke overskrives af automatisk forslag.
  bool _didManuallyPickExpiry = false;

  // State til scanning, gemning og fejlvisning.
  bool _isScanning = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Starter kamera-flowet automatisk, når skærmen åbnes.
    unawaited(_scanImage());
  }

  @override
  void dispose() {
    // Controllers ryddes op, når skærmen lukkes.
    _nameController.dispose();
    _categoryController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  // Tager et billede og sender det til OCR-servicen.
  Future<void> _scanImage() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (image == null) {
        // Hvis brugeren annullerer første scan, lukkes skærmen igen.
        if (mounted && _suggestion == null) {
          Navigator.pop(context);
        }
        return;
      }

      // Analyserer billedet og udfylder formularen med forslaget.
      final suggestion = await _ocrService.analyzeImage(image.path);
      await _applySuggestion(suggestion);
    } catch (error) {
      setState(() {
        _errorMessage = 'Teksten kunne ikke læses: $error';
      });
    } finally {
      // Slukker scanning-state, når OCR-flowet er færdigt.
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // Udfylder formularen med OCR-forslaget.
  Future<void> _applySuggestion(OcrProductSuggestion suggestion) async {
    final expiryDate =
        suggestion.expiryDate ??
        await _expiryService.expiryDateFor(
          name: suggestion.name,
          category: suggestion.category,
        );

    setState(() {
      _suggestion = suggestion;
      _didManuallyPickExpiry = suggestion.expiryDate != null;
      _selectedExpiryDate = expiryDate;
      _nameController.text = suggestion.name;
      _categoryController.text = suggestion.category;
      _expiryDateController.text = _formatDate(expiryDate);
    });
  }

  // Åbner kalenderen, så brugeren kan rette udløbsdatoen manuelt.
  Future<void> _pickExpiryDate() async {
    final today = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );

    if (pickedDate == null) {
      return;
    }

    // Gemmer den manuelt valgte dato.
    setState(() {
      _didManuallyPickExpiry = true;
      _selectedExpiryDate = pickedDate;
      _expiryDateController.text = _formatDate(pickedDate);
    });
  }

  // Opdaterer standarddatoen, hvis brugeren ændrer varenavnet.
  Future<void> _refreshDefaultExpiryDate() async {
    if (_didManuallyPickExpiry) {
      return;
    }

    final expiryDate = await _expiryService.expiryDateFor(
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
    );

    // Stopper hvis skærmen er lukket, eller brugeren allerede selv valgte dato.
    if (!mounted || _didManuallyPickExpiry) {
      return;
    }

    setState(() {
      _selectedExpiryDate = expiryDate;
      _expiryDateController.text = _formatDate(expiryDate);
    });
  }

  // Bruger et alternativt OCR-navn og opdaterer dato-forslaget.
  void _useAlternativeName(String name) {
    _nameController.text = name;
    unawaited(_refreshDefaultExpiryDate());
  }

  // Gemmer den bekræftede OCR-vare i køleskabet.
  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final expiryDate = _selectedExpiryDate;
    if (expiryDate == null) {
      return;
    }

    // Starter saving-state og fjerner gamle fejlbeskeder.
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Gemmer varen med source 'scan', så appen ved den kom fra OCR.
      await _fridgeItemService.addItem(
        userId: widget.userId,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        expiryDate: expiryDate,
        source: 'scan',
      );

      if (!mounted) {
        return;
      }

      // Sender true tilbage, så oversigten kan vide at en vare blev gemt.
      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      setState(() {
        _errorMessage = 'Varen kunne ikke gemmes (${error.code}).';
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Varen kunne ikke gemmes: $error';
      });
    } finally {
      // Slukker saving-state igen, hvis skærmen stadig er åben.
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Formaterer datoen som dag-måned-år.
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  // Tjekker at tekstfelter ikke er tomme.
  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Feltet skal udfyldes';
    }
    return null;
  }

  // Tjekker at der er valgt en udløbsdato.
  String? _validateDate(String? value) {
    if (_selectedExpiryDate == null) {
      return 'V\u00e6lg en udl\u00f8bsdato';
    }

    return null;
  }

  // Oversætter OCR-sikkerhed til en kort dansk tekst.
  String _confidenceText(double confidence) {
    if (confidence >= 0.85) {
      return 'Høj sikkerhed';
    }
    if (confidence >= 0.65) {
      return 'Middel sikkerhed';
    }
    return 'Lav sikkerhed';
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _suggestion;

    // Skærmen viser enten loading, scan-knap eller bekræftelsesformular.
    return Scaffold(
      appBar: AppBar(title: const Text('Scan varetekst')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isScanning)
                // Vises mens billedet analyseres.
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (suggestion == null)
                // Vises hvis der endnu ikke findes et OCR-forslag.
                FilledButton.icon(
                  onPressed: _scanImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tag billede'),
                )
              else
                // Formularen lader brugeren rette OCR-resultatet før gemning.
                _ConfirmationForm(
                  formKey: _formKey,
                  nameController: _nameController,
                  categoryController: _categoryController,
                  expiryDateController: _expiryDateController,
                  confidenceText: _confidenceText(suggestion.confidence),
                  reason: suggestion.reason,
                  alternativeNames: suggestion.alternativeNames,
                  onUseAlternativeName: _useAlternativeName,
                  rawText: suggestion.rawText,
                  isSaving: _isSaving,
                  onPickExpiryDate: _pickExpiryDate,
                  onRetake: _scanImage,
                  onSave: _saveItem,
                  validateRequiredText: _requiredText,
                  validateDate: _validateDate,
                ),
              // Fejlbeskeden vises under formularen, hvis noget går galt.
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Formularen hvor brugeren bekræfter eller retter OCR-resultatet.
class _ConfirmationForm extends StatelessWidget {
  const _ConfirmationForm({
    required this.formKey,
    required this.nameController,
    required this.categoryController,
    required this.expiryDateController,
    required this.confidenceText,
    required this.reason,
    required this.alternativeNames,
    required this.onUseAlternativeName,
    required this.rawText,
    required this.isSaving,
    required this.onPickExpiryDate,
    required this.onRetake,
    required this.onSave,
    required this.validateRequiredText,
    required this.validateDate,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController expiryDateController;
  final String confidenceText;
  final String reason;
  final List<String> alternativeNames;
  final ValueChanged<String> onUseAlternativeName;
  final String rawText;
  final bool isSaving;
  final VoidCallback onPickExpiryDate;
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final String? Function(String?) validateRequiredText;
  final String? Function(String?) validateDate;

  @override
  Widget build(BuildContext context) {
    // Form gør det muligt at validere alle felter før gemning.
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overskrift til bekræftelsesdelen.
          Row(
            children: [
              const Icon(Icons.document_scanner_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tjek varen f\u00f8r du gemmer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Viser hvor sikker OCR-servicen er på sit forslag.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  confidenceText,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(reason),
              ],
            ),
          ),
          if (alternativeNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Alternative navne kan vælges med chips.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in alternativeNames)
                  ActionChip(
                    label: Text(name),
                    onPressed: () => onUseAlternativeName(name),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Brugeren kan rette varenavnet.
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Varenavn',
              border: OutlineInputBorder(),
            ),
            validator: validateRequiredText,
          ),
          const SizedBox(height: 16),
          // Brugeren kan rette kategorien.
          TextFormField(
            controller: categoryController,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            validator: validateRequiredText,
          ),
          const SizedBox(height: 16),
          // Udløbsdatoen åbner kalenderen ved tryk.
          TextFormField(
            controller: expiryDateController,
            readOnly: true,
            onTap: onPickExpiryDate,
            decoration: const InputDecoration(
              labelText: 'Udløbsdato',
              hintText: 'V\u00e6lg dato',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            validator: validateDate,
          ),
          const SizedBox(height: 24),
          // Gemmer den rettede vare i køleskabet.
          FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.check),
            label: Text(isSaving ? 'Gemmer...' : 'Gem vare'),
          ),
          // Starter kameraet igen, hvis brugeren vil tage et nyt billede.
          TextButton.icon(
            onPressed: isSaving ? null : onRetake,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tag nyt billede'),
          ),
          const SizedBox(height: 24),
          // Viser rå OCR-tekst til fejltjek.
          ExpansionTile(
            title: const Text('Læst tekst'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  rawText.trim().isEmpty ? 'Ingen tekst' : rawText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
