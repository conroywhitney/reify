# Implementation Tasks

## 1. Project Setup

- [ ] 1.1 Create `reify_fs` app in umbrella (`mix new apps/reify_fs --sup`)
- [ ] 1.2 Add Rustler dependency to `reify_fs/mix.exs`
- [ ] 1.3 Initialize Rust NIF project with `mix rustler.new`
- [ ] 1.4 Add `fuser` crate to Cargo.toml
- [ ] 1.5 Verify NIF compiles and loads (hello world function)

## 2. Whitelist Module (Pure Elixir, TDD)

- [ ] 2.1 Create `ReifyFs.Whitelist` module with ETS table
- [ ] 2.2 Implement `new/1` - create whitelist with initial paths
- [ ] 2.3 Implement `add/2` - add single path
- [ ] 2.4 Implement `remove/2` - remove single path
- [ ] 2.5 Implement `allowed?/2` - check if path is allowed (with prefix matching)
- [ ] 2.6 Implement `add_all/2` - bulk add paths
- [ ] 2.7 Implement `remove_all/2` - bulk remove paths
- [ ] 2.8 Implement `list/1` - list all whitelisted paths
- [ ] 2.9 Add doctests for public API

## 3. FUSE NIF Foundation

- [ ] 3.1 Define NIF function signatures in Elixir (`ReifyFs.Native`)
- [ ] 3.2 Implement basic FUSE mount/unmount in Rust
- [ ] 3.3 Implement `getattr` callback (return file attributes or ENOENT)
- [ ] 3.4 Implement `readdir` callback (list directory, filtering hidden entries)
- [ ] 3.5 Implement `open` callback (check whitelist before allowing)
- [ ] 3.6 Implement `read` callback (passthrough to real filesystem)
- [ ] 3.7 Implement `write` callback (passthrough to real filesystem)

## 4. Visibility Logic

- [ ] 4.1 Create `ReifyFs.Fuse.Callbacks` module to handle FUSE events
- [ ] 4.2 Wire whitelist checks into `getattr` (ENOENT for non-whitelisted)
- [ ] 4.3 Wire whitelist filtering into `readdir`
- [ ] 4.4 Wire whitelist checks into `open`/`read`/`write`
- [ ] 4.5 Test the 404 principle (ENOENT not EACCES)

## 5. OTP Integration

- [ ] 5.1 Create `ReifyFs.Fuse.Daemon` GenServer to manage mount lifecycle
- [ ] 5.2 Add Daemon to application supervision tree
- [ ] 5.3 Handle clean unmount on shutdown
- [ ] 5.4 Handle crash recovery (whitelist survives via ETS heir)
- [ ] 5.5 Make mount point configurable via application env

## 6. Integration Tests

- [ ] 6.1 Test: mount FUSE, create whitelisted file, verify visible
- [ ] 6.2 Test: non-whitelisted file returns ENOENT
- [ ] 6.3 Test: directory listing filters non-whitelisted entries
- [ ] 6.4 Test: add path to whitelist, file becomes visible
- [ ] 6.5 Test: remove path from whitelist, file disappears
- [ ] 6.6 Test: daemon crash and recovery

## 7. Documentation

- [ ] 7.1 Write module docs for `ReifyFs`
- [ ] 7.2 Write README for reify_fs app
- [ ] 7.3 Document FUSE installation requirements (macFUSE/FUSE-T)
