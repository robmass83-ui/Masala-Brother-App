# Masala Brother App

App Android privata per **Roberto** e **Laura**: spese condivise, conguagli e cose da fare.
Sostituisce il file Excel su OneDrive. Distribuzione solo come APK (no Play Store).

## Struttura repository

```
frontend/     # Flutter app (Android, minSdk 26) — UI + logica client
backend/      # Firebase: rules, indexes, storage rules
docs/         # design-reference.html, PROMPT-CURSOR.md, data-model.md
```

> Nota: le cartelle si chiamano `frontend/` e `backend/` (richiesta esplicita).
> Nel prompt originale erano `app/` e `firebase/` — stesso contenuto, nomi diversi.

## Prerequisiti

- Flutter stable (3.24+)
- Android SDK / JDK 17
- Account Firebase di Roberto (Auth Google, Firestore `europe-west`)

## Setup frontend

```bash
cd frontend
flutter pub get
# Configura Firebase (genera file gitignored):
#   dart pub global activate flutterfire_cli
#   flutterfire configure --project=<PROJECT_ID> --platforms=android
# Copia l'esempio se serve solo per compilare senza Firebase reale:
cp lib/firebase_options.example.dart lib/firebase_options.dart
flutter analyze
flutter test
flutter run
```

Package Android: `it.masala.brotherapp`

### Secret / file da non commitare

- `frontend/lib/firebase_options.dart`
- `frontend/android/app/google-services.json`
- `frontend/android/key.properties`, `*.jks` / `*.keystore`

Vedi `.gitignore`.

## Setup backend (Firebase)

```bash
cd backend
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Regole: solo le email in `households/main.memberEmails` possono leggere/scrivere.
Niente hard delete (soft delete con `deletedAt`).

## Build APK release

```bash
cd frontend
# Crea keystore (una tantum) e key.properties (gitignored)
flutter build apk --release --split-per-abi
```

Installa l’APK sui due telefoni (origini sconosciute). Aggiornamenti: installa sopra; i dati stanno su Firebase.

## Fasi

| Fase | Contenuto |
|------|-----------|
| 1 (questa PR) | Scheletro UI, temi, router, BalanceCalculator, backend rules, docs |
| 2 | Firebase Auth Google + household |
| 3 | Spese + Riepilogo |
| 4 | Bonifici |
| 5 | Cose da fare + notifiche |
| 6 | Rendiconto / export |
| 7 | Altro / rifiniture |
| 8 | Import Excel |
| 9 | Release CI + tag v1.0.0 |

## Design

Token e mockup in `docs/design-reference.html` (direzione B · Notte). Font **Sora**. UI in italiano.
