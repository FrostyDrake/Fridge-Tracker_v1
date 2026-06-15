# Fridge Tracker

Fridge Tracker er en Flutter-mobilapp, der hjælper brugere med at reducere
madspild ved at give et løbende overblik over, hvad der ligger i køleskabet,
hvornår varerne udløber, og hvad der bør bruges først.

Appen henvender sig primært til studerende og unge voksne med begrænset
madbudget, travl hverdag og stor erfaring med apps. Den kan også bruges af
familier, der handler ind til flere dage ad gangen og har brug for et enkelt
overblik.

## Kerneidé

Appen understøtter login, køleskabsoversigt, manuel tilføjelse, redigering,
slet/fortryd, kamerascanning, stregkodeopslag via Open Food Facts, lokale
standardudløbsdatoer, opskriftsforslag og et fundament for delt køleskab og
notifikationer.

## Team

| Navn | Scrum-rolle | Teknisk ansvar |
| ---- | ----------- | -------------- |
| Andrei | Scrum Master | Backend, Firebase Auth, FCM |
| Azad | Product Owner | Flutter-frontend, ML Kit |
| Dylan | Developer | Firestore-database, datamodel |

## Teknologistack

| Lag | Teknologi | Begrundelse |
| --- | --------- | ----------- |
| App | Flutter / Dart | Crossplatform-app til Android og iOS |
| Database | Firebase Firestore | Realtidssynkronisering og offline cache |
| Auth | Firebase Authentication | Sikker login med email/adgangskode |
| Notifikationsfundament | Lokale notifikationer + Firebase Cloud Messaging | Reminders lokalt og FCM-token til senere server-push |
| Billedgenkendelse | ML Kit on-device | Objektgenkendelse uden netværkskrav |
| Produktdata | Open Food Facts API | Gratis produktdatabase med dagligvarer |
| Standardudløbsdatoer | Lokal JSON-database | Hurtigt opslag for almindelige fødevarer |
| Versionsstyring | GitHub | Feature branches og pull requests |

I Sprint 1 kommunikerer Flutter direkte med Firestore via Firebase SDK. En
separat Node.js/Express-backend tilføjes kun, hvis et senere sprint skaber et
reelt behov for det.

## Sprint 1-mål

Byg et fungerende login-flow og en grundlæggende køleskabsoversigt med CRUD.

Sprint 1 user stories:

| User story | Points | Nøgleopgaver |
| ---------- | ------ | ------------ |
| US04 - Login | 5 | Firebase-opsætning, auth-flow, validering, security rules |
| US02 - Oversigt | 3 | Firestore-datamodel, ListView UI, farvekodning, realtid |
| US05 - Manuel tilføjelse | 3 | Formular-screen, Firestore-skrivning, navigation |
| US08 - Slet vare | 2 | Swipe-to-delete, Firestore delete, 5 sekunders fortryd |

## Datamodel

```
User
├── Fridge
│   └── FridgeItem
│       ├── id
│       ├── name
│       ├── category
│       ├── addedDate
│       ├── expiryDate
│       ├── source
│       └── imageUrl
└── householdId

households
├── name
├── createdAt
├── members
│    └── member
│         ├── role
│         └── email
├── sharedFridge
│   └── FridgeItem
│       ├── id
│       ├── name
│       ├── category
│       ├── addedDate
│       ├── expiryDate
│       ├── source
│       └── imageUrl
└── ownerId
```

## Farvekodning for udløb

| Farve | Betydning |
| ----- | --------- |
| Rød | Udløber om 3 dage eller mindre |
| Orange | Udløber om 4-7 dage |
| Grøn | Mere end 7 dage tilbage |

## Kravspecifikation

Projektet tager udgangspunkt i kravspecifikationen
`Fridge_Tracker_Kravspecifikation.docx - Documente Google.pdf`.
PDF'en ligger i repoets `docs`-mappe:
[Kravspecifikation](docs/Fridge_Tracker_Kravspecifikation.docx%20-%20Documente%20Google.pdf).

Kravspecifikationen beskriver problemformulering, målgruppe, use cases,
funktionelle krav, ikke-funktionelle krav, designkrav og datamodel. Den aktuelle
version af appen dækker login, køleskabsoversigt, manuel tilføjelse,
scanning/OCR, Open Food Facts-opslag, standardudløb fra lokal JSON,
opskrifter, slet/fortryd og et fundament for delt køleskab.

Udløbsnotifikationer er markeret som en senere version i kravspecifikationen.
Repoet indeholder derfor et notifikations- og FCM-tokenfundament, men ikke en
fuld server-push-løsning.

## Estimeret tidsplan - 5 uger

| Uge | Fokus | Arbejde | Resultat |
| --- | ----- | ------- | -------- |
| Uge 1 | Kravspecifikation og planlægning | Problemformulering, målgruppe, use cases, datamodel, MoSCoW-prioritering og teknologivalg | Grundlag for projektet og kravspecifikation |
| Uge 2 | Firebase og login | Firebase setup, Authentication, login/opret konto/logout, Firestore-struktur og security rules | Brugere kan oprette konto, logge ind og have egne data |
| Uge 3 | Køleskabsfunktioner | Køleskabsoversigt, manuel tilføjelse, redigering, sletning med fortryd, farvekodning og sortering | Appen har fungerende CRUD-flow for varer |
| Uge 4 | Scanning og smarte funktioner | Barcode-scanning, OCR, Open Food Facts, standardudløb fra JSON, opskriftsforslag og delt køleskab foundation | Appen kan foreslå udløbsdatoer og opskrifter baseret på varer |
| Uge 5 | Test, dokumentation og polish | Flere unit/widget tests, opdatering af Andrei Sprint 1/2 docs, kravspec-alignment, analyse/test/build og praktisk platformstest | Projektet er mere stabilt, dokumenteret og klarere til aflevering/demo |

## Dokumentation

- [Kravspecifikation](docs/Fridge_Tracker_Kravspecifikation.docx%20-%20Documente%20Google.pdf)
- [Projektoverblik](docs/project-overview.md)
- [Sprint 1-backlog](docs/sprint-1.md)
- [Andrei sprint 1](docs/andrei-sprint-1.md)
- [Andrei sprint 2](docs/andrei-sprint-2.md)
