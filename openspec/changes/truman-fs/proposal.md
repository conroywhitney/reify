## Why

Agents need a filesystem playground where unauthorized files literally don't exist (404, not 403). Current containment approaches either block everything (unusable) or leak information through permission errors (probeable). FUSE lets us control visibility at the kernel level, making the whitelist unforgeable by processes inside the playground.

This is the foundation layer that all other Truman components build on. Without filesystem visibility control, the rest of the stack has nothing to protect.

## What Changes

- New `truman_fs` umbrella app with OTP supervision tree
- ETS-backed whitelist for O(1) path lookups
- FUSE daemon that filters `readdir`, `getattr`, `open` based on whitelist
- The "404 principle" - non-whitelisted paths return ENOENT (No such file), not EACCES (Permission denied)
- macOS-first implementation using macFUSE or FUSE-T

## Capabilities

### New Capabilities

- `whitelist`: Manage allowed paths in ETS - add, remove, check, bulk operations, pattern matching
- `fuse-visibility`: FUSE callbacks that enforce the whitelist, implementing the 404 principle

### Modified Capabilities

(none - this is the first component)

## Impact

### Dependencies
- Requires FUSE library for Elixir (research needed: Rust NIF vs existing binding)
- macOS: requires macFUSE or FUSE-T installed by user

### Platform Scope
- **macOS**: Primary target (this change)
- **Linux**: Future work (libfuse + Landlock) - not in scope
- **Windows**: Separate effort entirely (WinFsp + AppContainer) - not in scope

### Downstream
- Foundation for `truman_seatbelt` (defense in depth)
- Foundation for `truman_auth` (command whitelist checks paths)
- Foundation for `truman_web` (API exposes whitelist management)

## Open Questions

- **FUSE library choice**: Rust NIF (write our own) vs existing Elixir/Erlang binding?
- **macFUSE vs FUSE-T**: macFUSE requires kernel extension approval; FUSE-T uses newer macOS APIs but is less mature
