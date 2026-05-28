import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/fridge_item_service.dart';
import 'add_item_screen.dart';

class FridgeOverviewScreen extends StatelessWidget {
  const FridgeOverviewScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  static final FridgeItemService _service = FridgeItemService();

  String get _itemsPath => 'users/$userId/fridges/default/items';

  void _goToAddItem(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddItemScreen(userId: userId),
      ),
    );
  }

  Future<void> _deleteItem(String itemId) {
    return _service.deleteItem(userId: userId, itemId: itemId);
  }

  Future<void> _signOut() {
    return FirebaseAuth.instance.signOut();
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
    final itemDate = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
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
        return 'Firestore databasen findes ikke. Opret database (default) i Firebase Console.';
      }
      if (error.code == 'permission-denied') {
        return 'Ingen adgang til Firestore.\n\n'
            'Tjek at security rules bruger request.auth.uid == userId, '
            'og at data ligger under:\n$_itemsPath';
      }
      return 'Firebase fejl (${error.code}): ${error.message ?? error}';
    }
    return 'Varerne kunne ikke hentes fra databasen: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mit køleskab'),
        actions: [
          IconButton(
            onPressed: _signOut,
            tooltip: 'Log ud',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.watchItems(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage(snapshot.error!),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data?.docs ?? [];

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Dit køleskab er tomt - tilføj din første vare',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      'Appen læser fra:\n$_itemsPath',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
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
                      expiryDate == null
                          ? 'Ingen dato'
                          : _formatDate(expiryDate),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goToAddItem(context),
        tooltip: 'Tilføj vare',
        child: const Icon(Icons.add),
      ),
    );
  }
}
