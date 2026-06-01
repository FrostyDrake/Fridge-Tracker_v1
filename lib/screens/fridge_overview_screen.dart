import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/fridge_item_service.dart';
import '../services/open_food_facts_service.dart';
import 'add_item_screen.dart';
import 'barcode_scanner_screen.dart';
import 'ocr_scanner_screen.dart';

class FridgeOverviewScreen extends StatelessWidget {
  const FridgeOverviewScreen({super.key, required this.userId});

  final String userId;

  static final _authService = AuthService();
  static final _itemService = FridgeItemService();
  static final _productService = OpenFoodFactsService();

  String get _itemsPath => 'users/$userId/fridges/default/items';

  // Navigation.
  void _goToAddItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddItemScreen(userId: userId)),
    );
  }

  Future<void> _goToBarcodeScanner(BuildContext context) async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (context.mounted && barcode != null) {
      await _addScannedBarcode(context, barcode);
    }
  }

  Future<void> _goToOcrScanner(BuildContext context) async {
    final didSave = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => OcrScannerScreen(userId: userId)),
    );

    if (!context.mounted || didSave != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Varen blev tilføjet fra tekstscan')),
    );
  }

  Future<void> _addScannedBarcode(BuildContext context, String barcode) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Henter produkt for stregkode $barcode...')),
    );

    final product = await _findProduct(barcode);

    try {
      await _itemService.addItem(
        userId: userId,
        name: product.name,
        category: product.category,
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        source: 'barcode',
        imageUrl: product.imageUrl,
      );

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('${product.name} blev tilføjet')),
        );
      }
    } catch (error) {
      _showSnackBar(context, 'Produktet kunne ikke tilføjes: $error');
    }
  }

  Future<OpenFoodFactsProduct> _findProduct(String barcode) async {
    try {
      return await _productService.findByBarcode(barcode);
    } catch (_) {
      return OpenFoodFactsProduct(
        barcode: barcode,
        name: 'Stregkode $barcode',
        category: 'Ukendt',
      );
    }
  }

  Future<void> _deleteItem(String itemId) {
    return _itemService.deleteItem(userId: userId, itemId: itemId);
  }

  Future<void> _updateItem(
    BuildContext context,
    String itemId, {
    String? name,
    String? category,
    DateTime? expiryDate,
  }) async {
    try {
      await _itemService.updateItem(
        userId: userId,
        itemId: itemId,
        name: name,
        category: category,
        expiryDate: expiryDate,
      );
    } catch (error) {
      _showSnackBar(context, 'Varen kunne ikke opdateres: $error');
    }
  }

  // Edit dialogs.
  Future<void> _editText({
    required BuildContext context,
    required String label,
    required String value,
    required Future<void> Function(String value) save,
  }) async {
    final newValue = await _showInputDialog(
      context,
      title: 'Rediger $label',
      label: label,
      value: value,
    );

    if (newValue != null && newValue.isNotEmpty && newValue != value) {
      await save(newValue);
    }
  }

  Future<void> _editDate({
    required BuildContext context,
    required String itemId,
    required DateTime? value,
  }) async {
    final newValue = await _showInputDialog(
      context,
      title: 'Rediger udløbsdato',
      label: 'Udløbsdato',
      value: value == null ? '' : _formatDate(value),
      hintText: 'fx 2026-06-01',
      keyboardType: TextInputType.datetime,
    );

    if (newValue == null || newValue.isEmpty) {
      return;
    }

    final date = DateTime.tryParse(newValue);
    if (date == null) {
      _showSnackBar(context, 'Brug datoformatet YYYY-MM-DD');
      return;
    }

    await _updateItem(context, itemId, expiryDate: date);
  }

  Future<String?> _showInputDialog(
    BuildContext context, {
    required String title,
    required String label,
    required String value,
    String? hintText,
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuller'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Gem'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  // Data formatting.
  Color _expiryColor(DateTime? date) {
    if (date == null) {
      return Colors.grey;
    }

    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final itemDate = DateTime(date.year, date.month, date.day);
    final daysLeft = itemDate.difference(currentDate).inDays;

    if (daysLeft <= 3) return Colors.red;
    if (daysLeft <= 7) return Colors.orange;
    return Colors.green;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _dateText(DateTime? date) {
    return date == null ? 'Ingen dato' : _formatDate(date);
  }

  String _errorMessage(Object error) {
    if (error is! FirebaseException) {
      return 'Varerne kunne ikke hentes fra databasen: $error';
    }

    switch (error.code) {
      case 'not-found':
        return 'Firestore databasen findes ikke.\n\n'
            'Opret Cloud Firestore database "(default)" i Firebase Console.';
      case 'permission-denied':
        return 'Ingen adgang til Firestore.\n\n'
            'Tjek security rules og data-stien:\n$_itemsPath';
      case 'unavailable':
        return 'Firestore kan ikke nås lige nu.\n\n'
            'Tjek internetforbindelsen og Firebase opsætningen.';
      default:
        return 'Firebase fejl (${error.code}): ${error.message ?? error}';
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // UI.
  Widget _itemsView(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _itemService.watchItems(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageView(_errorMessage(snapshot.error!));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items =
            snapshot.data?.docs.map(_FridgeItem.fromDoc).toList() ?? [];
        if (items.isEmpty) {
          return _emptyView(context);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _productDropdown(context, items[index]);
          },
        );
      },
    );
  }

  Widget _emptyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.kitchen_outlined, size: 56, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Dit køleskab er tomt',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Tilføj din første vare for at se udløbsdatoer her.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _goToAddItem(context),
              icon: const Icon(Icons.add),
              label: const Text('Tilføj vare'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _goToBarcodeScanner(context),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan stregkode'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _goToOcrScanner(context),
              icon: const Icon(Icons.document_scanner),
              label: const Text('Scan varetekst'),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              SelectableText(
                'Appen læser fra:\n$_itemsPath',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _messageView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _productDropdown(BuildContext context, _FridgeItem item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteItem(item.id),
      child: Card(
        child: ExpansionTile(
          leading: CircleAvatar(backgroundColor: _expiryColor(item.expiryDate)),
          title: Text(item.name),
          subtitle: Text('Udløber: ${_dateText(item.expiryDate)}'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _detailRow(
              label: 'Navn',
              value: item.name,
              onEdit: () => _editText(
                context: context,
                label: 'navn',
                value: item.name,
                save: (value) => _updateItem(context, item.id, name: value),
              ),
            ),
            _detailRow(
              label: 'Kategori',
              value: item.category,
              onEdit: () => _editText(
                context: context,
                label: 'kategori',
                value: item.category,
                save: (value) => _updateItem(context, item.id, category: value),
              ),
            ),
            _detailRow(
              label: 'Udløbsdato',
              value: _dateText(item.expiryDate),
              onEdit: () => _editDate(
                context: context,
                itemId: item.id,
                value: item.expiryDate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow({
    required String label,
    required String value,
    required VoidCallback onEdit,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(value),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onEdit,
            tooltip: 'Rediger $label',
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mit køleskab'),
        actions: [
          IconButton(
            onPressed: () => _goToBarcodeScanner(context),
            tooltip: 'Scan stregkode',
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            onPressed: () => _goToOcrScanner(context),
            tooltip: 'Scan varetekst',
            icon: const Icon(Icons.document_scanner),
          ),
          IconButton(
            onPressed: _signOut,
            tooltip: 'Log ud',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _itemsView(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToAddItem(context),
        tooltip: 'Tilføj vare',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FridgeItem {
  const _FridgeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.expiryDate,
  });

  final String id;
  final String name;
  final String category;
  final DateTime? expiryDate;

  factory _FridgeItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _FridgeItem(
      id: doc.id,
      name: data['name'] as String? ?? 'Ukendt vare',
      category: data['category'] as String? ?? 'Ingen kategori',
      expiryDate: _readDate(data['expiryDate']),
    );
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
