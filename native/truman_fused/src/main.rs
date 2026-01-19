//! TrumanFS FUSE Daemon
//!
//! Communicates with Elixir via JSON over stdin/stdout (4-byte length prefix).
//! All filesystem operations are checked against the Elixir-side whitelist.
//!
//! JSON chosen over ETF for "audit-first" logging - the Auditor appends raw
//! bytes to audit.jsonl BEFORE parsing, so logs must be human-readable.

mod protocol;

use anyhow::Result;
use log::info;

fn main() -> Result<()> {
    env_logger::init();

    info!("truman_fused starting");

    // TODO: Parse CLI args for mount point, source directory
    // TODO: Start JSON protocol handler
    // TODO: Mount FUSE filesystem
    // TODO: Run event loop

    println!("truman_fused: ready");

    Ok(())
}
