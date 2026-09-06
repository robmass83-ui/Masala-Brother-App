# Data model — Masala Brother App

Schema definitivo Firestore sotto `households/main/…`.
Importi sempre in **centesimi interi** (`int`). Soft delete con `deletedAt`.

## `households/main`

| campo | tipo | note |
|---|---|---|
| memberEmails | string[] | email autorizzate (Roberto, Laura) |
| members | map uid → `{name, initial, colorKey: "rob"\|"lau"}` | compilato al primo login |
| enableAttachments | bool | default false se Storage non attivo |
| createdAt / updatedAt | timestamp | |

## `expenses/{id}`

| campo | tipo | note |
|---|---|---|
| description | string | 1–120 |
| amountDueCents | int | totale dovuto |
| date | timestamp | |
| categoryId | string | |
| propertyId | string? | |
| shareRobPct | int | default 50; Laura = 100 − shareRobPct |
| payments | array `{id, payerUid, amountCents, date, method, note}` | |
| paidRobCents, paidLauCents, paidTotalCents | int | denormalizzati |
| status | `da_pagare` \| `parziale` \| `pagato` | denormalizzato |
| attachments | array? | opzionale |
| notes | string? | |
| source | `app` \| `excel_import` | |
| importRow | int? | |
| dateEstimated | bool? | import Excel |
| createdBy, createdAt, updatedBy, updatedAt, deletedAt | | audit |

**Stato:** paidTotal==0 → da_pagare; 0<paidTotal<amountDue → parziale; else pagato.

## `transfers/{id}`

Bonifico di conguaglio (non è una spesa).

| campo | tipo |
|---|---|
| fromUid, toUid | string |
| amountCents | int > 0 |
| date | timestamp |
| note | string? |
| source, importRow, audit | come sopra |

## `tasks/{id}`

| campo | tipo |
|---|---|
| title | string 1–200 |
| notes | string? |
| assigneeUid | string? |
| dueDate | timestamp? |
| reminderDaysBefore | int? |
| propertyId | string? |
| linkedExpenseId | string? |
| createExpenseOnDone | bool | default false |
| done, doneAt, doneBy | |
| audit | |

## `categories/{id}` / `properties/{id}`

- categories: `{name, order, isDefault, deletedAt?}` — seed: Bollette, Condominio, Lavori e fatture, Tasse e tributi, Notaio e pratiche, Assicurazioni, Altro
- properties: `{name, shortName, street, houseNumber, interno, scala, floor, postalCode, city, notes, order, deletedAt?}` — seed: Via Forlanini (civico 9), Via Addis, Via Prunizzedda, Sassari / altro. `name` è l'etichetta in lista (es. "Via Forlanini"); il resto è il registro appartamento, visibile nel dettaglio da Altro → Immobili.
- Modificabili da Altro (rinomina, riordino, nuove voci). Le predefinite non si archiviano. Soft-delete con `deletedAt` (le regole vietano hard delete).

## `activity/{id}`

`{type, refId, byUid, at, summary}` — cronologia in Altro → Attività (create/modifiche/cestino di spese, bonifici, cose da fare, catalogo).

## Cestino

Spese, bonifici, cose da fare e liste con `deletedAt` negli ultimi 30 giorni: Altro → Cestino, con ripristino.

## Saldo (client-side)

Vedi `BalanceCalculator` in `frontend/lib/data/balance_calculator.dart`.
Con quote 50%: `creditRob == (paidRob − paidLau) / 2`.
Esempio: paidRob 53.207,19 + paidLau 44.434,19 → Laura deve **€ 4.386,50**.
