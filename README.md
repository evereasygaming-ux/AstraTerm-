# AstraTerm

AstraTerm is a Flutter-based, cross-platform terminal application.

## Identity

- Product name: AstraTerm
- Flutter package: `astraterm`
- Android application ID / Apple bundle ID: `com.astra.term`
- Initial delivery priority: Android first, then iOS, macOS, Windows and Debian Linux.

## Phase 1 status

This repository contains the shared Flutter application foundation, an Android-first CI workflow, and a platform bootstrap script. It is **not yet a complete terminal emulator**. The process/PTY engine, terminal rendering, shell adapters, SSH and runtime plugin system are later milestones.

## Phase 2.1 status (terminal engine begins)

Phase 2.1 adds the first execution layer: a Kotlin adapter around the Android
system shell (`/system/bin/sh`), fully sandboxed in the app and built through
GitHub Actions (no Termux Android SDK, ADB or NDK needed):

- `lib/services/terminal_shell.dart`: Dart `TerminalShellService` over the
  `com.astra.term/terminal` MethodChannel and `com.astra.term/terminal_output`
  EventChannel. Non-Android platforms degrade gracefully with a clear
  unavailable message.
- `native/android/`: tracked Kotlin shell-engine sources that the bootstrap
  script installs into the (git-ignored) generated Android runner.
- Command input, streamed merged stdout/stderr output, a connection status
  indicator and a close/restart session control in the Flutter UI.

This milestone is an initial Android sandbox shell **only**. Honest
limitations: no PTY, no BusyBox, no package manager, no Debian/Ubuntu
userspace, no root privileges, no full Linux compatibility.

## Requirements

- Flutter stable SDK (version pinned by the CI workflow)
- Android SDK for Android builds
- Git

## Bootstrap

The repository keeps generated platform folders out of source control until bootstrapping. From the repository root:

```bash
bash scripts/bootstrap_flutter.sh
flutter pub get
flutter analyze
flutter test
flutter run
```

The bootstrap script generates Android, iOS, macOS, Windows and Linux runner projects using Flutter, while preserving AstraTerm's Dart source and package metadata. It uses `com.astra.term` as the native application/bundle identifier. The generated `MainActivity` is then replaced with AstraTerm's tracked Kotlin MainActivity + shell engine plugin from `native/android/` (idempotent: safe to re-run).

## Android build

```bash
flutter build apk --release
flutter build appbundle --release
```

Artifacts are written under `build/app/outputs/`.

## GitHub Actions

- `ci.yml`: formatting, static analysis, unit tests and Android debug APK verification on pushes and pull requests.
- `android-release.yml`: manually triggered Android release APK and AAB builds. Signing is intentionally not configured until signing credentials are supplied through GitHub Actions secrets.

## Architecture principles

1. Shared Dart application/domain code.
2. Platform-specific execution adapters; no assumption that every OS exposes the same shell.
3. Android-first delivery, with all five Flutter targets scaffolded.
4. Plugin APIs are versioned and capability-based.
5. Runtime extensions must not execute arbitrary downloaded native/Dart code. Use declarative extensions or isolated external processes where platform policy permits.
6. No secrets or signing keys in source control.

## Terminal engine boundary

The UI must communicate with a typed terminal-session API. The API will eventually expose session creation, input, output events, resize, signal/close and lifecycle state. Platform adapters will implement execution using each operating system's supported process and terminal facilities.

iOS is sandboxed and does not provide unrestricted access to a system shell. Android process execution is restricted to the app sandbox unless a separately installed environment or explicitly granted integration is used. These are product constraints, not Flutter defects.

## License

Choose and add a license before public distribution.
