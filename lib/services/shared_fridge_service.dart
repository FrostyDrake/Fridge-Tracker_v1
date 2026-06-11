import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_database.dart';

class SharedFridge {
  const SharedFridge({
    required this.ownerId,
    required this.ownerEmail,
    required this.fridgeName,
  });

  final String ownerId;
  final String ownerEmail;
  final String fridgeName;

  factory SharedFridge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SharedFridge(
      ownerId: data['ownerId'] as String? ?? doc.id,
      ownerEmail: data['ownerEmail'] as String? ?? 'Ukendt bruger',
      fridgeName: data['fridgeName'] as String? ?? 'Delt køleskab',
    );
  }
}

class SharedFridgeMember {
  const SharedFridgeMember({required this.uid, required this.email});

  final String uid;
  final String email;

  factory SharedFridgeMember.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return SharedFridgeMember(
      uid: data['uid'] as String? ?? doc.id,
      email: data['email'] as String? ?? 'Ukendt bruger',
    );
  }
}

class SharedFridgeService {
  SharedFridgeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirestoreDatabase.instance;

  final FirebaseFirestore _firestore;

  Stream<List<SharedFridge>> watchSharedFridges(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('sharedFridges')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(SharedFridge.fromDoc).toList());
  }

  Stream<List<SharedFridgeMember>> watchMembers(String ownerUserId) {
    return _firestore
        .collection('users')
        .doc(ownerUserId)
        .collection('fridges')
        .doc('default')
        .collection('members')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(SharedFridgeMember.fromDoc).toList(),
        );
  }

  Future<void> shareWithEmail({
    required String ownerUserId,
    required String recipientEmail,
  }) async {
    final email = recipientEmail.trim();
    final normalizedEmail = email.toLowerCase();
    if (email.isEmpty) {
      throw const SharedFridgeException('Skriv en email først');
    }

    final recipient = await _findUserByEmail(email, normalizedEmail);
    if (recipient == null) {
      throw const SharedFridgeException('Brugeren blev ikke fundet');
    }
    if (recipient.id == ownerUserId) {
      throw const SharedFridgeException('Du kan ikke dele med dig selv');
    }

    final ownerDoc = await _firestore.collection('users').doc(ownerUserId).get();
    final ownerEmail =
        ownerDoc.data()?['email'] as String? ?? 'Ukendt bruger';
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    final recipientShareRef = _firestore
        .collection('users')
        .doc(recipient.id)
        .collection('sharedFridges')
        .doc(ownerUserId);
    batch.set(recipientShareRef, {
      'ownerId': ownerUserId,
      'ownerEmail': ownerEmail,
      'fridgeName': 'Delt køleskab',
      'sharedAt': now,
    }, SetOptions(merge: true));

    final memberRef = _firestore
        .collection('users')
        .doc(ownerUserId)
        .collection('fridges')
        .doc('default')
        .collection('members')
        .doc(recipient.id);
    batch.set(memberRef, {
      'uid': recipient.id,
      'email': recipient.data()['email'] as String? ?? email,
      'sharedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserByEmail(
    String email,
    String normalizedEmail,
  ) async {
    final byNormalized = await _firestore
        .collection('users')
        .where('emailLower', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byNormalized.docs.isNotEmpty) {
      return byNormalized.docs.first;
    }

    final byEmail = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return byEmail.docs.isEmpty ? null : byEmail.docs.first;
  }
}

class SharedFridgeException implements Exception {
  const SharedFridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}
