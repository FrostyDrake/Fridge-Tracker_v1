import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Samler Firestore-adgang, så appen bruger den samme database-id overalt.
class FirestoreDatabase {
  // Navnet på den Firestore database appen bruger.
  static const id = 'default';

  // Returnerer Firestore-instansen for den initialiserede Firebase-app.
  static FirebaseFirestore get instance {
    return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: id);
  }
}
