# Sprint 1

## Sprintmål

Byg fungerende Firebase Authentication og en grundlæggende køleskabsoversigt med
oprettelse, læsning og sletning af varer.

## Sprint Backlog

| User story | Points | Nøgleopgaver | Ansvarlig |
| ---------- | ------ | ------------ | --------- |
| US04 - Login | 5 | Firebase-opsætning, auth-flow, validering, security rules | Andrei + Dylan |
| US02 - Oversigt | 3 | Firestore-datamodel, ListView UI, farvekodning, realtidsopdatering | Dylan + Azad |
| US05 - Manuel tilføjelse | 3 | Formular-screen, Firestore-skrivning, navigation | Azad + Dylan |
| US08 - Slet vare | 2 | Swipe-to-delete, Firestore delete, 5 sekunders fortryd | Azad |

Total: 13 story points.

## Funktionelle krav

| ID | Krav |
| -- | ---- |
| FK01 | Systemet skal give mulighed for at oprette konto med email/adgangskode samt logge ind og ud med validering og fejlbeskeder |
| FK02 | Systemet skal vise alle varer med navn, kategori og udløbsdato, farvekodet efter udløbsstatus |
| FK03 | Systemet skal give mulighed for manuel tilføjelse via formular; tomme felter accepteres ikke |
| FK04 | Systemet skal give mulighed for sletning af vare med 5 sekunders fortrydmulighed |
| FK05 | Systemet skal sende push-notifikation med varenavn og udløbsdato, når en vare udløber inden for 2 dage |

## Ikke-funktionelle krav

| ID | Kategori | Krav |
| -- | -------- | ---- |
| IFK01 | Sikkerhed | Brug HTTPS, Firestore security rules, og gem aldrig adgangskoder i klartekst |
| IFK02 | Performance | Oversigten indlæses inden for 2 sekunder og fungerer offline med cachede data |
| IFK03 | Brugervenlighed | Første vare kan tilføjes inden for 60 sekunder efter kontooprettelse; WCAG 2.1 AA følges |
| IFK04 | Skalerbarhed | Datamodellen understøtter delt køleskab uden omskrivning af eksisterende struktur |
| IFK05 | Platformskompatibilitet | Appen fungerer på Android API 26+ og iOS 13+ uden funktionelle forskelle |

## Acceptkriterier

### US04 - Login

- Gyldig email og adgangskode opretter en konto og sender brugeren til oversigten.
- Ugyldig email viser "Ugyldig emailadresse".
- Adgangskode under 6 tegn viser en fejlbesked.
- Eksisterende email viser "Denne email er allerede i brug".
- Login med eksisterende konto viser brugerens egne data.
- Logout forhindrer adgang til data, indtil brugeren logger ind igen.

### US02 - Køleskabsoversigt

- Alle varer vises efter login.
- Rød markering bruges, når der er 1-2 dage tilbage.
- Gul markering bruges, når der er 3-5 dage tilbage.
- Grøn markering bruges, når der er 6 eller flere dage tilbage.
- Tom oversigt viser "Dit køleskab er tomt - tilføj din første vare".
- Oversigten opdateres i realtid uden manuel genindlæsning.

### US03 - Notifikation

- Notifikation sendes præcis 2 dage før udløb.
- Notifikationen indeholder varenavn og udløbsdato.
- Der sendes ingen notifikation for varer med mere end 2 dage tilbage.
- Tryk på notifikationen åbner appen og viser varen.
- Hvis notifikationer er slået fra, sendes ingen notifikation, men rød markering vises stadig i oversigten.

## Scrum-opsætning

Daily Scrum:

- Hvad lavede jeg siden sidst?
- Hvad laver jeg i dag?
- Hvad blokerer mig?

Sprint Review:

- Demo på rigtig enhed
- Gennemgang af acceptkriterier
- Vurdering af sprint backlog
- Opdatering af product backlog
- Kort retrospektiv
