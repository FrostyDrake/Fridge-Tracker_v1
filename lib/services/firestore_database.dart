import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreDatabase {
  static const id = 'default';

  static FirebaseFirestore get instance {
    return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: id);
  }
}
