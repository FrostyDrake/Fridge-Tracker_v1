# Andrei - Dag 1 til 5

## Dag 1 - Firebase og projektopsætning

Status: implementeret og verificeret.

Færdigt:

- Firebase-projektet er konfigureret som `fridge-tracker-9bd57`.
- Android Firebase-konfiguration findes i `android/app/google-services.json`.
- Flutter Firebase options findes i `lib/firebase_options.dart`.
- Android Gradle bruger `com.google.gms.google-services`.
- Firestore security rules findes i `firestore.rules`.
- Firestore indexes-placeholder findes i `firestore.indexes.json`.
- Appen bruger Firestore database-id `default` via `FirestoreDatabase`.
- Firebase CLI deploy-konfiguration til den navngivne database findes i `firebase.deploy.json`.

Firebase Console-status:

- `Email/Password` er slået til under Authentication.
- Cloud Firestore databasen `default` findes.
- Firestore rules er deployet og verificeret.
- Android package matcher `com.example.fridge_tracker`.

Deploy-kommando:

```powershell
npx firebase-tools deploy --only firestore:rules,firestore:indexes --project fridge-tracker-9bd57 --config firebase.deploy.json
```

## Dag 2 - Auth-flow

Status: implementeret.

Færdigt:

- Appen initialiserer Firebase før auth-afhængige screens vises.
- `AuthGate` lytter på `FirebaseAuth.instance.authStateChanges()`.
- Brugere der ikke er logget ind ser login/opret-konto UI.
- Brugere der er logget ind sendes til køleskabsoversigten med deres Firebase Auth UID.
- Kontooprettelse bruger `createUserWithEmailAndPassword`.
- Login bruger `signInWithEmailAndPassword`.
- Logout bruger `FirebaseAuth.signOut`.
- Signup/login opretter disse Firestore-dokumenter:
  - `users/{uid}`
  - `users/{uid}/fridges/default`

Data path for varer:

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

## Dag 4 - Sikkerhed og test

Status: implementeret, deployet og manuelt verificeret.

Færdigt:

- Firestore rules kræver login via `request.auth != null`.
- Brugere kan kun læse/skrive deres egen path med `request.auth.uid == userId`.
- Brugere kan ikke slette `users/{uid}` eller `fridges/default`.
- Varedokumenter valideres med faste felter og korrekte typer.
- `source` begrænses til `manual`, `scan` eller `barcode`.
- Reglerne er deployet til Firestore databasen `default`.
- Sikkerhed er testet med flere brugere, så brugere kun ser egne varer.

## Dag 5 - Sprint review-forberedelse

Status: klar til demo.

Demo-flow:

1. Åbn appen.
2. Vis login-skærmen.
3. Opret en ny konto med email/adgangskode.
4. Vis at brugeren sendes til køleskabsoversigten.
5. Tilføj en vare manuelt.
6. Vis at varen dukker op i oversigten.
7. Rediger navn, kategori eller udløbsdato fra dropdown/udvidet varevisning.
8. Slet varen med swipe og vis 5 sekunders `Fortryd`.
9. Vis stregkodescanner eller OCR-scanner som ekstra funktion.
10. Log ud og log ind igen med samme konto.
11. Vis at brugerens egne data stadig vises.

Funktioner klar til sprint review:

- Login, opret konto og logout.
- User-specific Firestore-data.
- Manuel tilføjelse af varer.
- Realtime køleskabsoversigt.
- Farvekodning efter udløbsdato.
- Redigering af varedata.
- Swipe-to-delete med 5 sekunders fortryd.
- Barcode-scanning med Open Food Facts fallback.
- OCR-scanning med forslag til varenavn og udløbsdato.

Kendte begrænsninger:

- Push-notifikationer er ikke implementeret endnu.
- Lokal `data/default_expiry_days.json` findes, men er ikke koblet på appens udløbsdato-logik endnu.
- Barcode/OCR bruger stadig fallback-udløb på 7 dage, hvis der ikke findes en dato.
- Opskriftsforslag er ikke implementeret endnu.
- Delt køleskab, statistik og indkøbsliste er ikke implementeret endnu.

Verifikationskommandoer:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```
