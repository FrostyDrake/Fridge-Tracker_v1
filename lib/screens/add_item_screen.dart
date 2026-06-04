import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/fridge_item_service.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, required this.userId});

  final String userId;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _service = FridgeItemService();

  DateTime? _selectedExpiryDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final expiryDate = _selectedExpiryDate;
    if (expiryDate == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _service
          .addItem(
            userId: widget.userId,
            name: _nameController.text.trim(),
            category: _categoryController.text.trim(),
            expiryDate: expiryDate,
          )
          .timeout(const Duration(seconds: 12));

      if (mounted) {
        Navigator.pop(context);
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

    setState(() {
      _selectedExpiryDate = pickedDate;
      _expiryDateController.text = _formatDate(pickedDate);
    });
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

  String? _validateDate(String? value) {
    if (_selectedExpiryDate == null) {
      return 'Vælg en udløbsdato';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tilføj vare')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    labelText: 'Udløbsdato',
                    hintText: 'Vælg dato',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: _validateDate,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _saveItem,
                  child: Text(_isSaving ? 'Gemmer...' : 'Gem vare'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
