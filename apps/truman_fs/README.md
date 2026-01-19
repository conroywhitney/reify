# TrumanFS

Filesystem visibility control via FUSE. Makes unauthorized files literally not exist.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                           User/Agent                            │
│                         ls /home/user/                          │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                         FUSE (Kernel)                           │
│              Intercepts all filesystem operations               │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    truman_fused (Rust daemon)                   │
│                  Receives FUSE callbacks, asks Elixir           │
└─────────────────────────────────────────────────────────────────┘
                                │ JSON over stdin/stdout
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Elixir Port                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │   Auditor   │───▶│   Handler   │───▶│     Whitelist       │ │
│  │ (log first) │    │ (check path)│    │      (ETS)          │ │
│  └─────────────┘    └─────────────┘    └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────┐
                    │   Real Filesystem │
                    │   (passthrough)   │
                    └───────────────────┘
```

## The 404 Principle

Traditional permissions:
```
$ cat /secret/file.txt
Permission denied    # Reveals the file exists!
```

TrumanFS:
```
$ cat /secret/file.txt
No such file or directory    # File doesn't exist (to you)
```

## Whitelist API

```elixir
# Create a whitelist
{:ok, whitelist} = TrumanFs.Whitelist.new(["/home/user/projects"])

# Add paths
TrumanFs.Whitelist.add(whitelist, "/home/user/documents")

# Check if path is allowed (includes children)
TrumanFs.Whitelist.allowed?(whitelist, "/home/user/projects/app/lib/main.ex")
# => true

TrumanFs.Whitelist.allowed?(whitelist, "/home/user/secrets/passwords.txt")
# => false

# List all whitelisted paths
TrumanFs.Whitelist.list(whitelist)
# => ["/home/user/projects", "/home/user/documents"]
```

## Audit-First Logging

Every operation is logged BEFORE processing:

```
$ tail -f /var/log/truman/audit.jsonl
{"op":"getattr","path":"/home/user/projects","req_id":1}
{"op":"readdir","path":"/home/user/projects","req_id":2}
{"op":"open","path":"/home/user/projects/app.ex","req_id":3}
```

Why `.jsonl`? JSON Lines format - one JSON object per line. The Auditor writes raw bytes to disk before parsing. If something crashes, you can still read the log with standard tools (`cat`, `grep`, `jq`). Binary formats like ETF would require a decoder. See Decision 6 in `openspec/changes/truman-fs/design.md`.

## Requirements

- **macOS 26+** with macFUSE 5.1.3+ (FSKit backend, no kernel extension)
- **Elixir 1.19+** / OTP 27+
- **Rust** (for building `truman_fused`)

```bash
# Install macFUSE
brew install --cask macfuse
```

## Module Structure

```
lib/truman_fs/
├── application.ex    # OTP Application supervisor
├── whitelist.ex      # ETS-backed path whitelist (done)
├── auditor.ex        # Log-first, process-second
├── handler.ex        # FUSE request processing
├── port.ex           # GenServer wrapping Rust Port
└── protocol.ex       # JSON encode/decode
```

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| FUSE library | `fuser` crate | Well-maintained, Rust safety |
| Communication | Port (not NIF) | Crash isolation |
| Protocol | JSON (not ETF) | Audit logs must be human-readable |
| macOS FUSE | macFUSE + FSKit | Userspace, no kext on macOS 26 |
| Whitelist storage | ETS | O(1) lookups, concurrent reads |

See `../../openspec/changes/truman-fs/design.md` for full rationale.

## Testing

```bash
# Unit tests (whitelist, protocol)
cd apps/truman_fs && mix test

# Integration tests (requires macFUSE)
mix test --include integration
```

## Development

```bash
# Build Rust daemon
cd native/truman_fused
cargo build

# Run with logging
RUST_LOG=debug cargo run -- --mount /tmp/truman_test --source /home/user
```
