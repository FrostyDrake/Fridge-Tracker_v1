# Andrei - Sprint 1

Status: implementeret, dokumenteret og verificeret.

## Formål

Sprint 1 dækkede Firebase-fundamentet, login-flowet og den første sikre
integration mellem Flutter, Firebase Authentication og Cloud Firestore.

Andreis hovedansvar var:

- Firebase-projekt og app-konfiguration
- Authentication med email/adgangskode
- Auth-gate mellem login og køleskabsoversigt
- Firestore security rules for brugerdata
- Fejlbeskeder og validering i login-flowet
- Sprint review-forberedelse og praktisk test

## Dag 1 - Firebase og projektopsætning

Status: implementeret.

Færdigt:

- Firebase-projektet er konfigureret som `fridge-tracker-9bd57`.
- Android Firebase-konfiguration findes i `android/app/google-services.json`.
- Flutter Firebase options findes i `lib/firebase_options.dart`.
- Android Gradle bruger `com.google.gms.google-services`.
- Firestore security rules findes i `firestore.rules`.
- Firestore indexes-placeholder findes i `firestore.indexes.json`.
- Appen bruger Firestore database-id `default` via `FirestoreDatabase`.
- Firebase CLI deploy-konfiguration findes i `firebase.deploy.json`.

## Dag 2 - Auth-flow

Status: implementeret.

Færdigt:

- Appen initialiserer Firebase før auth-afhængige screens vises.
- `AuthGate` lytter på `FirebaseAuth.instance.authStateChanges()`.
- Brugere uden aktiv session ser login/opret-konto.
- Brugere med aktiv session sendes til `FridgeOverviewScreen`.
- Kontooprettelse bruger `createUserWithEmailAndPassword`.
- Login bruger `signInWithEmailAndPassword`.
- Logout bruger `FirebaseAuth.signOut`.
- Signup/login sikrer disse Firestore-dokumenter:
  - `users/{uid}`
  - `users/{uid}/fridges/default`

Primær datapath for varer:

```text
users/{uid}/fridges/default/items/{itemId}
```

## Dag 3 - Validering og fejlbeskeder

Status: implementeret.

Færdigt:

- Ugyldig email viser `Ugyldig emailadresse`.
- Adgangskode under 6 tegn viser `Adgangskoden skal være mindst 6 tegn`.
- Eksisterende email viser `Denne email er allerede i brug`.
- Forkert login viser `Email eller adgangskode er forkert`.
- Netværksfejl vises med dansk fejlbesked.
- Login-formularen valideres før Firebase kaldes.

## Dag 4 - Sikkerhed og test

Status: implementeret og manuelt verificeret.

Færdigt:

- Firestore rules kræver login via `request.auth != null`.
- Brugere kan læse og skrive egne køleskabsvarer.
- Brugere kan ikke slette `users/{uid}` eller `fridges/default`.
- Varedokumenter valideres med faste felter og korrekte typer.
- `source` begrænses til `manual`, `scan` eller `barcode`.
- Reglerne understøtter delt køleskab gennem medlemsadgang.
- Der er tilføjet statiske kontrakttests for vigtige Firestore rules.

## Dag 5 - Sprint review og praktisk test

Status: testet og virker.

Praktisk test er gennemført for:

1. Login-skærm og validering.
2. Kontooprettelse og login.
3. Køleskabsoversigt efter login.
4. Manuel tilføjelse af vare.
5. Realtime visning af varer.
6. Farvekodning efter udløbsdato.
7. Redigering af navn, kategori og udløbsdato.
8. Swipe-to-delete med 5 sekunders `Fortryd`.
9. Logout og login igen med samme konto.
10. Platform-/enhedstest af app-flowet.

Konklusion: punkt 5 fra den seneste gap-liste, platform- og enhedstest, er
testet og virker.

## Verifikation

Automatiske checks:

```powershell
.\.tools\flutter-sdk\flutter\bin\flutter.bat analyze --no-pub
.\.tools\flutter-sdk\flutter\bin\flutter.bat test --no-pub
.\.tools\flutter-sdk\flutter\bin\flutter.bat build web --no-pub
```

Relevant testdækning:

- `test/widget_test.dart` tester login-skærm og formularvalidering.
- `test/firestore_rules_contract_test.dart` tester centrale Firestore rules
  som tekstkontrakter.

## Kendte begrænsninger efter Sprint 1

- Emulator-baserede Firestore rules tests kan stadig tilføjes senere.
- Rigtige server-push-notifikationer er ikke et Sprint 1-krav og hører til en
  senere version.
- Opskrifter, standardudløb, OCR/barcode-polering og push-fundament er
  dokumenteret under Andrei Sprint 2.
