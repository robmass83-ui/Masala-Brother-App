# Masala Brother App — prompt per Cursor

> **Come usarlo in Cursor (leggi prima, poi cancella questo riquadro se vuoi)**
>
> 1. Clona il repo vuoto `https://github.com/robmass83-ui/Masala-Brother-App` e aprilo in Cursor.
> 2. Copia dentro il repo il file `docs/design-reference.html` (quello che ti ho dato insieme a questo prompt).
> 3. In Cursor scegli la modalità **Plan**, allega con `@` il file `docs/design-reference.html` e incolla **tutto** il testo sotto la riga "INIZIO PROMPT". Fatti proporre il piano, leggilo, correggi se serve, approva.
> 4. Passa a **Build** e fagli eseguire le fasi **una alla volta** (Fase 0, poi Fase 1, …). Dopo ogni fase: `flutter analyze`, `flutter test`, prova sul telefono, commit. Non fargli fare tutto in un colpo solo.
> 5. Quando arrivi alla Fase 8 ti servirà il file Excel: te lo darò io, con la mappatura è già scritta qui sotto.

---

## INIZIO PROMPT

Sei uno sviluppatore senior Flutter/Firebase. Devi costruire **Masala Brother App**, un'app Android privata usata da due sole persone, **Roberto** e **Laura**, per gestire spese condivise, conguagli e cose da fare. Sostituisce un file Excel condiviso su OneDrive. Non verrà pubblicata su Play Store: si distribuisce come APK installato a mano. Tutto il codice (front end Flutter e "back end" Firebase: regole, indici, funzioni se servono, script) vive in questo repository. I dati stanno sul progetto Firebase di Roberto.

Il riferimento visivo è `docs/design-reference.html` (allegato): contiene i token colore dei due temi e le 10 schermate renderizzate in tema scuro e chiaro. Segui quel design fedelmente per gerarchia, misure, colori e componenti; il markup HTML è solo un riferimento, non va copiato.

Lingua dell'interfaccia: **italiano**. Formato numeri: **italiano** (`€ 1.234,56`). Date: `gg MMM aaaa` in italiano (es. `17 lug 2026`). Fuso: quello del telefono.

---

### 1. Stack e vincoli tecnici

- **Flutter** (ultima stable, Dart 3), target **Android** (minSdk 26, targetSdk ultimo). Struttura che permetta iOS in futuro senza riscrivere.
- Gestione stato: **Riverpod** (riverpod_generator / hooks non obbligatori). Navigazione: **go_router**. Modelli immutabili con **freezed** + **json_serializable**.
- Firebase: **firebase_core, firebase_auth, cloud_firestore, firebase_storage** (Storage opzionale, vedi §5), **google_sign_in**. Configurazione con `flutterfire configure` (genera `lib/firebase_options.dart`).
- Firestore con **persistenza offline attiva** (`persistenceEnabled: true`, cache illimitata). L'app deve funzionare offline e sincronizzare da sola: tutte le scritture sono ottimistiche, mai bloccare l'utente in attesa della rete.
- Notifiche locali con **flutter_local_notifications** + **timezone** (promemoria scadenze). Niente FCM, niente server.
- Export: **excel** (o `syncfusion_flutter_xlsio` community) per .xlsx, **pdf** + **printing** per PDF, **share_plus** per condividere il file.
- Import Excel (fase 2): **excel** per lettura, **file_picker** per scegliere il file.
- Immagini ricevute: **image_picker** + compressione (`flutter_image_compress`) a max 1600px / ~300 KB.
- Font: **Sora** via `google_fonts` (con fallback di sistema).
- Qualità: `flutter_lints` strict, `very_good_analysis` opzionale. Test unitari obbligatori per la logica di calcolo (§4) e per il parser Excel (§8). Nessun warning in `flutter analyze`.
- Nessun secret nel repo: `google-services.json` e `firebase_options.dart` vanno in `.gitignore` con un `firebase_options.example.dart` e istruzioni in README. (Il repo è privato ma la regola vale comunque.)

