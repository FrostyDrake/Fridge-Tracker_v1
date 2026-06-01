# Andrei - Dag 1 til 5

## Dag 1 - Firebase og projektopsætning

Status: implementeret i repoet. Firebase Console skal stadig være korrekt sat op
af projektets ejer.

Færdigt:

- Firebase-projektet er konfigureret som `fridge-tracker-9bd57`.
- Android Firebase-konfiguration findes i `android/app/google-services.json`.
- Flutter Firebase options findes i `lib/firebase_options.dart`.
- Android Gradle bruger `com.google.gms.google-services`.
- Firestore deploy-konfiguration findes i `firebase.json`.
- Firestore security rules findes i `firestore.rules`.
- Firestore indexes-placeholder findes i `firestore.indexes.json`.

Firebase Console-checkliste:

- `Email/Password` er slået til under Authentication.
- Cloud Firestore databasen `(default)` findes.
- Firestore rules deployes fra `firestore.rules`.
- Android package matcher `com.example.fridge_tracker`.

Deploy-kommando:

```powershell
firebase deploy --only firestore:rules,firestore:indexes
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

Status: implementeret og manuelt testet.

Færdigt:

- Ugyldig email viser `Ugyldig emailadresse`.
- Adgangskode under 6 tegn viser `Adgangskoden skal være mindst 6 tegn`.
- Eksisterende email viser `Denne email er allerede i brug`.
- Forkert login viser `Email eller adgangskode er forkert`.
- Netværksfejl vises med dansk fejlbesked.

## Dag 4 - Sikkerhed og test

Status: klar til deploy og review.

Færdigt i repoet:

- Firestore rules kræver login via `request.auth != null`.
- Brugere kan kun læse/skrive deres egen path med `request.auth.uid == userId`.
- Brugere kan ikke slette `users/{uid}` eller `fridges/default`.
- Varedokumenter valideres med faste felter og korrekte typer.
- `source` begrænses til `manual`, `scan` eller `barcode`.
- Appen viser en tydelig fejl, hvis Firestore rules blokerer adgang.

Manuel test før demo:

1. Opret bruger A og tilføj en vare.
2. Log ud.
3. Opret bruger B.
4. Bekræft at bruger B ikke kan se bruger A's varer.
5. Log ind som bruger A igen.
6. Bekræft at bruger A stadig kan se sine egne varer.
7. Test at tilføjelse og sletning stadig virker efter rules er deployet.

## Dag 5 - Sprint review-forberedelse

Status: klar til demo.

Demo-flow:

1. Åbn appen.
2. Vis login-skærmen.
3. Opret en ny konto med email/adgangskode.
4. Vis at brugeren sendes til køleskabsoversigten.
5. Tilføj en vare.
6. Vis at varen dukker op i oversigten.
7. Log ud.
8. Log ind igen med samme konto.
9. Vis at brugerens egne data stadig vises.
10. Log ud igen og forklar at appen ikke viser data uden login.

Kendte begrænsninger til sprint review:

- Push-notifikationer er ikke implementeret endnu.
- Kamerascanning er ikke implementeret endnu.
- Opskriftsforslag er ikke implementeret endnu.
- UI er funktionelt, men Azad kan stadig polere layout og navigation.
- Firebase rules skal deployes, før sikkerhedstesten tæller som færdig i Firebase Console.

Verifikationskommandoer:

```powershell
C:\dev\flutter\bin\flutter.bat analyze
C:\dev\flutter\bin\flutter.bat test
```
