# Vercel plugin (Cursor / agent)

Il plugin ufficiale Vercel **non** è un’app GitHub da abilitare sul repository.
Si installa nell’ambiente dell’agente (Cursor sul PC, o Cloud Agent) e dà skill, comandi slash e contesto deploy.

## Dove va

| Cosa | Dove | Commit su GitHub? |
|------|------|-------------------|
| `npx plugins add vercel/vercel-plugin` | Macchina locale / agente | No (installazione locale) |
| MCP Vercel | `.cursor/mcp.json` | **Sì** (già nel repo) |
| Config hosting Flutter web | `vercel.json` (root) | Sì, se usi Vercel per la preview |

## Installazione (una volta)

Dal root del repo:

```bash
./scripts/install-vercel-plugin.sh
```

oppure:

```bash
npx plugins add vercel/vercel-plugin --target cursor --scope project --yes
```

In Cursor puoi anche usare:

```text
/add-plugin vercel
```

Poi **ricarica la finestra** Cursor.

## Uso tipico

```text
/vercel-plugin:status
/vercel-plugin:deploy
/vercel-plugin:env
/vercel-plugin:bootstrap
```

L’MCP in `.cursor/mcp.json` punta a `https://mcp.vercel.com` (OAuth al primo collegamento).

## Preview web di questa app

L’app è Flutter (`frontend/`), non Next.js. Per Vercel conviene pubblicare `frontend/build/web` già buildato, oppure collegare il repo e usare `vercel.json` in root come riferimento di build/output.