### 2. Struttura del repository

```
Masala-Brother-App/
├── README.md                      # setup, build APK, come installarlo sui 2 telefoni
├── docs/
│   ├── design-reference.html      # riferimento visivo (fornito)
│   ├── PROMPT-CURSOR.md           # questo file
│   └── data-model.md              # generato in Fase 1: schema Firestore definitivo
├── app/                           # progetto Flutter
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart               # MaterialApp.router, temi, locale it_IT
│   │   ├── core/                  # theme/, utils (formattazione €, date), widgets comuni
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── home/              # Riepilogo
│   │   │   ├── expenses/          # elenco, nuova, dettaglio, pagamenti
│   │   │   ├── transfers/         # bonifici di conguaglio
│   │   │   ├── tasks/             # cose da fare
│   │   │   ├── report/            # rendiconto
│   │   │   ├── export/            # excel + pdf
│   │   │   ├── import_excel/      # fase 2
│   │   │   └── settings/          # Altro
│   │   └── data/                  # modelli freezed, repository Firestore, calcolo saldo
│   └── test/
├── firebase/
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   ├── storage.rules
│   └── firebase.json
└── .github/workflows/build-apk.yml   # build release APK a ogni tag v*
```

### 3. Firebase: progetto, autenticazione, sicurezza

**Setup (documentalo nel README passo per passo, con screenshot testuali di dove cliccare):**

1. Progetto Firebase già creato da Roberto. Regione Firestore: `europe-west` (eur3) o `europe-west1`.
2. Authentication → abilita **Google**. Aggiungi l'app Android con package `it.masala.brotherapp` e le impronte SHA-1/SHA-256 dei keystore debug e release (spiega come ottenerle con `keytool`).
3. Firestore in modalità produzione. Storage: **opzionale** — i nuovi progetti Firebase richiedono il piano Blaze (pay-as-you-go, con quota gratuita) per Storage; se Roberto non vuole attivarlo, gli allegati ricevuta restano disattivati tramite un flag `enableAttachments` in un documento di configurazione e l'interfaccia nasconde la voce.
4. `flutterfire configure` nella cartella `app/`.

**Accesso: solo due persone.** Login con Google. Un documento `households/main` contiene `memberEmails: [email Roberto, email Laura]` e `members: { uid: {name, initial, colorKey: "rob"|"lau"} }`. Le **regole Firestore** consentono lettura e scrittura **solo** se `request.auth.token.email` è nella lista `memberEmails` del household (leggi il documento nelle regole con `get()`); tutto il resto negato. Chi entra con un'altra Google account vede una schermata "Questa app è privata" con logout. Al primo login di un'email autorizzata, l'app compila `members[uid]` se manca.

Regole anche per validare i dati: importi numerici ≥ 0, `createdBy == request.auth.uid` in creazione, niente cancellazione fisica (`allow delete: if false`) — si usa soft delete con `deletedAt`.

### 4. Modello dati e logica di calcolo (il cuore dell'app)

Tutto sta sotto `households/main/…`. Importi sempre in **centesimi interi** (`int amountCents`) per evitare errori di arrotondamento; si formattano solo in UI.

**`expenses/{id}`** — una spesa da dividere

| campo | tipo | note |
|---|---|---|
| description | string | obbligatorio, 1–120 caratteri |
| amountDueCents | int | "DA PAGARE" nell'Excel: quanto costa in totale la voce |
| date | timestamp | data della spesa/fattura |
| categoryId | string | riferimento a `categories/{id}` |
| propertyId | string? | riferimento a `properties/{id}`, opzionale |
| shareRobPct | int | quota di Roberto in percento, default **50**; Laura = 100 − shareRobPct |
| payments | array di `{id, payerUid, amountCents, date, method: "bonifico"\|"contanti"\|"carta"\|"altro", note}` | pagamenti effettivi; max ~20 per spesa quindi array va bene |
| paidRobCents, paidLauCents, paidTotalCents | int | **denormalizzati**, ricalcolati a ogni scrittura dall'array payments (mai editati a mano) |
| status | "da_pagare" \| "parziale" \| "pagato" | denormalizzato, vedi regola sotto |
| attachments | array di `{storagePath, thumbPath, name, sizeBytes}` | opzionale |
| notes | string? | |
| source | "app" \| "excel_import" | |
| importRow | int? | riga Excel di origine |
| createdBy, createdAt, updatedBy, updatedAt, deletedAt | | audit |

