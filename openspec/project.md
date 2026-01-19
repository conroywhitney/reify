# Project Context

> "LiveView for the Filesystem"

## Purpose

A secure, reactive filesystem shell where human and AI operate in the same sandboxed environment. Files only exist if they're whitelisted. Commands only run if they're allowed. Everything is mediated, auditable, and fail-safe.

**Core Insight**: Helpful agents are more dangerous than malicious ones. A playground that says "yes" to safe things beats a prison that says "no" to everything.

## Tech Stack

- **Elixir/OTP** - Supervision trees, fault tolerance, concurrency
- **Phoenix** - HTTP/WebSocket API (reify_web)
- **FUSE** - Filesystem in Userspace for visibility control
- **Seatbelt/Landlock** - OS-level sandbox enforcement
- **ETS** - In-memory whitelist storage
- **Git-annex** - Large file synchronization

## Project Conventions

### Code Style

- `mix format` - Standard Elixir formatter
- `mix credo --strict` - Static analysis
- `mix dialyzer` - Type checking with Dialyxir
- Snake_case for modules (`ReifyFs`), functions (`allowed?`), variables

### Architecture Patterns

**Umbrella App Structure:**

| App | Purpose |
|-----|---------|
| `reify_fs` | FUSE daemon, ETS whitelist, visibility control |
| `reify_auth` | RBAC, actor types, command whitelist |
| `reify_sync` | Git-annex integration, PubSub notifications |
| `reify_web` | Phoenix HTTP/WS API |
| `reify_audit` | Auditor (dead man's switch), logging |
| `reify_seatbelt` | macOS Seatbelt / Linux Landlock wrappers |

**Defense in Depth:**
1. FUSE - Files don't exist outside whitelist (visibility)
2. Seatbelt/Landlock - Kernel-level enforcement (backup)
3. Command whitelist - Only approved commands run (RBAC)
4. Auditor - Dead man's switch supervision (fail-safe)

### Testing Strategy

**TDD: Red-Green-Refactor**
1. Write a failing test
2. Write minimum code to pass
3. Refactor while keeping green

**Doctests for Public APIs** - Living documentation that enforces contracts

**Test Private Functions Through Public API** - If it needs its own tests, it should be its own module

### Git Workflow

- Feature branches: `feature/<name>`, `chore/<name>`, `fix/<name>`
- Squash merges to main
- Atomic commits preferred
- Auto-commit in TDD mode when tests pass
- Never force push

## Domain Context

### The 404 Principle
Protected paths return "No such file or directory" NOT "Permission denied" — prevents probing attacks. Files outside the whitelist literally don't exist from the perspective of processes in the sandbox.

### Actor Types
Different actors (human, agent, git, web) get different permissions:
- **Human**: Full access (different sandbox)
- **Agent**: Read whitelisted files, run whitelisted commands
- **Git**: Access specific repos, not all of GitHub
- **Web**: Blocklist + whitelist + HITL approval

### Key Decisions
1. FUSE for visibility (not just permissions)
2. Seatbelt as backup defense layer
3. External .git directories (no info leak)
4. Git-annex for large files (not WebSocket streaming)
5. Command whitelist with RBAC
6. Drop POSIX reimplementation - use real commands
7. Auditor as dead man's switch
8. Two-layer network control (Seatbelt + Proxy)

## Important Constraints

- **Security First**: Every design decision prioritizes containment
- **Fail-Safe**: If supervision fails, sandbox collapses to deny-all
- **No Info Leak**: Even error messages shouldn't reveal protected paths
- **Cross-Platform**: macOS (Seatbelt) and Linux (Landlock) support needed

## External Dependencies

- **FUSE**: macFUSE or FUSE-T on macOS, libfuse on Linux
- **Git-annex**: For large file sync
- **Phoenix PubSub**: For reactive notifications
- **Seatbelt**: macOS sandbox-exec
- **Landlock**: Linux kernel sandboxing (5.13+)
