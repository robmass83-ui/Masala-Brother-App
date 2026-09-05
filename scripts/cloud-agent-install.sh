#!/usr/bin/env bash
# Idempotent Cloud Agent bootstrap for the Masala Brother App.
# Ensures the Flutter SDK is present, then refreshes frontend (Flutter) and
# backend (Firebase rules emulator) dependencies. Safe to run repeatedly.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${FLUTTER_HOME:-/opt/flutter}"

# 1. Flutter SDK. Baked into the environment snapshot; cloned here only if absent
#    (e.g. when building without the snapshot) so the script stays self-contained.
if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
  echo "Flutter SDK not found at $FLUTTER_DIR; cloning stable channel..."
  parent="$(dirname "$FLUTTER_DIR")"
  if [[ -w "$parent" ]]; then
    mkdir -p "$FLUTTER_DIR"
  else
    sudo mkdir -p "$FLUTTER_DIR"
    sudo chown -R "$(id -u):$(id -g)" "$FLUTTER_DIR"
  fi
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
git config --global --add safe.directory "$FLUTTER_DIR" || true

# Expose flutter/dart on the system PATH for interactive agent shells.
for bin in flutter dart; do
  if [[ -w /usr/local/bin ]]; then
    ln -sf "$FLUTTER_DIR/bin/$bin" "/usr/local/bin/$bin" || true
  elif sudo -n true 2>/dev/null; then
    sudo ln -sf "$FLUTTER_DIR/bin/$bin" "/usr/local/bin/$bin" || true
  fi
done

flutter config --no-analytics >/dev/null 2>&1 || true
flutter precache --web

# 2. Frontend dependencies (Flutter/Dart).
(cd "$REPO_ROOT/frontend" && flutter pub get)

# 3. Backend dependencies (Firestore rules emulator tests).
(cd "$REPO_ROOT/backend" && npm install)

echo "Cloud Agent install complete."
