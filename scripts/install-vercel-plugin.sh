#!/usr/bin/env bash
# Installs the official Vercel agent plugin into Cursor (project scope).
# Required once per machine / agent environment — not a GitHub App.
# Docs: https://vercel.com/docs/agent-resources/vercel-plugin
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v npx >/dev/null 2>&1; then
  echo "npx is required (Node.js 18+)." >&2
  exit 1
fi

echo "Installing vercel/vercel-plugin (Cursor, project scope)..."
npx --yes plugins add vercel/vercel-plugin --target cursor --scope project --yes

echo
echo "Done. Restart Cursor / reload the window so the plugin loads."
echo "Slash commands: /vercel-plugin:deploy /vercel-plugin:status /vercel-plugin:env"
echo "Marketplace: Customize → Plugins → search Vercel, or run: /add-plugin vercel"
