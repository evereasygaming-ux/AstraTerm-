# AstraTerm

AstraTerm is a Flutter-based, cross-platform terminal application.

## Identity

- Product name: AstraTerm
- Flutter package: `astraterm`
- Android application ID / Apple bundle ID: `com.astra.term`
- Initial delivery priority: Android first, then iOS, macOS, Windows and Debian Linux.

## Phase 1 status

This repository contains the shared Flutter application foundation, an Android-first CI workflow, and a platform bootstrap script. It is **not yet a complete terminal emulator**. The process/PTY engine, terminal rendering, shell adapters, SSH and runtime plugin system are later milestones.

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

The bootstrap script generates Android, iOS, macOS, Windows and Linux runner projects using Flutter, while preserving AstraTerm's Dart source and package metadata. It uses `com.astra.term` as the native application/bundle identifier.

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
