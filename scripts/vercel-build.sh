#!/usr/bin/env bash
# Build Flutter web for Vercel (output: frontend/build/web).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="$ROOT/flutter/bin:$PATH"

cd frontend
flutter pub get
flutter build web --release --dart-define=DEMO_AUTH=true --web-renderer canvaskit
