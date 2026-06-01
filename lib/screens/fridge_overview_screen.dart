import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/fridge_item_service.dart';
import '../services/open_food_facts_service.dart';
import 'add_item_screen.dart';
import 'barcode_scanner_screen.dart';

class FridgeOverviewScreen extends StatelessWidget {
  const FridgeOverviewScreen({super.key, required this.userId});

  final String userId;

  static final FridgeItemService _service = FridgeItemService();
  static final AuthService _authService = AuthService();
  static final OpenFoodFactsService _openFoodFactsService =
      OpenFoodFactsService();

  String get _itemsPath => 'users/$userId/fridges/default/items';

  void _goToAddItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddItemScreen(userId: userId)),
    );
  }

  Future<void> _goToBarcodeScanner(BuildContext context) async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (!context.mounted || barcode == null) {
      return;
    }

    await _addScannedBarcode(context, barcode);
  }

  Future<void> _addScannedBarcode(BuildContext context, String barcode) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Henter produkt for stregkode $barcode...')),
    );

    OpenFoodFactsProduct product;
    try {
      product = await _openFoodFactsService.findByBarcode(barcode);
    } catch (_) {
      product = OpenFoodFactsProduct(
        barcode: barcode,
        name: 'Stregkode $barcode',
        category: 'Ukendt',
      );
    }

    try {
      await _service.addItem(
        userId: userId,
        name: product.name,
        category: product.category,
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        source: 'barcode',
        imageUrl: product.imageUrl,
      );

      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('${product.name} blev tilføjet')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Produktet kunne ikke tilføjes: $error')),
      );
    }
  }

  Future<void> _deleteItem(String itemId) {
    return _service.deleteItem(userId: userId, itemId: itemId);
  }

  Future<void> _signOut() {
    return _authService.signOut();
  }

  DateTime? _readExpiryDate(Map<String, dynamic> data) {
    final value = data['expiryDate'];
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  Color _expiryColor(DateTime expiryDate) {
    final today = DateTime.now();
    final currentDate = DateTime(today.year, today.month, today.day);
    final itemDate = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );
    final daysLeft = itemDate.difference(currentDate).inDays;

    if (daysLeft <= 2) {
      return Colors.red;
    }
    if (daysLeft <= 5) {
      return Colors.orange;
    }
    return Colors.green;
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _errorMessage(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'not-found') {
        return 'Firestore databasen findes ikke.\n\n'
            'Opret Cloud Firestore database "(default)" i Firebase Console '
            'for projektet fridge-tracker-9bd57.';
      }
      if (error.code == 'permission-denied') {
        return 'Ingen adgang til Firestore.\n\n'
            'Tjek at security rules bruger request.auth.uid == userId, '
            'og at data ligger under:\n$_itemsPath';
      }
      if (error.code == 'unavailable') {
        return 'Firestore kan ikke nås lige nu.\n\n'
            'Tjek internetforbindelsen, at Firestore databasen er oprettet, '
            'og at browseren ikke blokerer firebaseio.com eller googleapis.com.';
      }
      return 'Firebase fejl (${error.code}): ${error.message ?? error}';
    }
    return 'Varerne kunne ikke hentes fra databasen: $error';
  }

  Widget _errorView(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_errorMessage(error), textAlign: TextAlign.center),
      ),
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
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tilføj din første vare for at se udløbsdatoer her.',
              textAlign: TextAlign.center,
            ),
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

  Widget _itemsView(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchItems(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error!);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data?.docs ?? [];

        if (items.isEmpty) {
          return _emptyView(context);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final data = item.data();
            final expiryDate = _readExpiryDate(data);
            final color = expiryDate == null
                ? Colors.grey
                : _expiryColor(expiryDate);

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
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: color),
                  title: Text(data['name'] as String? ?? 'Ukendt vare'),
                  subtitle: Text(
                    data['category'] as String? ?? 'Ingen kategori',
                  ),
                  trailing: Text(
                    expiryDate == null ? 'Ingen dato' : _formatDate(expiryDate),
                  ),
                ),
              ),
            );
          },
        );
      },
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
