# Fridge Tracker

Fridge Tracker is a Flutter mobile app that helps users reduce food waste by
keeping a live overview of what is in their fridge, when items expire, and what
should be used first.

The app is aimed primarily at students and young adults who have limited food
budgets, busy routines, and are comfortable using mobile apps. It also supports
families who shop for many items at once and need a simple overview.

## Core Idea

Users can add fridge items manually in Sprint 1. Later, the app will support
camera scanning, barcode lookup through Open Food Facts, intelligent default
expiry dates, expiry notifications, and recipe suggestions.

## Team

| Name | Scrum role | Technical responsibility |
| ---- | ---------- | ------------------------ |
| Andrei | Scrum Master | Backend, Firebase Auth, FCM |
| Azad | Product Owner | Flutter frontend, ML Kit |
| Dylan | Developer | Firestore database, data model |

## Technology Stack

| Layer | Technology | Reason |
| ----- | ---------- | ------ |
| App | Flutter / Dart | Cross-platform Android and iOS app |
| Database | Firebase Firestore | Realtime sync and offline cache |
| Auth | Firebase Authentication | Secure email/password login |
| Push notifications | Firebase Cloud Messaging | Push notifications for Android and iOS |
| Image recognition | ML Kit on-device | Object recognition without network dependency |
| Product data | Open Food Facts API | Free product database with grocery products |
| Default expiry dates | Local JSON database | Fast lookup for common food expiry defaults |
| Version control | GitHub | Feature branches and pull requests |

Sprint 1 uses Flutter directly against Firebase through the Firebase SDK. A
separate Node.js/Express backend should only be added if a later sprint creates
a real need for it.

## Sprint 1 Goal

Build a working authentication flow and a basic fridge overview with CRUD.

Sprint 1 user stories:

| User story | Points | Main tasks |
| ---------- | ------ | ---------- |
| US04 - Login | 5 | Firebase setup, auth flow, validation, security rules |
| US02 - Overview | 3 | Firestore data model, ListView UI, color coding, realtime updates |
| US05 - Manual add | 3 | Form screen, Firestore write, navigation flow |
| US08 - Delete item | 2 | Swipe-to-delete, Firestore delete, 5 second undo |

## Data Model

```text
User
└── Fridge
    └── FridgeItem
        ├── id
        ├── name
        ├── category
        ├── addedDate
        ├── expiryDate
        ├── source
        └── imageUrl
```

The structure should support a later shared fridge feature without requiring a
full rewrite.

## Expiry Status Colors

| Color | Meaning |
| ----- | ------- |
| Red | Expires in 1-2 days |
| Yellow | Expires in 3-5 days |
| Green | More than 5 days left |

## Documentation

- [Project overview](docs/project-overview.md)
- [Sprint 1 backlog](docs/sprint-1.md)
- [GitHub permissions guide](docs/github-permissions.md)
