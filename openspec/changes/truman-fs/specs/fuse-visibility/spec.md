# FUSE Visibility Capability

FUSE daemon that enforces whitelist-based visibility. Implements the "404 principle" - non-whitelisted paths don't exist.

## ADDED Requirements

### Requirement: The 404 Principle

The system SHALL return "No such file or directory" (ENOENT) for non-whitelisted paths, NOT "Permission denied" (EACCES).

#### Scenario: Access non-whitelisted file
- **WHEN** a process attempts to access `/etc/passwd` (not whitelisted)
- **THEN** return ENOENT ("No such file or directory")
- **AND** the error message SHALL NOT reveal that the file exists but is restricted

#### Scenario: Access whitelisted file
- **WHEN** a process attempts to access `/home/user/projects/app.ex` (whitelisted)
- **THEN** allow the operation to proceed to the real filesystem

---

### Requirement: Directory listings are filtered

The system SHALL filter `readdir` results to only show whitelisted entries.

#### Scenario: List directory with mixed visibility
- **WHEN** `/home/user` contains `projects/` (whitelisted) and `secrets/` (not whitelisted)
- **AND** a process calls `readdir` on `/home/user`
- **THEN** only `projects/` appears in the listing
- **AND** `secrets/` is completely absent (not hidden, not permission-denied)

#### Scenario: List fully whitelisted directory
- **WHEN** all contents of a directory are whitelisted
- **THEN** `readdir` returns all entries

#### Scenario: List directory with no whitelisted contents
- **WHEN** no contents of a directory are whitelisted
- **THEN** `readdir` returns empty (just `.` and `..`)

---

### Requirement: File attributes respect visibility

The system SHALL return ENOENT for `getattr` on non-whitelisted paths.

#### Scenario: Stat non-whitelisted file
- **WHEN** a process calls `stat` on a non-whitelisted path
- **THEN** return ENOENT

#### Scenario: Stat whitelisted file
- **WHEN** a process calls `stat` on a whitelisted path
- **THEN** return the real file attributes from the underlying filesystem

---

### Requirement: File operations respect visibility

The system SHALL return ENOENT for `open`, `read`, `write` on non-whitelisted paths.

#### Scenario: Open non-whitelisted file
- **WHEN** a process attempts to `open` a non-whitelisted file
- **THEN** return ENOENT

#### Scenario: Read whitelisted file
- **WHEN** a process reads from an open whitelisted file
- **THEN** return the real file contents

#### Scenario: Write to whitelisted file
- **WHEN** a process writes to an open whitelisted file
- **THEN** write to the real underlying file

---

### Requirement: FUSE mount is supervised

The system SHALL run the FUSE daemon under OTP supervision.

#### Scenario: FUSE daemon crashes
- **WHEN** the FUSE daemon process crashes
- **THEN** the supervisor restarts it
- **AND** the whitelist state is preserved (ETS survives restart)

#### Scenario: Clean shutdown
- **WHEN** the application stops
- **THEN** the FUSE mount is cleanly unmounted

---

### Requirement: Mount point is configurable

The system SHALL allow configuring where the FUSE filesystem is mounted.

#### Scenario: Configure mount point
- **WHEN** the application starts with mount_point set to `/playground`
- **THEN** the FUSE filesystem is mounted at `/playground`

#### Scenario: Access through mount point
- **WHEN** a whitelisted path is `/home/user/projects/app.ex`
- **AND** the mount point is `/playground`
- **THEN** the file is accessible at `/playground/home/user/projects/app.ex`

---

### Requirement: Passthrough to real filesystem

The system SHALL pass allowed operations through to the real underlying filesystem.

#### Scenario: Create file in whitelisted directory
- **WHEN** a process creates a new file in a whitelisted directory
- **THEN** the file is created on the real filesystem
- **AND** the new file inherits whitelist status from parent

#### Scenario: Delete whitelisted file
- **WHEN** a process deletes a whitelisted file
- **THEN** the file is deleted from the real filesystem
