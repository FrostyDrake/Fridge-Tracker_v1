import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_database.dart';

// Model for et køleskab, som en anden bruger har delt med dig.
class SharedFridge {
  const SharedFridge({
    required this.ownerId,
    required this.ownerEmail,
    required this.fridgeName,
  });

  // Ejerens id, email og navnet på det delte køleskab.
  final String ownerId;
  final String ownerEmail;
  final String fridgeName;

  // Laver modellen ud fra et Firestore-dokument.
  factory SharedFridge.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SharedFridge(
      ownerId: data['ownerId'] as String? ?? doc.id,
      ownerEmail: data['ownerEmail'] as String? ?? 'Ukendt bruger',
      fridgeName: data['fridgeName'] as String? ?? 'Delt køleskab',
    );
  }
}

// Model for et medlem, som har adgang til brugerens køleskab.
class SharedFridgeMember {
  const SharedFridgeMember({required this.uid, required this.email});

  // Medlemmets bruger-id og email.
  final String uid;
  final String email;

  // Laver medlemsmodellen ud fra Firestore-data.
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

// Service der håndterer simple shared fridge-funktioner.
class SharedFridgeService {
  SharedFridgeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirestoreDatabase.instance;

  // Firestore bruges til at læse og skrive shared fridge-data.
  final FirebaseFirestore _firestore;

  // Lytter på køleskabe, som er delt med den aktuelle bruger.
  Stream<List<SharedFridge>> watchSharedFridges(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('sharedFridges')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(SharedFridge.fromDoc).toList());
  }

  // Lytter på medlemmer, der har adgang til ejerens standard-køleskab.
  Stream<List<SharedFridgeMember>> watchMembers(String ownerUserId) {
    return _firestore
        .collection('users')
        .doc(ownerUserId)
        .collection('fridges')
        .doc('default')
        .collection('members')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(SharedFridgeMember.fromDoc).toList(),
        );
  }

  // Deler ejerens køleskab med en anden bruger via email.
  Future<void> shareWithEmail({
    required String ownerUserId,
    required String recipientEmail,
  }) async {
    // Email trimmes og normaliseres, så opslag bliver mere robust.
    final email = recipientEmail.trim();
    final normalizedEmail = email.toLowerCase();
    if (email.isEmpty) {
      throw const SharedFridgeException('Skriv en email først');
    }

    // Finder modtagerens bruger-dokument.
    final recipient = await _findUserByEmail(email, normalizedEmail);
    if (recipient == null) {
      throw const SharedFridgeException('Brugeren blev ikke fundet');
    }
    if (recipient.id == ownerUserId) {
      throw const SharedFridgeException('Du kan ikke dele med dig selv');
    }

    // Henter ejerens email, så modtageren kan se hvem der delte køleskabet.
    final ownerDoc = await _firestore
        .collection('users')
        .doc(ownerUserId)
        .get();
    final ownerEmail = ownerDoc.data()?['email'] as String? ?? 'Ukendt bruger';
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    // Modtageren får en reference til det delte køleskab.
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

    // Ejeren får modtageren i sin medlemsliste.
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

    // Begge dokumenter gemmes samlet.
    await batch.commit();
  }

  // Finder en bruger på emailLower først og email som fallback.
  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserByEmail(
    String email,
    String normalizedEmail,
  ) async {
    // Nyere brugere har emailLower, som er bedst til case-insensitive opslag.
    final byNormalized = await _firestore
        .collection('users')
        .where('emailLower', isEqualTo: normalizedEmail)
        .limit(1)
        .get();
    if (byNormalized.docs.isNotEmpty) {
      return byNormalized.docs.first;
    }

    // Fallback til gamle dokumenter, som måske kun har email.
    final byEmail = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return byEmail.docs.isEmpty ? null : byEmail.docs.first;
  }
}

// Exception med en besked, der kan vises direkte i UI'et.
class SharedFridgeException implements Exception {
  const SharedFridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}
