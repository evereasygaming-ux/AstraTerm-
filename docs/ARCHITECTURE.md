# AstraTerm Architecture — Phase 1 + Phase 2.1

## Phase 2.1 — Android shell engine (current)

Phase 2.1 adds the first execution layer: a Kotlin adapter around Android's
system shell (`/system/bin/sh`) that runs inside the app sandbox. It is an
initial Android sandbox shell, NOT a complete Linux environment.

Layer layout:

- `lib/services/terminal_shell.dart`: `TerminalShellService` (Dart side). Owns
  the `com.astra.term/terminal` MethodChannel (`start`, `write`, `close`) and
  the `com.astra.term/terminal_output` EventChannel (streamed output as
  `{"type": "data", ...}` and `{"type": "exit", "code": n}` events). Surfaces
  lifecycle state and prevents interface changes from leaking into the UI.
- `native/android/MainActivity.kt` + `native/android/TerminalPlugin.kt`:
  tracked Kotlin sources. `scripts/bootstrap_flutter.sh` copies them into the
  generated Android runner (which is git-ignored) on every run, keeping the
  copy idempotent. `MainActivity` attaches the plugin to the Flutter engine
  and tears the shell down on engine cleanup.
- `TerminalPlugin` details:
  - Spawns ONE persistent process via `ProcessBuilder("/system/bin/sh")`
    (duplicate starts are detected and reported).
  - Merges stderr into stdout (`redirectErrorStream(true)`).
  - Streams merged output from a dedicated reader thread through the
    EventChannel; chunks buffered until a listener attaches.
  - `HOME` and `TMPDIR` point at application-private directories
    (`filesDir/home`, `cacheDir/tmp`).
  - `PATH` is a controlled list of Android system executable directories plus
    optional app-private `HOME/bin` / `HOME/usr/bin` prefixes (reserved for
    later milestones).
  - `TERM=dumb`: no PTY support in this milestone.
  - Root is never requested; no extra Android permissions are needed.

Known limitations (documented intentionally):

- No PTY: output is raw pipe text, not a terminal device; programs that
  require ttys (e.g. `vim`, interactive prompts) will not behave like an
  interactive terminal session.
- Only executables shipped with Android (+ anything the user places in
  app-private dirs) run: no BusyBox, no package manager, no Debian/Ubuntu
  userspace in this milestone.
- The shell is closed when the Flutter engine is destroyed (activity teardown
  matches the safest Android lifecycle semantics for child processes).

## Layering (Phase 1 baseline)

- `app`: application composition and lifecycle.
- `core`: shared primitives, errors, logging and configuration.
- `features`: user-facing feature modules.
- `packages/terminal_api` (planned): typed session contracts. Phase 2.1's
  `TerminalShellService` is the stopgap in front of it.
- `packages/terminal_engine` (planned): orchestration and event streams.
- `native/*`: platform-specific process/PTY adapters (Android Phase 2.1 in
  place; desktop platforms to follow).
- `packages/plugin_api` and `plugin_manager` (planned): versioned extension contracts and lifecycle.

## Terminal session contract (design target)

A session should expose:
- stable session ID and lifecycle state;
- `write(Uint8List)` for input;
- output stream of byte chunks;
- terminal resize (columns and rows);
- close/terminate and supported signals;
- working directory and environment metadata subject to platform restrictions.

The UI must not directly spawn processes. It talks to a domain-level session service, which selects a platform adapter.

## Platform constraints

- Android: execute only within app sandbox or through an explicitly integrated environment. Do not promise a full Linux distribution by default.
- iOS: sandboxed app-owned execution only; no unrestricted host shell.
- macOS/Linux: native process and PTY facilities, subject to permissions.
- Windows: process pipes initially; ConPTY integration for full terminal semantics.
- Remote SSH: independent transport/session adapter, not a local shell.

## Plugin security

Plugin manifests declare API compatibility and requested capabilities. Runtime extensions should use a constrained declarative format or isolated process protocol. Downloaded arbitrary executable code is not a universal cross-platform plugin strategy.
