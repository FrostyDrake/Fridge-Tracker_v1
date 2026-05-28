# Project Overview

## What Is Fridge Tracker?

Fridge Tracker is a mobile application that helps users reduce food waste by
giving them a live overview of the contents of their fridge. Users can scan
products with the camera, confirm detected items, and store them with an
intelligent expiry date.

The app sends notifications when items are close to expiry and can later suggest
recipes based on the items that should be used first.

## Problem

Many households throw food away because they lose track of what they own and
when it expires. Existing solutions often require too much manual registration.
Fridge Tracker reduces that effort by using camera scanning, barcode lookup, and
default expiry dates.

## Target Group

Primary target group:

- Students and young adults aged 18-30
- People living alone or in shared housing
- Users with limited food budgets and busy routines

Secondary target group:

- Families that shop for a full week at a time
- Households with many fridge items to track

## Architecture

```text
Flutter App
├── Firebase Auth - login/logout
├── Firebase Firestore - read/write fridge data
├── Firebase Cloud Messaging - push notifications
├── ML Kit on-device - image recognition
└── Open Food Facts API - product name and category
```

Important decision for Sprint 1:

Flutter communicates directly with Firestore through the Firebase SDK. No
separate backend is planned for Sprint 1.

## Scan Flow

1. User opens the camera in the app.
2. ML Kit tries visual object recognition.
3. If a barcode is detected, the app calls the Open Food Facts API.
4. Product name and category are returned.
5. The app looks up a default expiry time in the local JSON database.
6. User confirms or adjusts the expiry date.
7. Item is added to Firestore.

## MoSCoW Prioritization

### Must Have

- Camera scan with automatic item recognition
- Automatic expiry date from local JSON database
- Manual item creation
- Fridge overview with expiry color coding
- Push notification when an item expires within 2 days
- Local data persistence between sessions
- Secure login and account creation

### Should Have

- Item categories
- Sorting by expiry date
- Edit existing item
- Recipe suggestions through an external API
- Cloud backup and synchronization

### Could Have

- Shared fridge with household members
- Food waste statistics over time
- Shopping list based on items that are nearly missing
- Filtering by category or expiry status
- AI-based meal plans

### Won't Have This Time

- Smart fridge IoT integration
- Social feed or sharing recipes with friends

## Product Backlog

| ID | User story | Priority | Points |
| -- | ---------- | -------- | ------ |
| US01 | As a user, I want to scan an item with the camera so it is automatically added | Must | 8 |
| US02 | As a user, I want to see all fridge items in one overview | Must | 3 |
| US03 | As a user, I want to receive a notification when an item expires within 2 days | Must | 5 |
| US04 | As a user, I want to create an account and log in securely | Must | 5 |
| US05 | As a user, I want to manually add an item with name and expiry date | Should | 3 |
| US06 | As a user, I want to see items sorted by expiry date | Should | 2 |
| US07 | As a user, I want recipe suggestions based on items that expire soon | Should | 8 |
| US08 | As a user, I want to delete an item from the fridge | Should | 2 |
| US09 | As a user, I want to share my fridge with household members | Could | 8 |
| US10 | As a user, I want to see food waste statistics over time | Could | 5 |

## Technical Risks

| Risk | Problem | Mitigation |
| ---- | ------- | ---------- |
| Firestore security rules | Misconfiguration can expose user data | Write and test rules from day one |
| Sprint 1 dependencies | Overview, add, and delete depend on auth | Set Firebase up together on day one and build UI in parallel |
| Image recognition | ML Kit may fail on unknown or generic items | Always provide manual fallback |
| Date format | Inconsistent dates can break sorting and notifications | Standardize on ISO 8601 or Firestore Timestamp |
