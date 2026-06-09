# Fridge Tracker

Fridge Tracker er en Flutter-mobilapp, der hjælper brugere med at reducere
madspild ved at give et løbende overblik over, hvad der ligger i køleskabet,
hvornår varerne udløber, og hvad der bør bruges først.

Appen henvender sig primært til studerende og unge voksne med begrænset
madbudget, travl hverdag og stor erfaring med apps. Den kan også bruges af
familier, der handler ind til flere dage ad gangen og har brug for et enkelt
overblik.

## Kerneidé

I Sprint 1 kan brugeren tilføje varer manuelt. Senere skal appen understøtte
kamerascanning, stregkodeopslag via Open Food Facts, intelligente
standardudløbsdatoer, udløbsnotifikationer og opskriftsforslag.

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
| Push-notifikationer | Firebase Cloud Messaging | Push-notifikationer til Android og iOS |
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
└── household
    ├── name
	└── role

households
├── name
├── createdAt
├── members
│    └── member
│         ├── role
│         └── email
└── sharedFridge
    └── FridgeItem
    ├── id
    ├── name
    ├── category
    ├── addedDate
    ├── expiryDate
    ├── source
    └── imageUrl
```

## Farvekodning for udløb

| Farve | Betydning |
| ----- | --------- |
| Rød | Udløber om 1-2 dage |
| Gul | Udløber om 3-5 dage |
| Grøn | Mere end 5 dage tilbage |

## Dokumentation

- [Projektoverblik](docs/project-overview.md)
- [Sprint 1-backlog](docs/sprint-1.md)
- [Andrei dag 1-5](docs/andrei-day-1-5.md)
