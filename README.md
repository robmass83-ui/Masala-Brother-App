# Masala Brother App

App Android privata per **Roberto** e **Laura**: spese condivise, conguagli e cose da fare.
Sostituisce il file Excel su OneDrive. Distribuzione solo come APK (no Play Store).

## Struttura repository

```
frontend/     # Flutter app (Android, minSdk 26) — UI + logica client
backend/      # Firebase: rules, indexes, storage rules + test emulator
docs/         # design-reference.html, PROMPT-CURSOR.md, data-model.md
```

## Prerequisiti

- Flutter stable (3.24+)
- Android SDK / JDK 17
- Account Firebase di Roberto (Auth Google, Firestore `europe-west`)
- Node.js 20+ (solo per test regole; anche per il plugin Vercel)

## Plugin Vercel (Cursor)

Il comando `npx plugins add vercel/vercel-plugin` va eseguito **nell’ambiente Cursor** (non è un’app da aggiungere su GitHub).
Nel repo c’è già il MCP Vercel in `.cursor/mcp.json` e lo script di install:

```bash
./scripts/install-vercel-plugin.sh
# oppure:
npx plugins add vercel/vercel-plugin --target cursor --scope project --yes
```

In Cursor: `/add-plugin vercel`, poi ricarica la finestra.
Dettagli: [`docs/vercel-plugin.md`](docs/vercel-plugin.md).

## Setup Firebase (Fase 2)

1. Console Firebase → progetto di Roberto → **Authentication** → abilita **Google**.
2. Aggiungi app Android package `it.masala.brotherapp`.
3. SHA-1/SHA-256 debug:
   ```bash
   keytool -list -v -alias androiddebugkey \
     -keystore ~/.android/debug.keystore -storepass android -keypass android
   ```
4. Scarica `google-services.json` in `frontend/android/app/` (gitignored).
5. Firestore in produzione, regione `europe-west`.
6. Nel repo:
   ```bash
   cd frontend
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<PROJECT_ID> --platforms=android
   # Sostituisci i REPLACE_ME in lib/firebase_options.example.dart
   # oppure genera lib/firebase_options.dart e aggiorna firebase_bootstrap.dart
   ```
7. Crea il documento `households/main` con:
   ```json
   {
     "memberEmails": ["email.roberto@gmail.com", "email.laura@gmail.com"],
     "members": {},
     "enableAttachments": false
   }
   ```
8. Deploy regole:
   ```bash
   cd backend
   npx firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

### Modalità demo (senza Firebase)

Se `firebase_options` ha ancora `REPLACE_ME`, l’app parte in **DEMO_AUTH**:
il pulsante “Entra con Google” simula Roberto e apre il Riepilogo.

```bash
cd frontend
flutter run --dart-define=DEMO_AUTH=true
```

## Setup frontend

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter run   # oppure flutter run -d chrome per preview web
```

### Secret da non commitare

- `frontend/lib/firebase_options.dart` (se generato)
- `frontend/android/app/google-services.json`
- `frontend/android/key.properties`, `*.jks` / `*.keystore`

## Test regole Firestore

```bash
cd backend
npm install
npm run test:rules
```

Verifica: membro ok, outsider negato, hard delete negato.

## Build APK release

```bash
cd frontend
flutter build apk --release --split-per-abi
```

## Fasi

| Fase | Stato |
|------|--------|
| 1 Scheletro UI | fatto |
| 2 Firebase + login | in corso / questa PR |
| 3 Spese + Riepilogo | |
| 4 Bonifici | |
| 5 Cose da fare | |
| 6 Rendiconto / export | |
| 7 Altro / rifiniture | |
| 8 Import Excel | |
| 9 Release CI | |

## Design

Token e mockup in `docs/design-reference.html` (direzione B · Notte). Font **Sora**. UI in italiano.
