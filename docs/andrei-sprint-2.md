# Andrei - Sprint 2

Status: implementeret, testet og dokumenteret.

## Formål

Sprint 2 udvidede Fridge Tracker med opskriftsforslag, standardudløbslogik,
notifikationsfundament og mere testdækning omkring de integrationer, der er
vigtige i kravspecifikationen.

## Dag 1 - Fundament for opskrifts-API

Status: implementeret.

Færdigt:

- TheMealDB er valgt som opskrifts-API.
- `RecipeService` er tilføjet med funktioner til:
  - søgning efter opskrifter ud fra én ingrediens med `filter.php?i=...`
  - hentning af fulde opskriftsdetaljer med `lookup.php?i=...`
  - mapping af almindelige danske køleskabsvarer til TheMealDB-ingredienser
- Opskriftsopslag logges fra forslagsskærmen med:
  - varenavn fra køleskabet
  - matchet ingrediens
  - antal opskrifter fra API'et
  - eventuelle fejl ved opslag

## Dag 2 - Opskriftsforslag

Status: implementeret.

Færdigt:

- `RecipeSuggestionsScreen` er tilføjet.
- Navigation er tilføjet fra køleskabsoversigten.
- Skærmen læser varer fra det aktive køleskab, også når brugeren ser et delt
  køleskab.
- Varer med udløbsdato inden for 0-3 dage bruges som input til forslag.
- Opskriftskort viser billede, titel, kildevare, matchet ingrediens og
  udløbsstatus.
- Skærmen håndterer:
  - manglende køleskabsdata
  - ingen varer der udløber snart
  - ingen fundne opskrifter
  - Firestore-fejl
  - fejl fra opskrifts-API'et

## Dag 3 - Polering og integration

Status: implementeret.

Færdigt:

- Loading states er tilføjet for Firestore, opskriftssøgning og
  opskriftsdetaljer.
- Retry-knapper er tilføjet ved fejl i opskriftssøgning og detaljer.
- Opskriftskort åbner en detaljevisning med billede, ingredienser,
  fremgangsmåde, område, kategori og markerbare kilde-/videolinks.
- TheMealDB-begrænsninger er dokumenteret.

## Standardudløb og scanning

Status: implementeret.

Færdigt:

- `data/default_expiry_days.json` er registreret som Flutter asset.
- `DefaultExpiryService` læser den lokale JSON-database.
- Manuel tilføjelse bruger automatisk standardudløbsdato, men brugeren kan
  stadig vælge dato manuelt.
- Barcode-flowet bruger Open Food Facts og derefter standardudløb.
- OCR-flowet bruger funden dato, hvis OCR finder en holdbarhedsdato, ellers
  lokal standardudløbsdato.
- Open Food Facts fallback håndterer ukendte produkter og manglende felter.

## Notifikations- og push-fundament

Status: service/UI-fundament implementeret.

Færdigt:

- `ExpiryNotificationService` planlægger lokale reminders.
- Appen initialiserer lokale notifikationer ved startup.
- Android 13+ notifikationstilladelse er tilføjet i manifestet.
- Køleskabsoversigten synkroniserer reminders, når item-streamen opdateres.
- Varer får en reminder 2 dage før udløbsdato kl. 09:00.
- Hvis varen allerede er inden for reminder-vinduet, planlægges en reminder kort
  efter næste sync, så flowet kan testes i appen.
- Udløbne varer udelades.
- `PushNotificationService` kan registrere FCM-token for brugeren.
- `PushNotificationsScreen` forklarer status og backend-begrænsningen.

Bemærk: kravspecifikationen markerer udløbsnotifikationer som en senere version.
Det nuværende arbejde er derfor et fundament, ikke en fuld server-push-løsning.

## Ekstra testdækning

Status: implementeret.

Testdækning er udvidet til:

- `DefaultExpiryService`: direkte kategori, keyword-match, kategori-substring,
  fallback og asset-backed JSON-opslag.
- `OcrProductService`: kendte produktord, fallback-produktlinjer,
  støjfiltrering og datoparsing.
- `OpenFoodFactsService`: API-kald, produktmapping, fallback-felter og
  fejlstatusser.
- `RecipeService`: ingrediensmapping, fallback-ingredienser, API-kald, limit,
  ugyldige rows, detaljer og fejl.
- `ExpiryNotificationService`: præcis 2-dages reminder, reminders i dag,
  reminder-vindue, sortering, udløbne varer og stabile notification IDs.
- `widget_test.dart`: login-skærm og formularvalidering.
- `firestore_rules_contract_test.dart`: centrale Firestore rules-kontrakter.

## Praktisk test

Status: testet og virker.

Den tidligere åbne gap om platform-/enhedstest er lukket:

- Login-flow virker.
- Manuel varetilføjelse virker.
- Køleskabsoversigten opdateres.
- Barcode/OCR-flowet er testet praktisk.
- Opskriftsforslag kan åbnes fra oversigten.
- Delt køleskab kan vælges fra oversigten, når adgang findes.
- App-flowet er testet på målplatform/test-enhed og virker.

## Kendte begrænsninger

- Den gratis v1 API fra TheMealDB understøtter kun filtrering på én ingrediens.
  Multi-ingredient filtering kræver supporter key og v2 API.
- Ukendte varer kan give nul opskrifter, fordi mappingen falder tilbage til det
  første brugbare produktord.
- Opskriftssøgning kræver netværksadgang. Der er ingen persistent recipe cache.
- Opskriftslinks vises som markerbar tekst og åbnes ikke i ekstern browser endnu.
- Real push kræver stadig en Cloud Function eller anden sikker backend.
- Notifikation-tap åbner endnu ikke direkte en bestemt vare.
- Delt køleskab har direkte deling via email, men ikke fuldt invite/accept-flow,
  roller eller fjern-medlem UI.
- Emulator-baserede Firestore rules tests kan stadig tilføjes som næste
  kvalitetstrin.

## Verifikation

Kørt efter seneste ændringer:

```powershell
.\.tools\flutter-sdk\flutter\bin\flutter.bat analyze --no-pub
.\.tools\flutter-sdk\flutter\bin\flutter.bat test --no-pub
.\.tools\flutter-sdk\flutter\bin\flutter.bat build web --no-pub
```
