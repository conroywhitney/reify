## Context

Truman needs a filesystem visibility layer that makes unauthorized files literally not exist. Traditional permission models (Unix file permissions, ACLs) return "Permission denied" which reveals the existence of protected resources. We need the "404 principle" - if you can't access it, it doesn't exist.

FUSE (Filesystem in Userspace) lets us intercept filesystem operations and filter them based on a whitelist before passing through to the real filesystem.

This is the first component of the Truman stack. Other components (`truman_seatbelt`, `truman_auth`, `truman_web`) will build on this foundation.

## Goals / Non-Goals

**Goals:**
- Provide whitelist-based filesystem visibility control
- Implement the 404 principle (ENOENT, not EACCES)
- O(1) path lookups via ETS
- OTP supervision for fault tolerance
- macOS support via macFUSE or FUSE-T
- Clean, testable Elixir API for whitelist management

**Non-Goals:**
- Linux support (future work, different FUSE library)
- Windows support (separate effort entirely)
- Network filtering (that's `truman_seatbelt` + proxy layer)
- Command whitelisting (that's `truman_auth`)
- Full POSIX reimplementation (we dropped that approach)

## Decisions

### Decision 1: FUSE for Visibility Control

**Choice**: Use FUSE to make non-whitelisted files invisible

**Alternatives considered**:
- **Chroot**: Can be escaped, doesn't hide file existence
- **Containers/VMs**: Too heavyweight, complex setup
- **LD_PRELOAD hooks**: Can be bypassed, only works for dynamically linked binaries
- **Reimplementing filesystem commands**: What we did in truman-shell, too much surface area

**Rationale**: FUSE operates at the kernel level. Once mounted, all filesystem access goes through our code - there's no bypassing it from userspace. We get real commands (`ls`, `cat`, `grep`) for free; we just control what they can see.

---

### Decision 2: ETS for Whitelist Storage

**Choice**: Store whitelist in ETS (Erlang Term Storage)

**Alternatives considered**:
- **GenServer state**: Lost on crash, slower for concurrent reads
- **Mnesia**: Overkill for single-node in-memory data
- **External DB**: Unnecessary latency and complexity

**Rationale**: ETS provides:
- O(1) lookups
- Concurrent reads without bottleneck
- Survives process crashes (if owned by supervisor)
- No external dependencies

---

### Decision 3: Prefix-Based Path Matching

**Choice**: Whitelist directories, allow all children automatically

**Alternatives considered**:
- **Exact path matching**: Would require listing every file
- **Glob patterns**: More complex, harder to reason about
- **Regex patterns**: Even more complex, security footgun

**Rationale**: If `/home/user/projects` is whitelisted, then `/home/user/projects/app/lib/module.ex` is automatically allowed. Simple mental model, easy to implement with `String.starts_with?/2`.

---

### Decision 4: macFUSE with FSKit Backend

**Choice**: Use macFUSE 5.1.3+ with FSKit backend on macOS 26+

**Context**:
- **macFUSE (old)**: Required kernel extension, user had to enable in System Settings
- **FUSE-T**: Userspace FUSE, no kext, but limited `fuser` crate support
- **macFUSE 5.1.3+ FSKit**: New backend runs entirely in userspace on macOS 26, no kext needed

**Rationale**: macFUSE 5.1.3 (Dec 2025) added FSKit backend which gives us the best of both worlds: full `fuser` crate compatibility AND no kernel extension on macOS 26. Mount with `-o backend=fskit` for userspace mode.

---

### Decision 5: Port over NIF for FUSE Daemon

**Choice**: Run Rust FUSE daemon as supervised Port, not NIF

**Alternatives considered**:
- **Rustler NIF**: Fast calls, shared memory, but NIF crash = BEAM crash
- **Port (external process)**: Crash isolation, non-blocking, IPC overhead

**Rationale**: FUSE operations are inherently async (kernel calls us). A Port is cleaner - the Rust daemon runs independently, sends events to Elixir via stdin/stdout. If the Rust process crashes, BEAM survives and can restart it. Supervision becomes straightforward OTP.

---

### Decision 6: JSON Protocol for Audit-First Logging

**Choice**: Use JSON for Port communication, not ETF (Erlang Term Format)

**Alternatives considered**:
- **ETF**: Native to Elixir, slightly faster, but binary blobs in logs
- **JSON**: Human-readable, standard tooling, self-documenting logs
- **MessagePack**: Binary but structured, middle ground

**Rationale**: The Auditor's first action is to append raw bytes to the audit log BEFORE parsing. This "log first, parse second" pattern ensures no operation goes unrecorded. For this to work, the raw log must be readable without special decoders:

```
# With JSON Lines - immediately useful:
$ tail audit.jsonl
{"op":"getattr","path":"/home/user/secret.txt","req_id":42}

# With ETF - need decoder:
$ tail audit.log
<<131,104,3,100,0,7,...>>  # What does this mean?
```

For forensics, compliance, and debugging, anyone can read JSON with `cat`, `grep`, `jq`. ETF requires trusting a decoder. The audit trail must be self-documenting.

---

### Decision 7: Passthrough Architecture

**Choice**: Pass allowed operations through to real filesystem, filter disallowed ones

**Alternatives considered**:
- **Virtual filesystem**: Store files in ETS/memory (what truman-shell was heading toward)
- **Copy-on-write overlay**: Complex, overkill for visibility control

**Rationale**: We're not trying to virtualize the filesystem - we just want to control visibility. Real files, real operations, just filtered access.

## Risks / Trade-offs

### Risk: FUSE Performance Overhead
Every filesystem operation goes through userspace. For heavy I/O workloads, this adds latency.

**Mitigation**: This is acceptable for our use case (AI agent playground). We're not building a high-performance storage system. Profile if needed, but don't prematurely optimize.

---

### Risk: macFUSE/FUSE-T Installation Requirement
Users must install FUSE support manually (not bundled with macOS).

**Mitigation**: Clear documentation. Consider checking for FUSE availability at startup and providing helpful error messages.

---

### Risk: Port Process Crashes
A bug in the Rust FUSE daemon could crash the external process.

**Mitigation**:
- OTP supervision restarts the Port automatically
- BEAM VM survives Port crashes (unlike NIFs)
- Auditor logs capture state before crash for debugging

---

### Risk: ETS Table Ownership
If the process that owns the ETS table crashes, the table is deleted.

**Mitigation**: Have the supervisor own the ETS table (heir pattern), or use a dedicated ETS manager process that's restarted on crash.

## Module Structure

```
truman/
├── apps/truman_fs/
│   ├── lib/
│   │   ├── truman_fs.ex              # Public API
│   │   ├── truman_fs/
│   │   │   ├── application.ex        # OTP Application
│   │   │   ├── whitelist.ex          # ETS-backed whitelist
│   │   │   ├── auditor.ex            # Critical path: log first, process second
│   │   │   ├── handler.ex            # Process FUSE requests, check whitelist
│   │   │   ├── port.ex               # GenServer wrapping Rust Port
│   │   │   └── protocol.ex           # JSON message encode/decode
│   │   └── ...
│   └── test/
│       ├── whitelist_test.exs
│       └── auditor_test.exs
│
└── native/truman_fused/              # Rust FUSE daemon (separate binary)
    ├── Cargo.toml
    └── src/
        ├── main.rs                   # Entry point, CLI args
        ├── protocol.rs               # JSON message encode/decode
        └── fuse.rs                   # FUSE callbacks using fuser crate
```

**Data flow:**
```
Kernel (FUSE) → Rust daemon → JSON/stdout → Elixir Port
                                              ↓
                                          Auditor (log first!)
                                              ↓
                                          Handler (whitelist check)
                                              ↓
                                          JSON/stdin → Rust → Kernel
```

## Open Questions

1. **How to test FUSE operations?**
   - Option A: Mount for real in test, use temp directories
   - Option B: Mock the NIF layer, test Elixir logic only
   - Likely: Both - unit tests mock NIF, integration tests mount for real

2. **ETS table naming**
   - Named table (single global whitelist) vs reference-based (multiple whitelists)?
   - Leaning toward named table for simplicity, can evolve later

3. **Whitelist hot-reload**
   - Can the whitelist be modified while FUSE is mounted?
   - Yes, ETS updates are atomic. But do we need to signal the NIF?
