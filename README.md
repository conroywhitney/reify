# Truman

A secure playground for human+AI collaboration. Truman provides visibility control, audit logging, and network gating so AI agents can work with real tools while humans maintain oversight.

## Philosophy

- **Playground, not sandbox**: Co-creation, not containment
- **Additive security**: Whitelist what's allowed, everything else doesn't exist
- **404 principle**: Unauthorized resources return "not found", not "permission denied"
- **Audit-first**: Every operation is logged before processing (no "oops" without a record)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Truman Stack                         │
├─────────────────────────────────────────────────────────────┤
│  truman_web     │ Phoenix API for session management        │
│  truman_auth    │ Command whitelist + RBAC                  │
│  truman_fs      │ FUSE-based filesystem visibility    ◄───  │
│  truman_seatbelt│ macOS sandbox profiles                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Rust Daemons   │
                    │  (truman_fused) │
                    └─────────────────┘
```

## Apps

| App | Status | Description |
|-----|--------|-------------|
| `truman_fs` | In Progress | Filesystem visibility via FUSE |
| `truman_auth` | Planned | Command whitelist and RBAC |
| `truman_seatbelt` | Planned | macOS Seatbelt wrapper |
| `truman_web` | Planned | Phoenix HTTP/WebSocket API |

## Getting Started

```bash
# Prerequisites
# - Elixir 1.19+ / OTP 27+
# - Rust (via rustup)
# - macFUSE 5.1.3+ (brew install --cask macfuse)

# Install dependencies
mix deps.get

# Build Rust daemon
cd native/truman_fused && cargo build --release

# Run tests
mix test
```

## Key Design Decisions

See `openspec/changes/truman-fs/design.md` for detailed rationale.

1. **FUSE for visibility** - Kernel-level interception, no bypass from userspace
2. **Port over NIF** - Crash isolation (Rust crash doesn't kill BEAM)
3. **JSON protocol** - Audit logs must be human-readable without decoders
4. **macFUSE + FSKit** - Userspace on macOS 26, no kernel extension

## Development

```bash
# Format code
mix format

# Run linter
mix credo

# Run type checker
mix dialyzer
```

## License

MIT
