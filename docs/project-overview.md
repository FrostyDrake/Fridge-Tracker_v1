# Projektoverblik

## Hvad er Fridge Tracker?

Fridge Tracker er en mobilapplikation, der hjælper brugere med at reducere
madspild ved at give et løbende overblik over køleskabets indhold. Brugeren kan
scanne varer med kameraet, bekræfte det fundne produkt og gemme varen med en
intelligent udløbsdato.

Appen foreslår opskrifter baseret på varer, der bør bruges først, og har et
fundament for notifikationer. Fuld server-push er markeret som en senere version
i kravspecifikationen.

## Problem

Mange husholdninger smider mad ud, fordi de mister overblikket over, hvad de
har, og hvornår det udløber. Eksisterende løsninger kræver ofte for meget manuel
registrering. Fridge Tracker reducerer brugerindsatsen med kamerascanning,
stregkodeopslag og standardudløbsdatoer.

## Målgruppe

Primær målgruppe:

- Studerende og unge voksne i alderen 18-30 år
- Personer der bor alene eller i kollektiv
- Brugere med begrænset madbudget og travl hverdag

Sekundær målgruppe:

- Familier der handler ind til en hel uge ad gangen
- Husholdninger med mange køleskabsvarer at holde styr på

## Arkitektur

```text
Flutter App
├── Firebase Auth - login/logout
├── Firebase Firestore - læs/skriv køleskabsdata
├── Firebase Cloud Messaging - push-notifikationer
├── ML Kit on-device - billedgenkendelse
└── Open Food Facts API - produktnavn og kategori
```

Vigtig beslutning for Sprint 1:

Flutter kommunikerer direkte med Firestore via Firebase SDK. Der er ikke planlagt
en separat backend i Sprint 1.

## Scan-flow

1. Brugeren åbner kameraet i appen.
2. ML Kit forsøger visuel objektgenkendelse.
3. Hvis en stregkode detekteres, kalder appen Open Food Facts API.
4. Produktnavn og kategori returneres.
5. Appen slår standardudløbstid op i den lokale JSON-database.
6. Brugeren bekræfter eller justerer udløbsdatoen.
7. Varen tilføjes til Firestore.

## MoSCoW-prioritering

### Must Have

- Kamerascan med automatisk varegenkendelse
- Automatisk udløbsdato fra lokal JSON-database
- Manuel tilføjelse af vare
- Køleskabsoversigt med farvekodning
- Lokal datalagring mellem sessioner
- Sikker login og oprettelse af konto

### Should Have

- Kategorisering af varer
- Sortering efter udløbsdato
- Redigering af eksisterende vare
- Opskriftsforslag via eksternt API
- Cloud-backup og synkronisering
- Delt køleskab med godkendte husstandsmedlemmer

### Could Have

- Madspildsstatistik over tid
- Indkøbsliste baseret på varer der snart mangler
- Filtrering efter kategori eller udløbsstatus
- AI-baserede madplaner

### Senere version

- Udløbsnotifikationer med server-push og direkte navigation til varen

### Won't Have denne gang

- Smart køleskab IoT-integration
- Socialt feed eller deling af opskrifter med venner

## Product Backlog

| ID | User story | Prioritet | Points |
| -- | ---------- | --------- | ------ |
| US01 | Som bruger vil jeg scanne en vare med kameraet, så den automatisk tilføjes | Must | 8 |
| US02 | Som bruger vil jeg se alle varer i køleskabet i én oversigt | Must | 3 |
| US03 | Som bruger vil jeg modtage en notifikation, når en vare udløber inden for 2 dage | Senere | 5 |
| US04 | Som bruger vil jeg oprette en konto og logge ind sikkert | Must | 5 |
| US05 | Som bruger vil jeg manuelt tilføje en vare med navn og udløbsdato | Should | 3 |
| US06 | Som bruger vil jeg se varer sorteret efter udløbsdato | Should | 2 |
| US07 | Som bruger vil jeg få opskriftsforslag baseret på varer, der snart udløber | Should | 8 |
| US08 | Som bruger vil jeg slette en vare fra køleskabet | Should | 2 |
| US09 | Som bruger vil jeg dele mit køleskab med mine husstandsmedlemmer | Should | 8 |
| US10 | Som bruger vil jeg se statistik over mit madspild over tid | Could | 5 |

## Tekniske risici

| Risiko | Problem | Reduktion |
| ------ | ------- | --------- |
| Firestore security rules | Fejlkonfiguration kan eksponere brugerdata | Skriv og test rules fra dag ét |
| Sprint 1-afhængigheder | Oversigt, tilføjelse og sletning afhænger af auth | Sæt Firebase op sammen dag ét, og byg UI parallelt |
| Billedgenkendelse | ML Kit kan fejle på ukendte eller generiske varer | Tilbyd altid manuel indtastning som fallback |
| Datoformat | Inkonsistente datoer kan ødelægge sortering og notifikationer | Standardiser på ISO 8601 eller Firestore Timestamp |
