# AstraTerm Roadmap

## Phase 1 — Foundation
- [x] Product identity and package metadata
- [x] Shared Flutter entry point and initial UI shell
- [x] Android-first GitHub Actions CI
- [x] Android release workflow (unsigned)
- [x] Native runner bootstrap script
- [x] Architecture and platform constraints documentation

## Phase 2 — Terminal engine
- [ ] Typed terminal session API
- [x] Android app-sandbox process adapter (Phase 2.1: persisted `/system/bin/sh`
      with merged output streaming; no PTY yet)
- [x] Output streaming and input handling (Phase 2.1: EventChannel-based,
      asynchronous; character-stream only, no VT processing yet)
- [ ] Terminal emulator rendering (VT/ANSI)
- [ ] Resize, lifecycle, cancellation and error states (partial: Phase 2.1
      covers close/restart and crash-aware teardown only)
- [ ] Session persistence and tabs

### Phase 2.1 specifics and limitations

Current milestone executes the Android system shell only:

- No PTY (`TERM=dumb`; pipe-based I/O only).
- No BusyBox, no package manager and no Debian/Ubuntu userspace.
- No root privileges requested anywhere.
- Full Linux compatibility is explicitly NOT claimed.

## Phase 3 — Cross-platform execution
- [ ] Debian/Linux PTY adapter
- [ ] macOS PTY adapter
- [ ] Windows process and ConPTY adapter
- [ ] iOS app-owned restricted command adapter
- [ ] Platform capability matrix and integration tests

## Phase 4 — Advanced terminal
- [ ] SSH
- [ ] File explorer
- [ ] Shell profiles and environment settings
- [ ] Command history and palette
- [ ] Split panes and workspaces

## Phase 5 — Plugin platform
- [ ] Versioned plugin manifest and SDK
- [ ] Capability permissions
- [ ] Signature/hash verification
- [ ] Declarative extensions and desktop process plugins
- [ ] Marketplace/repository support

## Phase 6 — Production
- [ ] Signed release pipelines
- [ ] Store metadata and platform-specific packaging
- [ ] Accessibility and performance audit
- [ ] Security review and documented support matrix
