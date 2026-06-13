import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/default_expiry_service.dart';
import '../services/fridge_item_service.dart';

// Skærmen hvor brugeren manuelt kan tilføje en ny vare til køleskabet.
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, required this.userId});

  // Brugerens id bruges til at gemme varen under den rigtige bruger.
  final String userId;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  // Form key bruges til at validere alle felter i formularen.
  final _formKey = GlobalKey<FormState>();

  // Controllers styrer teksten i inputfelterne.
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _expiryDateController = TextEditingController();

  // Services håndterer standard udløbsdato og gemning i databasen.
  final _expiryService = DefaultExpiryService.instance;
  final _service = FridgeItemService();

  // Den valgte udløbsdato gemmes som DateTime, ikke kun som tekst.
  DateTime? _selectedExpiryDate;

  // Sikrer at en manuelt valgt dato ikke bliver overskrevet automatisk.
  bool _didManuallyPickExpiry = false;

  // Holder styr på om appen er i gang med at gemme varen.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Når navn eller kategori ændres, prøver appen at foreslå en udløbsdato.
    _nameController.addListener(_applyDefaultExpiryDate);
    _categoryController.addListener(_applyDefaultExpiryDate);
  }

  @override
  void dispose() {
    // Listeners fjernes før controllers slettes.
    _nameController.removeListener(_applyDefaultExpiryDate);
    _categoryController.removeListener(_applyDefaultExpiryDate);

    // Controllers ryddes op, når skærmen lukkes.
    _nameController.dispose();
    _categoryController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  // Validerer formularen og gemmer varen i brugerens køleskab.
  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Hvis datoen mangler, stopper gemningen.
    final expiryDate = _selectedExpiryDate;
    if (expiryDate == null) {
      return;
    }

    // Starter loading-state, så knappen viser at der gemmes.
    setState(() {
      _isSaving = true;
    });

    try {
      // Gemmer varen gennem FridgeItemService.
      await _service
          .addItem(
            userId: widget.userId,
            name: _nameController.text.trim(),
            category: _categoryController.text.trim(),
            expiryDate: expiryDate,
          )
          .timeout(const Duration(seconds: 12));

      // Når varen er gemt, går brugeren tilbage til forrige skærm.
      if (mounted) {
        Navigator.pop(context);
      }
    } on TimeoutException {
      // Viser fejl hvis databasen ikke svarer hurtigt nok.
      _showError(
        'Databasen svarer ikke. Tjek Firestore database og Firebase config.',
      );
    } on FirebaseException catch (error) {
      // Firebase-fejl bliver lavet om til en mere forståelig besked.
      _showError(_firebaseErrorMessage(error));
    } catch (error) {
      // Andre fejl vises direkte, så de er nemme at fejlfinde.
      _showError('Varen kunne ikke gemmes: $error');
    } finally {
      // Slukker loading-state igen, hvis skærmen stadig er åben.
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Åbner en kalender, hvor brugeren kan vælge udløbsdato.
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

    // Gemmer datoen og skriver den ind i datofeltet.
    setState(() {
      _didManuallyPickExpiry = true;
      _selectedExpiryDate = pickedDate;
      _expiryDateController.text = _formatDate(pickedDate);
    });
  }

  // Finder automatisk en standard udløbsdato ud fra navn og kategori.
  Future<void> _applyDefaultExpiryDate() async {
    if (_didManuallyPickExpiry) {
      return;
    }

    // Tomme felter giver ikke nok information til en standarddato.
    final name = _nameController.text.trim();
    final category = _categoryController.text.trim();
    if (name.isEmpty && category.isEmpty) {
      return;
    }

    // Service-klassen beregner den foreslåede udløbsdato.
    final expiryDate = await _expiryService.expiryDateFor(
      name: name,
      category: category,
    );

    // Undgår at opdatere UI, hvis skærmen er lukket eller datoen er valgt manuelt.
    if (!mounted || _didManuallyPickExpiry) {
      return;
    }

    // Viser den foreslåede dato i formularen.
    setState(() {
      _selectedExpiryDate = expiryDate;
      _expiryDateController.text = _formatDate(expiryDate);
    });
  }

  // Viser fejlbeskeder nederst på skærmen.
  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
    );
  }

  // Gør Firebase-fejl mere læsbare for brugeren.
  String _firebaseErrorMessage(FirebaseException error) {
    if (error.code == 'not-found') {
      return 'Firestore databasen findes ikke.';
    }
    if (error.code == 'permission-denied') {
      return 'Ingen adgang til Firestore. Tjek security rules.';
    }
    return 'Firebase fejl (${error.code}): ${error.message ?? error}';
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

  // Tjekker at brugeren har valgt en udløbsdato.
  String? _validateDate(String? value) {
    if (_selectedExpiryDate == null) {
      return 'Vælg en udløbsdato';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold bygger siden med appbar og formular.
    return Scaffold(
      appBar: AppBar(title: const Text('Tilføj vare')),
      body: SafeArea(
        // ScrollView gør formularen brugbar på små skærme.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Felt til varens navn.
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Varenavn',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 16),
                // Felt til kategori, fx frugt, drikke eller mejeri.
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Kategori',
                    border: OutlineInputBorder(),
                  ),
                  validator: _requiredText,
                ),
                const SizedBox(height: 16),
                // Felt til udløbsdato, som åbner kalenderen når man trykker.
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
                // Gem-knappen deaktiveres mens varen bliver gemt.
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
