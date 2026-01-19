# Reify - Claude Context

> "LiveView for the Filesystem"

## What Is This?

A secure, reactive filesystem shell where human and AI operate in the same shared playground. Files only exist if they're whitelisted. Commands only run if they're allowed. Everything is mediated, auditable, and fail-safe.

## Key Concepts

### The 404 Principle
Protected paths return "No such file or directory" NOT "Permission denied" — prevents probing attacks.

### Core Insight
**Helpful agents are more dangerous than malicious ones.** Claude escaped ClaudeBox by wanting to run Elixir — not by being adversarial. A playground that says "yes" to safe things beats a prison that says "no" to everything.

### Defense in Depth
Multiple independent layers:
1. **FUSE** — Files don't exist outside whitelist (visibility)
2. **Seatbelt/Landlock** — Kernel-level enforcement (backup)
3. **Command whitelist** — Only approved commands run (RBAC)
4. **Auditor** — Dead man's switch supervision (fail-safe)

## Architecture

```
Agent sends: "grep TODO src/*.ex | head -5"
                    │
                    ▼
         ┌─────────────────────┐
         │   HTTP/WS API       │ → Phoenix (reify_web)
         ├─────────────────────┤
         │   Command Whitelist │ → RBAC check (reify_auth)
         ├─────────────────────┤
         │   Seatbelt Wrap     │ → sandbox-exec (reify_seatbelt)
         ├─────────────────────┤
         │   FUSE Mount        │ → Only whitelisted files visible (reify_fs)
         └─────────────────────┘
                    │
                    ▼
         Real grep, real files, real output
         (but only what you're allowed to see)
```

## Sub-Applications

| App | Description |
|-----|-------------|
| `reify_fs` | FUSE daemon with ETS-backed whitelist |
| `reify_auth` | Actor types, command whitelist, RBAC |
| `reify_sync` | Git-annex for large files, PubSub |
| `reify_web` | Phoenix HTTP/WS API |
| `reify_audit` | Dead man's switch, logging |
| `reify_seatbelt` | OS sandbox wrappers |

## Key Decisions

1. **FUSE for visibility** — Files outside whitelist don't exist
2. **Seatbelt as backup** — Kernel enforcement if FUSE bypassed
3. **External .git** — No info leak from git internals
4. **Git-annex for large files** — Not raw WebSocket streaming
5. **Command whitelist with RBAC** — Per-actor permissions
6. **Drop POSIX reimplementation** — Real commands in playground
7. **Auditor as dead man's switch** — Fail-safe supervision
8. **Network gatekeepers** — Seatbelt + Proxy for URL filtering

## Related Projects

| Project | Location | Relationship |
|---------|----------|--------------|
| VFS Spike | https://github.com/conroywhitney/vfs_spike/ | Early FUSE experiments |
| Truman Shell | https://github.com/conroywhitney/truman-shell | POSIX reimplementation (superseded) |
| ClaudeBox | https://github.com/conroywhitney/claudebox/ | Original sandboxing research |
| IExReAct | https://github.com/conroywhitney/IExReAct | Agent loop (will consume Reify) |

## Commands

```bash
mix test              # Run tests
mix deps.get          # Fetch dependencies
mix format            # Format code
mix credo --strict    # Static analysis
mix dialyzer          # Type checking
```

## Testing Philosophy

### Doctests = Living Documentation
Doctests serve dual purposes:
1. **Documentation** — Users see real, working examples in the docs
2. **Regression tests** — If the API changes, doctests fail immediately

### Test Private Functions Through Public API
- Elixir culture: if it's private (`defp`), it's an implementation detail
- If a private function needs its own tests, it should be its own module

## Open Questions

- **FUSE library**: Rust NIF vs existing Elixir/Erlang binding?
- **macOS FUSE**: macFUSE vs FUSE-T?

## Current State

Ready to implement. Start with `reify_fs` (FUSE daemon with ETS whitelist).
