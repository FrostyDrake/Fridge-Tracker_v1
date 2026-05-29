# Andrei - Day 1 and 2

## Day 1 - Firebase and project setup

Status: implemented in repo, Firebase Console must be verified by project owner.

Completed:

- Firebase project is configured as `fridge-tracker-9bd57`.
- Android Firebase app config is present in `android/app/google-services.json`.
- Flutter Firebase options are present in `lib/firebase_options.dart`.
- Android Gradle applies `com.google.gms.google-services`.
- Firestore deploy config is present in `firebase.json`.
- Firestore security rules are present in `firestore.rules`.
- Firestore indexes placeholder is present in `firestore.indexes.json`.

Firebase Console checklist:

- Authentication provider `Email/Password` must be enabled.
- Firestore database `(default)` must exist.
- Firestore rules should be deployed from `firestore.rules`.
- Android package must match `com.example.fridge_tracker`.
- Web app config is present in Dart options for local web testing.

Deploy command:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
```

## Day 2 - Auth flow

Status: implemented.

Completed:

- App initializes Firebase before showing auth-dependent screens.
- `AuthGate` listens to `FirebaseAuth.instance.authStateChanges()`.
- Logged-out users see login/create-account UI.
- Logged-in users are routed to the fridge overview for their Firebase Auth UID.
- Email and password fields validate before calling Firebase Auth.
- Account creation uses `createUserWithEmailAndPassword`.
- Login uses `signInWithEmailAndPassword`.
- Logout uses `FirebaseAuth.signOut`.
- Firebase Auth errors are mapped to Danish user-facing messages.
- Signup/login provisions these Firestore documents:
  - `users/{uid}`
  - `users/{uid}/fridges/default`

Data path for fridge items:

```text
users/{uid}/fridges/default/items/{itemId}
```

If the fridge overview is empty, it means there are no item documents under the
logged-in user's UID at that path yet.
