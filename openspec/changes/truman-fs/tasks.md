# Implementation Tasks

## Architecture Decisions (2026-01-18)

- **Port over NIF**: Rust daemon runs as supervised Port (crash isolation)
- **JSON protocol**: Human-readable for audit-first logging (`serde_json` in Rust, `Jason` in Elixir)
- **macFUSE + FSKit**: Userspace FUSE on macOS 26, no kernel extension needed
- **Auditor in critical path**: All messages pass through Auditor (dead man's switch)

## 1. Project Setup

- [x] 1.1 Create `truman_fs` app in umbrella
- [x] 1.2 Create Rust project for FUSE daemon (`cargo new truman_fused`)
- [x] 1.3 Add dependencies: `fuser`, `serde_json`, `serde`
- [x] 1.4 Verify Rust project compiles
- [ ] 1.5 Set up build integration (compile Rust on `mix compile`)

## 2. Whitelist Module (Pure Elixir, TDD) ✅ DONE

- [x] 2.1 Create `TrumanFs.Whitelist` module with ETS table
- [x] 2.2 Implement `new/1` - create whitelist with initial paths
- [x] 2.3 Implement `add/2` - add single path
- [x] 2.4 Implement `remove/2` - remove single path
- [x] 2.5 Implement `allowed?/2` - check if path is allowed (with prefix matching)
- [x] 2.6 Implement `add_all/2` - bulk add paths
- [x] 2.7 Implement `remove_all/2` - bulk remove paths
- [x] 2.8 Implement `list/1` - list all whitelisted paths
- [x] 2.9 Add doctests for public API

## 3. JSON Port Protocol

- [x] 3.1 Define message types (Rust side): `protocol.rs`
- [ ] 3.2 Define message types (Elixir side): `TrumanFs.Protocol`
- [ ] 3.3 Create Port wrapper GenServer: `TrumanFs.Port`
- [ ] 3.4 Test round-trip: Elixir → Rust → Elixir with JSON

## 4. Auditor (Critical Path)

- [ ] 4.1 Create `TrumanFs.Auditor` GenServer
- [ ] 4.2 Implement passthrough: receives from Port, forwards to handler, returns response
- [ ] 4.3 Implement JSON logging (human-readable audit trail)
- [ ] 4.4 Dead man's switch: if Auditor dies, Port handler crashes
- [ ] 4.5 Test: verify all operations logged, no bypass possible

## 5. FUSE Daemon (Rust)

- [ ] 5.1 Implement basic FUSE mount/unmount with `fuser`
- [ ] 5.2 Implement stdin/stdout ETF message loop
- [ ] 5.3 Implement `getattr` callback → sends request to Elixir, awaits response
- [ ] 5.4 Implement `readdir` callback → sends request, filters by response
- [ ] 5.5 Implement `open` callback → whitelist check via Elixir
- [ ] 5.6 Implement `read` callback → passthrough to real filesystem
- [ ] 5.7 Implement `write` callback → passthrough to real filesystem

## 6. Visibility Logic (Elixir Handler)

- [ ] 6.1 Create `TrumanFs.Handler` module to process FUSE requests
- [ ] 6.2 Wire whitelist checks into `getattr` (ENOENT for non-whitelisted)
- [ ] 6.3 Wire whitelist filtering into `readdir`
- [ ] 6.4 Wire whitelist checks into `open`/`read`/`write`
- [ ] 6.5 Test the 404 principle (ENOENT not EACCES)

## 7. OTP Integration

- [ ] 7.1 Create `TrumanFs.Daemon` supervisor for Port + Auditor
- [ ] 7.2 Add Daemon to application supervision tree
- [ ] 7.3 Handle clean unmount on shutdown (send shutdown message to Rust)
- [ ] 7.4 Handle crash recovery (restart Port, remount)
- [ ] 7.5 Make mount point configurable via application env

## 8. Integration Tests

- [ ] 8.1 Test: mount FUSE, create whitelisted file, verify visible
- [ ] 8.2 Test: non-whitelisted file returns ENOENT
- [ ] 8.3 Test: directory listing filters non-whitelisted entries
- [ ] 8.4 Test: add path to whitelist, file becomes visible
- [ ] 8.5 Test: remove path from whitelist, file disappears
- [ ] 8.6 Test: Auditor crash stops all operations
- [ ] 8.7 Test: Port crash triggers remount

## 9. Documentation

- [ ] 9.1 Write module docs for `TrumanFs`
- [ ] 9.2 Write README for truman_fs app
- [ ] 9.3 Document FUSE-T installation requirements
