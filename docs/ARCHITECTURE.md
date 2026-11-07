# AstraTerm Architecture — Phase 1

## Layering

- `app`: application composition and lifecycle.
- `core`: shared primitives, errors, logging and configuration.
- `features`: user-facing feature modules.
- `packages/terminal_api` (planned): typed session contracts.
- `packages/terminal_engine` (planned): orchestration and event streams.
- `native/*` (planned): platform-specific process/PTY adapters.
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
