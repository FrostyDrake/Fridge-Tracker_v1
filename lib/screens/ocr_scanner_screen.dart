import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/fridge_item_service.dart';
import '../services/ocr_product_service.dart';

class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({super.key, required this.userId});

  final String userId;

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _ocrService = OcrProductService();
  final _fridgeItemService = FridgeItemService();

  OcrProductSuggestion? _suggestion;
  bool _isScanning = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_scanImage());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

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
        if (mounted && _suggestion == null) {
          Navigator.pop(context);
        }
        return;
      }

      final suggestion = await _ocrService.analyzeImage(image.path);
      _applySuggestion(suggestion);
    } catch (error) {
      setState(() {
        _errorMessage = 'Teksten kunne ikke læses: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _applySuggestion(OcrProductSuggestion suggestion) {
    setState(() {
      _suggestion = suggestion;
      _nameController.text = suggestion.name;
      _categoryController.text = suggestion.category;
      _expiryDateController.text = suggestion.expiryDate == null
          ? _formatDate(DateTime.now().add(const Duration(days: 7)))
          : _formatDate(suggestion.expiryDate!);
    });
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _fridgeItemService.addItem(
        userId: widget.userId,
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        expiryDate: DateTime.parse(_expiryDateController.text.trim()),
        source: 'scan',
      );

      if (!mounted) {
        return;
      }

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
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Feltet skal udfyldes';
    }
    return null;
  }

  String? _validateDate(String? value) {
    final requiredError = _requiredText(value);
    if (requiredError != null) {
      return requiredError;
    }

    final date = DateTime.tryParse(value!.trim());
    if (date == null) {
      return 'Brug formatet YYYY-MM-DD';
    }

    return null;
  }

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

    return Scaffold(
      appBar: AppBar(title: const Text('Scan varetekst')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isScanning)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (suggestion == null)
                FilledButton.icon(
                  onPressed: _scanImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tag billede'),
                )
              else
                _ConfirmationForm(
                  formKey: _formKey,
                  nameController: _nameController,
                  categoryController: _categoryController,
                  expiryDateController: _expiryDateController,
                  confidenceText: _confidenceText(suggestion.confidence),
                  reason: suggestion.reason,
                  alternativeNames: suggestion.alternativeNames,
                  onUseAlternativeName: (name) {
                    _nameController.text = name;
                  },
                  rawText: suggestion.rawText,
                  isSaving: _isSaving,
                  onRetake: _scanImage,
                  onSave: _saveItem,
                  validateRequiredText: _requiredText,
                  validateDate: _validateDate,
                ),
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
  final VoidCallback onRetake;
  final VoidCallback onSave;
  final String? Function(String?) validateRequiredText;
  final String? Function(String?) validateDate;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Er dette korrekt?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(confidenceText),
          const SizedBox(height: 4),
          Text(reason),
          if (alternativeNames.isNotEmpty) ...[
            const SizedBox(height: 12),
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
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Varenavn',
              border: OutlineInputBorder(),
            ),
            validator: validateRequiredText,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: categoryController,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            validator: validateRequiredText,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: expiryDateController,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: 'Udløbsdato',
              helperText: 'Ret datoen hvis OCR læste forkert',
              hintText: 'fx 2026-06-01',
              border: OutlineInputBorder(),
            ),
            validator: validateDate,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: const Icon(Icons.check),
            label: Text(isSaving ? 'Gemmer...' : 'Gem vare'),
          ),
          TextButton.icon(
            onPressed: isSaving ? null : onRetake,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tag nyt billede'),
          ),
          const SizedBox(height: 24),
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
