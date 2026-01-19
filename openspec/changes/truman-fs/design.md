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

### Decision 4: macFUSE vs FUSE-T

**Choice**: Support both, prefer FUSE-T on macOS 12.3+

**Context**:
- **macFUSE**: Mature, well-tested, but requires kernel extension (user must approve in System Settings)
- **FUSE-T**: Uses newer macOS APIs (no kernel extension), but less mature

**Rationale**: FUSE-T is the future direction for macOS. Kernel extensions are being deprecated. But macFUSE has better compatibility and documentation. Support both, document tradeoffs.

---

### Decision 5: Rust NIF for FUSE Bindings

**Choice**: Write a Rust NIF that wraps the `fuser` crate

**Alternatives considered**:
- **Existing Elixir FUSE library**: None mature enough
- **Erlang port to C**: More complex FFI, memory safety concerns
- **Pure Elixir**: Not possible, FUSE requires native code

**Rationale**: Rust's `fuser` crate is well-maintained and handles the low-level FUSE protocol. Rustler makes Elixir NIFs straightforward. We get memory safety, good performance, and maintainable code.

---

### Decision 6: Passthrough Architecture

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

### Risk: NIF Crashes Take Down BEAM VM
A bug in the Rust NIF could crash the entire Erlang VM.

**Mitigation**:
- Use Rustler's safe patterns
- Extensive testing of the NIF
- Consider running FUSE in a separate OS process and communicating via port (future optimization)

---

### Risk: ETS Table Ownership
If the process that owns the ETS table crashes, the table is deleted.

**Mitigation**: Have the supervisor own the ETS table (heir pattern), or use a dedicated ETS manager process that's restarted on crash.

## Module Structure

```
apps/truman_fs/
├── lib/
│   ├── truman_fs.ex              # Public API
│   ├── truman_fs/
│   │   ├── application.ex       # OTP Application
│   │   ├── whitelist.ex         # ETS-backed whitelist
│   │   ├── fuse/
│   │   │   ├── daemon.ex        # GenServer managing FUSE mount
│   │   │   └── callbacks.ex     # FUSE operation handlers
│   │   └── native.ex            # Rustler NIF module
│   └── ...
├── native/
│   └── truman_fs_nif/            # Rust NIF using fuser crate
│       ├── Cargo.toml
│       └── src/
│           └── lib.rs
└── test/
    ├── whitelist_test.exs
    └── fuse_test.exs
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
