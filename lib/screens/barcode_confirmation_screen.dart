import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/fridge_item_service.dart';
import '../services/open_food_facts_service.dart';

class BarcodeConfirmationScreen extends StatefulWidget {
  const BarcodeConfirmationScreen({
    super.key,
    required this.userId,
    required this.product,
  });

  final String userId;
  final OpenFoodFactsProduct product;

  @override
  State<BarcodeConfirmationScreen> createState() =>
      _BarcodeConfirmationScreenState();
}

class _BarcodeConfirmationScreenState extends State<BarcodeConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _service = FridgeItemService();

  late DateTime _selectedExpiryDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedExpiryDate = DateTime.now().add(const Duration(days: 7));
    _nameController.text = widget.product.name;
    _categoryController.text = widget.product.category;
    _expiryDateController.text = _formatDate(_selectedExpiryDate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final today = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedExpiryDate = pickedDate;
      _expiryDateController.text = _formatDate(pickedDate);
    });
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final itemName = _nameController.text.trim();

    try {
      await _service
          .addItem(
            userId: widget.userId,
            name: itemName,
            category: _categoryController.text.trim(),
            expiryDate: _selectedExpiryDate,
            source: 'barcode',
            imageUrl: widget.product.imageUrl,
          )
          .timeout(const Duration(seconds: 12));

      if (mounted) {
        Navigator.pop(context, itemName);
      }
    } on TimeoutException {
      _showError(
        'Databasen svarer ikke. Tjek Firestore database og Firebase config.',
      );
    } on FirebaseException catch (error) {
      _showError(_firebaseErrorMessage(error));
    } catch (error) {
      _showError('Varen kunne ikke gemmes: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
  }

  String _firebaseErrorMessage(FirebaseException error) {
    if (error.code == 'not-found') {
      return 'Firestore databasen findes ikke.';
    }
    if (error.code == 'permission-denied') {
      return 'Ingen adgang til Firestore. Tjek security rules.';
    }
    return 'Firebase fejl (${error.code}): ${error.message ?? error}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Feltet skal udfyldes';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bekr\u00e6ft stregkode')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProductPreview(product: widget.product),
                const SizedBox(height: 16),
                Text(
                  'Tjek varen f\u00f8r du gemmer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Stregkode: ${widget.product.barcode}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Varenavn',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _expiryDateController,
                  readOnly: true,
                  onTap: _pickExpiryDate,
                  decoration: const InputDecoration(
                    labelText: 'Udl\u00f8bsdato',
                    hintText: 'V\u00e6lg dato',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveItem,
                  icon: const Icon(Icons.check),
                  label: Text(_isSaving ? 'Gemmer...' : 'Gem vare'),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Annuller'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductPreview extends StatelessWidget {
  const _ProductPreview({required this.product});

  final OpenFoodFactsProduct product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    final placeholder = _placeholder(context);

    if (imageUrl == null) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        height: 160,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: Icon(Icons.qr_code_scanner, size: 42)),
    );
  }
}
