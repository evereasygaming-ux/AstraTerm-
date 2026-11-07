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
MAIN_ACTIVITY_SRC="$NATIVE_ANDROID_DIR/MainActivity.kt"
TERMINAL_PLUGIN_SRC="$NATIVE_ANDROID_DIR/TerminalPlugin.kt"
TARGET_KOTLIN_DIR="android/app/src/main/kotlin/com/astra/term"

if [[ -d android/app/src/main/kotlin ]]; then
  # Both custom sources must exist; refuse to half-install otherwise.
  if [[ ! -f "$MAIN_ACTIVITY_SRC" ]]; then
    echo "Error: $MAIN_ACTIVITY_SRC is missing; cannot install the AstraTerm Android shell engine." >&2
    echo "Expected tracked source under native/android/MainActivity.kt." >&2
    exit 1
  fi
  if [[ ! -f "$TERMINAL_PLUGIN_SRC" ]]; then
    echo "Error: $TERMINAL_PLUGIN_SRC is missing; cannot install the AstraTerm Android shell engine." >&2
    echo "Expected tracked source under native/android/TerminalPlugin.kt." >&2
    exit 1
  fi
  mkdir -p "$TARGET_KOTLIN_DIR"
  cp -f "$MAIN_ACTIVITY_SRC" "$TARGET_KOTLIN_DIR/MainActivity.kt"
  cp -f "$TERMINAL_PLUGIN_SRC" "$TARGET_KOTLIN_DIR/TerminalPlugin.kt"
  echo "Android shell engine (Phase 2.1) installed into the generated runner."
else
  echo "Error: generated Android runner not found (android/app/src/main/kotlin missing); shell engine not installed." >&2
  exit 1
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
