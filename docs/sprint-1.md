# Sprint 1

## Sprint Goal

Build working Firebase authentication and a basic fridge overview with create,
read, and delete functionality.

## Sprint Backlog

| User story | Points | Key tasks | Owner |
| ---------- | ------ | --------- | ----- |
| US04 - Login | 5 | Firebase setup, auth flow, validation, security rules | Andrei + Dylan |
| US02 - Overview | 3 | Firestore data model, ListView UI, color coding, realtime updates | Dylan + Azad |
| US05 - Manual add | 3 | Form screen, Firestore write, navigation flow | Azad + Dylan |
| US08 - Delete item | 2 | Swipe-to-delete, Firestore delete, 5 second undo | Azad |

Total: 13 story points.

## Functional Requirements

| ID | Requirement |
| -- | ----------- |
| FK01 | The system must allow users to create an account with email/password and log in/out with validation and error messages |
| FK02 | The system must show all items with name, category, and expiry date, color-coded by expiry status |
| FK03 | The system must allow manual item creation through a form; empty fields are not accepted |
| FK04 | The system must allow item deletion with a 5 second undo option |
| FK05 | The system must send a push notification with item name and expiry date when an item expires within 2 days |

## Non-Functional Requirements

| ID | Category | Requirement |
| -- | -------- | ----------- |
| IFK01 | Security | Use HTTPS, Firestore security rules, and never store passwords in plain text |
| IFK02 | Performance | Overview loads within 2 seconds and works offline with cached data |
| IFK03 | Usability | First item can be added within 60 seconds after account creation; WCAG 2.1 AA is followed |
| IFK04 | Scalability | Data model supports shared fridges without rewriting the existing structure |
| IFK05 | Compatibility | Works on Android API 26+ and iOS 13+ without functional differences |

## Acceptance Criteria

### US04 - Login

- Valid email and password creates an account and sends the user to the overview.
- Invalid email shows "Ugyldig emailadresse".
- Password shorter than 6 characters shows an error message.
- Existing email shows "Denne email er allerede i brug".
- Login with an existing account shows the user's own data.
- Logout prevents access to data until the user logs in again.

### US02 - Fridge Overview

- All items are shown after login.
- Red marking is used when 1-2 days remain.
- Yellow marking is used when 3-5 days remain.
- Green marking is used when 6 or more days remain.
- Empty overview shows "Dit køleskab er tomt - tilføj din første vare".
- Overview updates in realtime without manual reload.

### US03 - Notification

- Notification is sent exactly 2 days before expiry.
- Notification contains item name and expiry date.
- No notification is sent for items with more than 2 days remaining.
- Pressing the notification opens the app and shows the item.
- If notifications are disabled, no notification is sent, but red overview marking still appears.

## Scrum Setup

Daily Scrum:

- What did I do since last time?
- What am I doing today?
- What is blocking me?

Sprint Review:

- Demo on a real device
- Review acceptance criteria
- Evaluate sprint backlog
- Update product backlog
- Short retrospective
