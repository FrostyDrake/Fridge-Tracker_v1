# Andrei - Sprint 2

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
- Navigation er tilføjet fra app baren på køleskabsoversigten.
- Skærmen læser den indloggede brugers køleskabsvarer via det eksisterende
  Firestore item-stream.
- Varer med udløbsdato inden for 0-3 dage bruges som input til opskriftsforslag.
- Opskriftskort viser billede, titel, kildevare fra køleskabet, matchet
  ingrediens og udløbsstatus.
- Skærmen håndterer:
  - manglende køleskabsdata
  - ingen varer der udløber snart
  - ingen fundne opskrifter
  - Firestore-fejl
  - fejl fra opskrifts-API'et

## Dag 3 - Polering og integration

Status: implementeret og lokalt verificeret.

Færdigt:

- Loading states er tilføjet for Firestore, opskriftssøgning og
  opskriftsdetaljer.
- Retry-knapper er tilføjet ved fejl i opskriftssøgning og hentning af detaljer.
- Opskriftskort åbner en detaljevisning med billede, ingredienser,
  fremgangsmåde, område, kategori og markerbare kilde-/videolinks, når
  TheMealDB leverer dem.
- Unit tests er tilføjet for mapping i opskriftsservicen og parsing af
  API-respons.

## Notifikationsfundament

Status: implementeret.

Færdigt:

- `ExpiryNotificationService` er tilføjet.
- Appen initialiserer lokale notifikationer ved startup.
- Android 13+ notifikationstilladelse er tilføjet i manifestet.
- Køleskabsoversigten synkroniserer reminders, når brugerens Firestore item
  stream opdateres.
- Varer får en reminder 2 dage før udløbsdato kl. 09:00.
- Hvis varen allerede er inden for reminder-vinduet, planlægges en reminder kort
  efter næste sync, så flowet kan testes i appen.
- Udløbne varer udelades.
- Unit tests er tilføjet for reminder-planlægning og stabile notification IDs.

Kendte begrænsninger:

- Den gratis v1 API fra TheMealDB understøtter kun filtrering på én ingrediens.
  Multi-ingredient filtering kræver supporter key og v2 API.
- Appen bruger en lille lokal mapping fra danske varenavne til engelske
  ingredienser. Ukendte varer falder tilbage til det første brugbare produktord
  og kan derfor give nul opskrifter.
- Opskriftsforslag udelader i øjeblikket udløbne varer og varer uden
  udløbsdato.
- Opskriftslinks vises som markerbar tekst. Appen åbner dem ikke i en ekstern
  browser endnu, fordi `url_launcher` ikke er tilføjet.
- Opskriftssøgning kræver netværksadgang. Der er ingen persistent recipe cache.
- Notifikationerne er lokale scheduled notifications. Der er ikke tilføjet en
  server/Cloud Function, der sender Firebase Cloud Messaging push-beskeder.
- Scheduled expiry reminders er kun aktive på Android/iOS. Web buildet virker
  stadig, men web understøtter ikke samme scheduled notification-flow.

Verifikation:

```powershell
.\.tools\flutter-sdk\flutter\bin\flutter.bat analyze
.\.tools\flutter-sdk\flutter\bin\flutter.bat test
.\.tools\flutter-sdk\flutter\bin\flutter.bat build web
```