**Regola stato** (identica alle formule Excel):
- `paidTotal == 0` → `da_pagare`
- `0 < paidTotal < amountDue` → `parziale`
- `paidTotal >= amountDue` → `pagato` (se `paidTotal > amountDue` mostra un avviso "pagato in eccesso di € X", non bloccare)

**`transfers/{id}`** — bonifico di conguaglio tra i due (nell'Excel erano righe "Bonifico Roberto per Laura" con importo dovuto 0 e +X / −X)

| campo | tipo |
|---|---|
| fromUid, toUid | string |
| amountCents | int > 0 |
| date | timestamp |
| note | string? |
| source, importRow, audit | come sopra |

**`tasks/{id}`** — cosa da fare

| campo | tipo |
|---|---|
| title | string 1–200 |
| notes | string? |
| assigneeUid | string? (null = chiunque) |
| dueDate | timestamp? |
| reminderDaysBefore | int? (0 = il giorno stesso) |
| propertyId | string? |
| linkedExpenseId | string? |
| createExpenseOnDone | bool, default false |
| done, doneAt, doneBy | bool, timestamp?, uid? |
| audit | |

**`categories/{id}`** `{name, order, isDefault}` — seed iniziale: Bollette, Condominio, Lavori e fatture, Tasse e tributi, Notaio e pratiche, Assicurazioni, Altro.
**`properties/{id}`** `{name, shortName, order}` — seed iniziale: Forlanini 9, Via Addis, Via Prunizzedda, Sassari / altro. Entrambe le liste sono modificabili da "Altro".

**`activity/{id}`** (opzionale ma consigliato) `{type, refId, byUid, at, summary}` — cronologia "chi ha fatto cosa" mostrata in Altro → Attività, utile perché i due lavorano in momenti diversi.

**Calcolo del saldo — deve dare gli stessi numeri dell'Excel.** Implementa una classe pura `BalanceCalculator` (nessuna dipendenza Firebase) con test unitari:

```
paidRob  = Σ expenses.paidRobCents + Σ transfers(from Rob).amount − Σ transfers(to Rob).amount
paidLau  = Σ expenses.paidLauCents + Σ transfers(from Lau).amount − Σ transfers(to Lau).amount
totalDue = Σ expenses.amountDueCents
totalPaid = paidRob + paidLau
halfEach = totalPaid / 2                          // "Metà da pagare" dell'Excel
creditRob = Σ over expenses (paidRobOnExpense − shareRobPct% × paidTotalOnExpense)
            + Σ transfers(from Rob) − Σ transfers(to Rob)
```
- Se `creditRob > 0` → **Laura deve a Roberto** `creditRob`; se `< 0` → Roberto deve a Laura `|creditRob|`; se 0 → "Siete in pari".
- Con tutte le quote al 50% `creditRob == (paidRob − paidLau) / 2`, che è esattamente la cella "Da restituire (metà della differenza)" dell'Excel. Scrivi un test che lo verifica con i dati di esempio: paidRob 53.207,19 e paidLau 44.434,19 → Laura deve 4.386,50.
- Il saldo si basa **solo su ciò che è stato pagato**, non su ciò che è dovuto: una bolletta non ancora pagata non sposta il saldo (come nell'Excel).
- Arrotondamenti: calcola in centesimi, la metà di un centesimo dispari va a favore di chi ha pagato di più (documentalo).
- Il saldo si calcola **sul client** da uno stream di tutte le spese e transfer non cancellate (per due persone e qualche centinaio di voci è istantaneo). Non usare Cloud Functions per questo.

**Validazioni in UI e nei repository:** importo > 0 (tranne `amountDue` che può essere 0 solo per voci importate); un pagamento non può superare di oltre il 100% l'importo dovuto senza conferma; data non oltre 1 anno nel futuro; descrizione obbligatoria; su "Segna pagata" se manca ancora una quota chiedi **chi** ha pagato la differenza e crea il pagamento corrispondente.

### 5. Design system e temi (vincolante)

- Due temi: **scuro** (predefinito nel design) e **chiaro**. Segui il sistema (`ThemeMode.system`) con override in Altro → Aspetto (Sistema / Chiaro / Scuro), salvato in `shared_preferences`.
- Implementa i token della tabella di `docs/design-reference.html` come `ThemeExtension<AppColors>` con due istanze (dark, light). **Ogni** colore di testo/icona viene dai token: `ink` su `bg`/`card`, `onAcc` su `acc`, `heroFg` su `hero`. È vietato usare `Colors.white`, `Colors.black` o esadecimali fissi nei widget. Aggiungi un test che carica ogni schermata in entrambi i temi (golden o almeno smoke test) e un check di contrasto (≥ 4.5:1 testo normale, ≥ 3:1 testo grande/icone) sui token con un test unitario.
- Roberto è sempre `rob`, Laura sempre `lau`, con iniziale in quadrato arrotondato (raggio = lato/3). Stati: Pagato `ok`, Parziale `warn`, Da pagare `due`, sempre come chip testo+sfondo soft.
- Font Sora. Corpo 15–16, secondario 12–13, importi 16–20 nelle liste, saldo 38–52. `Text` con `maxLines: 1, overflow: ellipsis` per titoli in lista; descrizioni lunghe a capo nel dettaglio.
- **Nessuno scroll orizzontale in nessuna schermata.** Liste verticali; chip filtro in `Wrap`; niente `DataTable` larghe: usa righe chiave/valore. Aggiungi un widget test che verifica che nessuna pagina produca overflow orizzontale (RenderFlex overflow = test fallito) a larghezze 360, 390 e 412 dp con scala testo 1.0 e 1.3.
- Una sola azione primaria per schermata: tasto pieno `acc` alto 56, raggio 16. Target minimi 48 dp. Card raggio 18 con bordo `line`; campi raggio 14.
- Barra inferiore: Riepilogo · Spese · **[+]** · Da fare · Altro. Il **[+]** centrale (FAB `acc`) apre Nuova spesa; **pressione lunga** apre un foglio con Nuova spesa / Nuova cosa da fare / Registra bonifico.
- Feedback: dopo ogni salvataggio uno `SnackBar` breve ("Spesa salvata") con **Annulla** per 5 secondi che ripristina (soft delete inverso). Stati vuoti con una frase e un tasto (mai schermate bianche). Indicatore piccolo "offline · le modifiche si sincronizzano dopo" quando non c'è rete.
- Rispetta la scala testo del sistema fino a 1.3 senza rompere il layout.

### 6. Schermate e comportamenti (rotte go_router)

**0. `/login`** — logo testuale "Masala Brother App", tasto "Entra con Google". Dopo il login: se email autorizzata → `/`, altrimenti schermata "App privata" con logout. Splash che aspetta lo stato auth (max 2 s poi mostra login).

**1. `/` Riepilogo** — header "Ciao {nome}" + campanella (apre la lista promemoria in scadenza). Riquadro saldo `hero`: etichetta "Situazione attuale", importo grande, frase "che **Laura** deve a **Roberto**" (o inverso, o "Siete in pari") con i nomi nei rispettivi colori; tasto "Registra bonifico" (precompila direzione e importo = saldo) e freccia → apre `/rendiconto`. Due card "Roberto ha pagato" / "Laura ha pagato" (paidRob/paidLau). Card "Spese totali / Metà a testa" con barra proporzionale rob/lau e percentuali. Sezione "Da sistemare": max 3 voci tra le spese `da_pagare` e `parziale` ordinate per data + le cose da fare in scadenza entro 7 giorni; link "Vedi tutte". Tutto in tempo reale da stream Firestore.

**2. `/spese` Elenco spese** — ricerca (icona → campo che filtra su descrizione, categoria, immobile, importo) e filtro (foglio: stato, chi ha pagato, categoria, immobile, periodo). Chip in `Wrap`: Tutte · Da pagare · Parziali · Pagate con conteggi. Lista raggruppata per **mese** (intestazione "SETTEMBRE 2026 · € totale mese"), righe: avatar di chi ha pagato (se entrambi mostra i due avatar sovrapposti; se nessuno, avatar vuoto tratteggiato), descrizione (1 riga, ellissi), sottotitolo "data · categoria/immobile", importo dovuto, chip stato. Tap → dettaglio. Swipe a sinistra → "Segna pagata" (con la domanda su chi ha pagato), swipe a destra → "Elimina" con conferma (soft delete). Paginazione: carica per mese, scroll infinito.

**3. `/spese/nuova` Nuova spesa** (anche `/spese/:id/modifica`) — campi in ordine: **Importo** (tastiera numerica, formattazione live `€ 1.234,56`, autofocus), Descrizione (suggerimenti dalle descrizioni recenti), Data (default oggi, date picker italiano), Categoria (chip selezionabili + "Altro…"), Immobile (chip, opzionale), **Chi ha pagato**: segmenti Roberto / Laura / Entrambi / Nessuno ancora. Se Roberto o Laura: crea un pagamento pari all'importo → stato `pagato`. Se Entrambi: appaiono due campi importo con default metà ciascuno, la somma deve fare l'importo (mostra il residuo); se la somma è minore → stato `parziale`. Se Nessuno ancora → `da_pagare`. **Divisione**: chip "Metà ciascuno" (default) oppure slider 0–100 con i due importi a fianco nei colori rob/lau. Foto ricevuta (se allegati abilitati). Tasto "Salva spesa". Annulla chiede conferma se ci sono modifiche.

**4. `/spese/:id` Dettaglio spesa** — chip categoria e stato, titolo intero, "data · aggiunta da {nome}". Card a 3 colonne: **Da pagare / Corrisposto / Manca** (Manca in `due`, Corrisposto in `ok`), barra rob/lau proporzionale. Lista **Pagamenti** (avatar, "{nome} ha pagato", data · metodo, importo; tap → modifica, swipe → elimina). Allegati (miniature, tap → visualizzatore). Note. Azioni: "Pagamento" (foglio: chi, importo con default = quanto manca, data, metodo, nota) e "Segna pagata" (se manca qualcosa chiede chi). Menu: modifica, duplica (utile per bollette ricorrenti: copia con data oggi e senza pagamenti), elimina.

**5. `/bonifici/nuovo` Registra bonifico** — card informativa "Per pareggiare i conti oggi: {chi} → {chi} € saldo". Segmenti direzione Laura → Roberto / Roberto → Laura (default: quella che pareggia). Importo con tasto "Tutto" = saldo. Data, nota. Testo di aiuto: "Il bonifico non è una spesa: serve solo a riportare il saldo a zero." Salva → torna a Riepilogo che mostra il nuovo saldo. Elenco bonifici in `/bonifici` (raggiungibile da Riepilogo → freccia → Rendiconto → "Bonifici").

**6. `/dafare` Cose da fare** — chip Aperte · Fatte · Tutte. Sezioni: **In scadenza** (scadute o entro 7 giorni, data in `due` se scaduta, `warn` se entro 7 giorni), **Prossimamente**, **Senza scadenza**, **Fatte di recente** (ultime 10, barrate). Riga: quadrato spunta 28 dp (tap → done con animazione e SnackBar Annulla), titolo, sottotitolo "Scade {data} · € importo se collegata a spesa" o "Fatta da {nome} · {data}", avatar assegnatario. Se `createExpenseOnDone` al completamento apre Nuova spesa precompilata (descrizione = titolo, immobile) e collega le due voci. Tap sulla riga → foglio dettaglio/modifica.

**7. `/dafare/nuova` Nuova cosa da fare** — Cosa (multilinea, autofocus), Se ne occupa (Roberto / Laura / Chiunque), Scadenza (opzionale), Promemoria (Nessuno / il giorno stesso / 1 / 3 / 7 giorni prima), Collegata a (immobile), interruttore "Crea anche la spesa quando la segni fatta". Tasto "Aggiungi".

Promemoria: alla creazione/modifica programma una notifica locale alle 9:00 del giorno calcolato, sul telefono di chi è assegnato (o di entrambi se "Chiunque"). All'avvio l'app ri-sincronizza le notifiche programmate con i task aperti (perché l'altro può aver modificato). Tap sulla notifica → apre il task.

**8. `/rendiconto` Rendiconto** — selettore periodo (Anno corrente / Tutto / Personalizzato con due date). Card totali: Spese del periodo, numero voci, pagato Roberto, pagato Laura, barra. Sezione **Per immobile** e **Per categoria**: righe con nome, importo, barra proporzionale (`acc`) rispetto al massimo; tap → elenco spese filtrato. Sezione **Bonifici** del periodo. Icona documento in alto → `/esporta` con il periodo già impostato.

**9. `/esporta` Esporta** — Formato: **Excel (.xlsx)** o **PDF**. Periodo. Interruttori: includi bonifici · includi cose da fare · solo da pagare/parziali. Tasto "Genera": crea il file in cache e apre il foglio di condivisione (WhatsApp, OneDrive, email, salva).
- **Excel**: replica il layout del file originale così Roberto lo riconosce: foglio "Spese" con righe 1–3 di riepilogo (Spese totali, TOT pagato Roberto/Laura, Da restituire, Metà da pagare **come formule** `=SUM(...)`, `=IF(...)`) e dalla riga 4 l'intestazione `DETTAGLIO SPESA | DA PAGARE | ROBERTO | LAURA | STATO | CORRISPOSTO | DATA | CATEGORIA | IMMOBILE | ID`; una riga per spesa, i bonifici come righe con DA PAGARE 0 e +X/−X (come faceva l'Excel), STATO e CORRISPOSTO come formule. Secondo foglio "Pagamenti" (un pagamento per riga), terzo "Da fare" se richiesto. Formato numeri `#.##0,00 €`, intestazioni in grassetto, larghezze colonne sensate, riquadro bloccato sotto la riga 4.
- **PDF**: A4 verticale, intestazione "Rendiconto spese Laura e Roberto · periodo", riquadro saldo, tabella spese (descrizione, data, dovuto, Roberto, Laura, stato) con totali, pagina per immobile/categoria, elenco bonifici, cose da fare aperte. Font leggibile ≥ 10 pt, colonne che non escono dalla pagina (descrizioni a capo).

**10. `/altro` Altro** — profilo (avatar, nome, email, stato "Sincronizzato · ultimo aggiornamento …" o "Offline"), sezione **Conti condivisi**: Partecipanti (nomi e colori, email autorizzate — sola lettura), Immobili (lista modificabile, riordino), Categorie (idem); **Dati**: Esporta Excel/PDF, Importa dal vecchio Excel (§8), Attività recente; **App**: Promemoria (ora predefinita), Aspetto (Sistema/Chiaro/Scuro), Dimensione testo (segue sistema, info), Versione app e "Controlla aggiornamenti" (apre la pagina Releases del repo GitHub), Esci.

### 7. Sincronizzazione e concorrenza

- Tutte le liste sono **stream** Firestore (`snapshots()`), quindi ciò che fa Laura appare sul telefono di Roberto in tempo reale senza refresh.
- Scritture con `SetOptions(merge: true)` sui soli campi toccati; `updatedAt: FieldValue.serverTimestamp()`. I campi denormalizzati (`paidRob/Lau/Total`, `status`) vengono ricalcolati dal repository **prima** di ogni scrittura a partire dall'array payments, in una transazione o batch.
- Soft delete ovunque (`deletedAt`); le query filtrano `deletedAt == null`. Cestino in Altro → Dati con ripristino (ultimi 30 giorni).
- Conflitti: last-write-wins è accettabile per due persone; mostra però in dettaglio "modificata da {nome} il …" e, se il documento cambia mentre è aperto in modifica, un avviso non bloccante.
- Indici composti necessari (dichiarali in `firestore.indexes.json`): expenses (deletedAt, date desc), expenses (deletedAt, status, date desc), tasks (deletedAt, done, dueDate), transfers (deletedAt, date desc).

### 8. Import dal vecchio Excel (Fase 2 — prepara il codice ora, il file arriverà dopo)

Il file `Spese_Laura_Roberto_corretto.xlsx` ha un solo foglio. Struttura **esatta**:

- Righe 1–3: riepilogo con formule (ignorare).
- Riga 4: intestazione `A=DETTAGLIO SPESA, B=DA PAGARE, C=ROBERTO, D=LAURA, E=STATO (formula), F=CORRISPOSTO (formula)`.
- Dalla riga 5 fino alla prima riga vuota o alla riga che contiene "TOTALE PAGATO": una voce per riga. `B` = importo dovuto, `C` = pagato da Roberto, `D` = pagato da Laura (celle vuote = 0). Alcune righe hanno solo `D` compilata senza `C`.
- **Bonifici**: righe con `B = 0` e `C`/`D` di segno opposto (es. `C = 1470, D = −1470` = "Bonifico Roberto per Laura" 1.470 €; `C = −750, D = 750` = Laura ha bonificato 750 € a Roberto). Vanno importati come `transfers`, **non** come spese: `from` = chi ha il valore positivo, importo = valore assoluto.
- La data non c'è come colonna: prova a estrarla dalla descrizione (pattern come "26 dic 2023", "genn 2024", "30/03/2026", "17/07/206" → correggi anni a 3 cifre, "lugl 2025", "mag/giugno 24"); se non trovi nulla usa l'ordine di riga per stimare (le righe sono cronologiche dal 2023 al 2026) e marca `dateEstimated: true` così in UI compare un puntino "data stimata" da correggere.
- Immobile: deducilo da parole chiave nella descrizione (`forlanini`, `addis`, `prunizzedda`/`prunuzzedda`, `sassari`, altrimenti nessuno). Categoria da parole chiave (`bolletta|luce|gas|tim|enel|gaxa|idrico` → Bollette; `condominio|ascensore|e/c` → Condominio; `fattura|infissi|acconto|saldo|rata` → Lavori e fatture; `imu|tari|bollo|redditi` → Tasse e tributi; `notai|successione|geometra|divisione` → Notaio e pratiche; altrimenti Altro).
- Ogni spesa importata ha `source: "excel_import"`, `importRow`, e un pagamento per ciascuna colonna C/D > 0 con `method: "altro"`, data = data della spesa.
- Flusso UI: Altro → Importa → scegli file → **anteprima** (tabella verticale a schede: n. spese, n. bonifici, totali per persona, saldo risultante confrontato con quello attuale, righe dubbie evidenziate) → conferma → import in batch da 400 → riepilogo. L'import è **idempotente**: una seconda importazione dello stesso file non duplica (chiave `importRow` + hash descrizione+importi). Dopo l'import il saldo calcolato dall'app deve coincidere al centesimo con la cella "Da restituire" dell'Excel: mostralo nell'anteprima come verifica.
- Scrivi test unitari del parser con un piccolo xlsx di fixture che riproduce i casi sopra (riga normale, riga solo Laura, bonifico in entrambe le direzioni, date nei vari formati).

### 9. Build, distribuzione, aggiornamenti

- README con: prerequisiti, `flutterfire configure`, creazione keystore release (`keytool`), `key.properties` ignorato da git, `flutter build apk --release --split-per-abi`, come installare l'APK su Android (attiva "origini sconosciute"), come aggiornare (installa sopra, i dati sono su Firebase).
- GitHub Actions `build-apk.yml`: su tag `v*` fa checkout, setup Flutter, ricrea `firebase_options.dart`, `google-services.json`, keystore e `key.properties` da **GitHub Secrets** (documenta i nomi dei secret), esegue `flutter analyze` + `flutter test`, builda l'APK firmato e lo allega alla **Release** GitHub. Così per aggiornare i due telefoni basta scaricare l'APK dalla release.
- Versioning: `pubspec.yaml` `version: 1.0.0+1`, mostrata in Altro.

### 10. Fasi di lavoro (esegui una alla volta, commit a ogni fase)

- **Fase 0 — Piano**: leggi tutto, guarda `docs/design-reference.html`, proponi il piano, elenca le domande aperte. Non scrivere codice.
- **Fase 1 — Scheletro**: progetto Flutter in `app/`, dipendenze, temi con i token, `AppColors`, tipografia, widget base (AppCard, StatusChip, PersonAvatar, PrimaryButton, MoneyText, AppScaffold con barra inferiore e FAB), routing con tutte le rotte e pagine placeholder, test di contrasto e di overflow. Scrivi `docs/data-model.md`.
- **Fase 2 — Firebase e login**: configurazione, Google Sign-In, household, regole Firestore + test delle regole con emulator (`firebase emulators:exec`), seed di categorie e immobili.
- **Fase 3 — Spese**: modelli, repository, `BalanceCalculator` con test, Elenco, Nuova/Modifica, Dettaglio, pagamenti, soft delete, Riepilogo completo.
- **Fase 4 — Bonifici**: registrazione, elenco, integrazione nel saldo.
- **Fase 5 — Cose da fare**: lista, creazione, completamento, collegamento spesa, notifiche locali.
- **Fase 6 — Rendiconto ed Esporta**: aggregazioni, Excel, PDF, condivisione.
- **Fase 7 — Altro e rifiniture**: impostazioni, aspetto, immobili/categorie, attività, cestino, stati vuoti, offline, accessibilità (scala testo 1.3, TalkBack sui controlli principali).
- **Fase 8 — Import Excel**: parser + anteprima + import idempotente (il file reale sarà fornito in questa fase; nel frattempo usa la fixture).
- **Fase 9 — Release**: README, workflow GitHub Actions, primo tag `v1.0.0`, APK.

Per ogni fase: `flutter analyze` senza warning, `flutter test` verde, e un breve elenco di cosa provare a mano sul telefono.

### 11. Criteri di accettazione finali

1. Con i dati d'esempio del riferimento (Roberto 53.207,19 pagato, Laura 44.434,19) il Riepilogo mostra **€ 4.386,50 che Laura deve a Roberto**.
2. Nessuna schermata scorre orizzontalmente a 360/390/412 dp con scala testo fino a 1.3.
3. Ogni testo è leggibile in entrambi i temi (test di contrasto verde); cambiando tema non resta nessun colore fisso.
4. Una spesa inserita da un telefono compare sull'altro entro pochi secondi; inserita offline, si sincronizza al ritorno della rete senza intervento.
5. L'Excel esportato si apre in Excel/OneDrive con le formule di riepilogo funzionanti e riproduce il layout originale.
6. L'import del file originale produce lo stesso saldo dell'Excel al centesimo e non duplica se rieseguito.
7. Solo le due email autorizzate possono leggere o scrivere (test delle regole).

## FINE PROMPT
