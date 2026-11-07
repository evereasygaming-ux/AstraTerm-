#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Install Flutter stable and retry." >&2
  exit 1
fi

PLATFORMS="android,ios,macos,windows,linux"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Generating native runner projects..."
flutter create \
  --platforms="$PLATFORMS" \
  --org=com.astra \
  --project-name=term \
  "$TMP_DIR/term" >/dev/null

for platform in android ios macos windows linux; do
  if [[ ! -e "$ROOT/$platform" ]]; then
    cp -R "$TMP_DIR/term/$platform" "$ROOT/$platform"
  fi
done

# Flutter project-name=term + org=com.astra yields com.astra.term for native IDs.
# Keep the Dart package name astraterm; native runner IDs are independent.
if [[ -f android/app/src/main/AndroidManifest.xml ]]; then
  sed -i.bak 's/android:label="term"/android:label="AstraTerm"/' android/app/src/main/AndroidManifest.xml || true
  rm -f android/app/src/main/AndroidManifest.xml.bak
fi

# Phase 2.1: install the custom Android shell engine sources from the tracked
# native/android/ directory into the generated Android runner. Runs on every
# invocation so the copy is idempotent and never reverts a previous install.
NATIVE_ANDROID_DIR="$ROOT/native/android"
if [[ -d android/app/src/main/kotlin ]]; then
  if [[ -d "$NATIVE_ANDROID_DIR" ]]; then
    mkdir -p android/app/src/main/kotlin/com/astra/term
    cp -f "$NATIVE_ANDROID_DIR/MainActivity.kt" android/app/src/main/kotlin/com/astra/term/MainActivity.kt
    cp -f "$NATIVE_ANDROID_DIR/TerminalPlugin.kt" android/app/src/main/kotlin/com/astra/term/TerminalPlugin.kt
    echo "Android shell engine (Phase 2.1) installed into the generated runner."
  else
    echo "Warning: native/android sources missing; shell engine not installed." >&2
  fi
else
  echo "Warning: generated Android runner not found; shell engine not installed." >&2
fi

if [[ -f ios/Runner/Info.plist ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName AstraTerm" ios/Runner/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string AstraTerm" ios/Runner/Info.plist 2>/dev/null || true
fi

if [[ -f macos/Runner/Info.plist ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName AstraTerm" macos/Runner/Info.plist 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string AstraTerm" macos/Runner/Info.plist 2>/dev/null || true
fi

echo "Platform runner scaffolding generated."
echo "Next: flutter pub get && flutter analyze && flutter test"
