import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_database.dart';

// Service der samler login, konto-oprettelse og brugerens startdata.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirestoreDatabase.instance;

  // Firebase Auth håndterer selve login/konto-oprettelsen.
  final FirebaseAuth _auth;

  // Firestore bruges til at oprette brugerens dokumenter efter login.
  final FirebaseFirestore _firestore;

  // Opretter en ny bruger med email og adgangskode.
  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      // Sikrer at brugeren også har dokumenter i Firestore.
      await _ensureUserDocuments(user);
    }
  }

  // Logger en eksisterende bruger ind.
  Future<void> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      // Opretter manglende Firestore-data, hvis brugeren ikke har det endnu.
      await _ensureUserDocuments(user);
    }
  }

  // Logger den aktuelle bruger ud.
  Future<void> signOut() {
    return _auth.signOut();
  }

  // Opretter eller opdaterer brugerens basisdokumenter i Firestore.
  Future<void> _ensureUserDocuments(User user) async {
    // Brugerens dokument og standard-køleskab ligger under users/{uid}.
    final userRef = _firestore.collection('users').doc(user.uid);
    final fridgeRef = userRef.collection('fridges').doc('default');
    final now = FieldValue.serverTimestamp();

    // Batch sikrer at bruger og køleskab gemmes samlet.
    final batch = _firestore.batch();
    batch.set(userRef, {
      'email': user.email,
      'emailLower': user.email?.toLowerCase(),
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
    batch.set(fridgeRef, {
      'name': 'Mit køleskab',
      'createdAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
