import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_database.dart';

class FridgeItemService {
  FridgeItemService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirestoreDatabase.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _itemsCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('fridges')
        .doc('default')
        .collection('items');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchItems(String userId) {
    return _itemsCollection(userId).orderBy('expiryDate').snapshots();
  }

  Future<void> addItem({
    required String userId,
    required String name,
    required String category,
    required DateTime expiryDate,
    String source = 'manual',
    String? imageUrl,
  }) {
    return _itemsCollection(userId).add({
      'name': name,
      'category': category,
      'addedDate': Timestamp.now(),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'source': source,
      'imageUrl': imageUrl,
    });
  }

  Future<void> deleteItem({required String userId, required String itemId}) {
    return _itemsCollection(userId).doc(itemId).delete();
  }
}
