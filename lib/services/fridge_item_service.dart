import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_database.dart';

// Service der læser og ændrer varer i brugerens køleskab.
class FridgeItemService {
  FridgeItemService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirestoreDatabase.instance;

  // Firestore-instansen bruges til alle databasekald.
  final FirebaseFirestore _firestore;

  // Finder items-collection for brugerens standard-køleskab.
  CollectionReference<Map<String, dynamic>> _itemsCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('fridges')
        .doc('default')
        .collection('items');
  }

  // Lytter live på varer sorteret efter udløbsdato.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchItems(String userId) {
    return _itemsCollection(userId).orderBy('expiryDate').snapshots();
  }

  // Tilføjer en ny vare til køleskabet.
  Future<void> addItem({
    required String userId,
    required String name,
    required String category,
    required DateTime expiryDate,
    String source = 'manual',
    String? imageUrl,
  }) {
    // Firestore gemmer datoer som Timestamp.
    return _itemsCollection(userId).add({
      'name': name,
      'category': category,
      'addedDate': Timestamp.now(),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'source': source,
      'imageUrl': imageUrl,
    });
  }

  // Sletter en vare fra køleskabet.
  Future<void> deleteItem({required String userId, required String itemId}) {
    return _itemsCollection(userId).doc(itemId).delete();
  }

  // Gendanner en slettet vare med dens gamle data.
  Future<void> restoreItem({
    required String userId,
    required String itemId,
    required Map<String, dynamic> data,
  }) {
    return _itemsCollection(userId).doc(itemId).set(data);
  }

  // Opdaterer kun de felter, der er sendt med.
  Future<void> updateItem({
    required String userId,
    required String itemId,
    String? name,
    String? category,
    DateTime? expiryDate,
  }) {
    final updates = <String, dynamic>{};

    // Tilføjer kun ændrede værdier til update-map.
    if (name != null) {
      updates['name'] = name;
    }
    if (category != null) {
      updates['category'] = category;
    }
    if (expiryDate != null) {
      updates['expiryDate'] = Timestamp.fromDate(expiryDate);
    }

    // Hvis intet er ændret, laver vi ikke et Firestore-kald.
    if (updates.isEmpty) {
      return Future.value();
    }

    return _itemsCollection(userId).doc(itemId).update(updates);
  }
}
