//! TrumanFS FUSE Daemon
//!
//! Communicates with Elixir via ETF over stdin/stdout.
//! All filesystem operations are checked against the Elixir-side whitelist.

mod protocol;

use anyhow::Result;
use log::info;

fn main() -> Result<()> {
    env_logger::init();

    info!("truman_fused starting");

    // TODO: Parse CLI args for mount point, source directory
    // TODO: Start ETF protocol handler
    // TODO: Mount FUSE filesystem
    // TODO: Run event loop

    println!("truman_fused: ready");

    Ok(())
}
