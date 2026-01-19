# Whitelist Capability

Manage which filesystem paths are visible within the playground. Uses ETS for O(1) lookups.

## ADDED Requirements

### Requirement: Whitelist can be created with initial paths

The system SHALL allow creating a whitelist with an initial set of allowed paths.

#### Scenario: Create whitelist with paths
- **WHEN** a whitelist is created with paths `["/home/user/projects", "/tmp"]`
- **THEN** both paths are immediately allowed

#### Scenario: Create empty whitelist
- **WHEN** a whitelist is created with no paths
- **THEN** no paths are allowed

---

### Requirement: Paths can be added to the whitelist

The system SHALL allow adding paths to an existing whitelist.

#### Scenario: Add single path
- **WHEN** path `/home/user/documents` is added to the whitelist
- **THEN** that path becomes allowed

#### Scenario: Add path that already exists
- **WHEN** a path that is already whitelisted is added again
- **THEN** the operation succeeds idempotently (no error, no duplicate)

---

### Requirement: Paths can be removed from the whitelist

The system SHALL allow removing paths from the whitelist.

#### Scenario: Remove existing path
- **WHEN** a whitelisted path is removed
- **THEN** that path is no longer allowed

#### Scenario: Remove non-existent path
- **WHEN** a path that is not whitelisted is removed
- **THEN** the operation succeeds idempotently (no error)

---

### Requirement: Path membership can be checked

The system SHALL provide O(1) lookup to check if a path is allowed.

#### Scenario: Check allowed path
- **WHEN** checking a path that is in the whitelist
- **THEN** return true

#### Scenario: Check disallowed path
- **WHEN** checking a path that is not in the whitelist
- **THEN** return false

---

### Requirement: Child paths inherit parent allowance

The system SHALL allow access to child paths when a parent directory is whitelisted.

#### Scenario: Access file under whitelisted directory
- **WHEN** `/home/user/projects` is whitelisted
- **AND** checking `/home/user/projects/myapp/lib/app.ex`
- **THEN** return true (child path allowed)

#### Scenario: Sibling paths are not allowed
- **WHEN** `/home/user/projects` is whitelisted
- **AND** checking `/home/user/documents/secret.txt`
- **THEN** return false (different subtree)

---

### Requirement: Bulk operations are supported

The system SHALL support adding and removing multiple paths atomically.

#### Scenario: Add multiple paths
- **WHEN** paths `["/a", "/b", "/c"]` are added in bulk
- **THEN** all paths become allowed

#### Scenario: Remove multiple paths
- **WHEN** paths `["/a", "/b"]` are removed in bulk
- **THEN** all specified paths become disallowed

---

### Requirement: Whitelist state can be listed

The system SHALL provide a way to list all currently whitelisted paths.

#### Scenario: List all paths
- **WHEN** requesting the list of whitelisted paths
- **THEN** return all top-level whitelisted paths (not expanded children)
