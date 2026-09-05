#!/usr/bin/env bash
# Install Flutter SDK on the Vercel build machine (not present by default).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -d flutter/.git ]]; then
  git -C flutter fetch --depth 1 origin stable
  git -C flutter checkout -q FETCH_HEAD || git -C flutter pull --ff-only
else
  rm -rf flutter
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git
fi

export PATH="$ROOT/flutter/bin:$PATH"
flutter config --no-analytics
flutter precache --web
flutter doctor -v || true
