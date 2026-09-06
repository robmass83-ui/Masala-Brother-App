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

### Preview web su Vercel

Il progetto Vercel è collegato a GitHub. Su `main` devono esserci `vercel.json` + `scripts/vercel-*.sh` (questo PR).
In Vercel → Project → Settings → Build & Development:

| Setting | Valore |
|---------|--------|
| Framework Preset | Other |
| Install Command | `bash scripts/vercel-install.sh` |
| Build Command | `bash scripts/vercel-build.sh` |
| Output Directory | `frontend/build/web` |
| Root Directory | `.` (repo root) |

Poi **Redeploy** da Deployments. URL: `https://masala-brother-app.vercel.app`

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

## Build APK (per Roberto e Laura)

**Non serve GitHub** per far usare l’app a Laura: i dati stanno su Firebase. Basta installare lo stesso APK sul suo telefono ed entrare con il suo Google (`laura.masala@tiscali.it`).

### Installare sul telefono

1. Copia l’APK sul telefono (WhatsApp, Drive, cavo). Per i telefoni recenti usa `app-arm64-v8a-release.apk`.
2. Apri il file. Se Android blocca: Impostazioni → sblocca **origini sconosciute** / “Consenti da questa app”.
3. Installa. All’aggiornamento successivo installa **sopra** (non disinstallare): i dati restano su Firebase.
4. Entra con Google. Se dice “app privata”, l’email non è in `households/main.memberEmails`.

### Build in locale

```bash
cd frontend
flutter build apk --release --split-per-abi
```

Gli APK escono in `frontend/build/app/outputs/flutter-apk/`.

Senza `android/key.properties` la release è firmata con il keystore **debug** (login Google già abilitato se lo SHA debug è in Firebase). Per una firma definitiva:

```bash
keytool -genkey -v -keystore frontend/android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Copia `frontend/android/key.properties.example` in `frontend/android/key.properties` e riempi le password. Poi aggiungi SHA-1/SHA-256 del keystore in Firebase → Authentication → Google / impronte dell’app Android:

```bash
keytool -list -v -keystore frontend/android/app/upload-keystore.jks -alias upload
```

`key.properties` e `*.jks` non vanno su git.

### GitHub Actions (opzionale, aggiornamenti futuri)

Il workflow `.github/workflows/build-apk.yml` parte su tag `v*` (es. `v1.0.0`) e allega gli APK alla Release GitHub. Serve **push** del codice e questi secret nel repo (Settings → Secrets and variables → Actions):

| Secret | Contenuto |
|--------|-----------|
| `FIREBASE_OPTIONS` | testo intero di `frontend/lib/firebase_options.dart` |
| `GOOGLE_SERVICES_JSON` | testo intero di `frontend/android/app/google-services.json` |
| `KEYSTORE_BASE64` | `certutil -encode upload-keystore.jks keystore.b64` (solo il base64) oppure `base64 -i upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | password del file `.jks` |
| `KEY_PASSWORD` | password della chiave (spesso uguale) |
| `KEY_ALIAS` | `upload` |

Poi: commit, push su `main`, `git tag v1.0.1 && git push origin v1.0.1`.

**Altro → Controlla aggiornamenti** non apre GitHub: confronta la versione sul telefono con l’ultima Release, scarica l’APK e apre l’installer di Android. Condizioni:

- il repository deve essere **pubblico** (senza token nell’app il telefono non legge un repo privato)
- la Release deve avere un file `.apk` allegato
- il `version:` in `pubspec.yaml` della Release deve essere **più alto** di quello già installato (es. telefono `1.0.0` → tag `v1.0.1`)

La prima installazione su Laura resta un APK inviato a mano (WhatsApp). Da quella versione in poi può aggiornare dal pulsante in app.

## Fasi

| Fase | Stato |
|------|--------|
| 1 Scheletro UI | fatto |
| 2 Firebase + login | fatto |
| 3 Spese + Riepilogo | fatto |
| 4 Bonifici | fatto |
| 5 Cose da fare | fatto |
| 6 Rendiconto / export | fatto |
| 7 Altro / rifiniture | fatto |
| 8 Import Excel | fatto |
| 9 Release CI | fatto |

Per importare il file originale: Altro → Importa dal vecchio Excel → scegli `Spese_Laura_Roberto_corretto.xlsx` → conferma. Lascia acceso **Elimina i dati di prova** per togliere spese/bonifici/task inseriti durante i test. Una seconda importazione non duplica.

## Design

Token e mockup in `docs/design-reference.html` (direzione B · Notte). Font **Sora**. UI in italiano.
