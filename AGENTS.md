# Agent Development Guide

> Best practices for AI agents working on Truman

## Development Workflow

### Starting New Work

1. **Spec before code** — Don't just start coding, understand the architecture first

### Test-Driven Development (TDD)

> **IMPORTANT: Always follow Red-Green-Refactor!**

1. **Red** — Write a failing test that describes the desired behavior
2. **Green** — Write the minimum code to make it pass
3. **Refactor** — Clean up while keeping tests green

```elixir
# Example TDD flow

# 1. RED: Write failing test
test "whitelist allows configured paths" do
  whitelist = Truman.FS.Whitelist.new(["/home/user/projects"])
  assert Truman.FS.Whitelist.allowed?(whitelist, "/home/user/projects/foo.txt")
  refute Truman.FS.Whitelist.allowed?(whitelist, "/etc/passwd")
end

# 2. GREEN: Minimal implementation
def allowed?(whitelist, path), do: Enum.any?(whitelist.paths, &String.starts_with?(path, &1))

# 3. REFACTOR: Add edge cases, optimize
```

### Doctests for Public APIs

Use doctests where they serve as **living documentation**:

```elixir
@doc """
Check if a path is allowed by the whitelist.

## Examples

    iex> whitelist = Truman.FS.Whitelist.new(["/home/user"])
    iex> Truman.FS.Whitelist.allowed?(whitelist, "/home/user/file.txt")
    true

"""
def allowed?(%Whitelist{} = whitelist, path), do: # ...
```

**When to use doctests:**
- Public API functions that benefit from usage examples
- Contract enforcement (if the API changes, doctests fail)
- Simple, deterministic outputs

**When NOT to use doctests:**
- Complex setup required
- Non-deterministic outputs (timestamps, random data)
- Internal/private functions

## Git Practices

### Commit Early and Often

**Atomic commits > big batches**

- Each commit = one logical unit of work
- Provenance and understandability are paramount
- We use **squash merges** to main, so messy feature branches are fine

### TDD Mode: Auto-Commit

**During TDD, don't ask for commit approval** if all checks pass:

```bash
mix format && mix test  # All green? Commit without asking.
```

The TDD cycle naturally produces atomic, well-tested commits. If tests pass and code is formatted, just commit and continue. This keeps flow state intact.

**Still ask before committing when:**
- Making architectural decisions
- Changing the approach mid-implementation
- Anything outside the TDD red-green-refactor cycle

### Before Every Commit

```bash
mix format && mix test && mix credo
```

If any fail, fix before committing.

### Never Force Push

**Do NOT use `--force-push`**

If history rewriting seems necessary:
1. Ask the HITL (Human In The Loop)
2. Let them decide and execute if appropriate
3. Prefer a messy double-commit over rewritten history

### Commit Message Format

```
<type>: <short description>

<optional body explaining why, not what>
```

Types: `feat`, `fix`, `test`, `docs`, `refactor`, `chore`

## Decision Points

### When Uncertain, Ask

**Speed is good when confident. But...**

Making a choice and reverting later costs more time/energy/tokens than pausing to collaborate.

**Ask the HITL when:**
- Multiple valid approaches exist
- The choice affects architecture
- You're about to delete/rewrite significant code
- The requirement is ambiguous

**Just do it when:**
- The path is clear and well-defined
- It's easily reversible
- Tests will catch any mistakes

## Commands Reference

```bash
# Development
mix test              # Run all tests
mix test --only focus # Run focused tests
mix format            # Format code
mix credo             # Static analysis
mix dialyzer          # Type checking

# Git
git status            # Check state before commit
git add -p            # Stage interactively (atomic commits)
git commit            # Commit (never --amend without asking)
git push              # Push (never --force)
```

## Architecture Overview

Truman is an umbrella app with these sub-applications:

| App | Purpose |
|-----|---------|
| `truman_fs` | FUSE daemon, ETS whitelist, visibility control |
| `truman_auth` | RBAC, actor types, command whitelist |
| `truman_sync` | Git-annex integration, PubSub notifications |
| `truman_web` | Phoenix HTTP/WS API |
| `truman_audit` | Auditor (dead man's switch), logging |
| `truman_seatbelt` | macOS Seatbelt / Linux Landlock wrappers |

## The Prime Directive

> Have fun with it :)

This is an experimental project exploring AI playgrounds with real filesystem control. Creativity and exploration are encouraged. When in doubt, write a test and try it out.
