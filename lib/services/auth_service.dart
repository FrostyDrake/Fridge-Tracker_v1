import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_database.dart';

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirestoreDatabase.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

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
      await _ensureUserDocuments(user);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await _ensureUserDocuments(user);
    }
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> _ensureUserDocuments(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final fridgeRef = userRef.collection('fridges').doc('default');
    final now = FieldValue.serverTimestamp();

    final batch = _firestore.batch();
    batch.set(userRef, {
      'email': user.email,
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
