//! JSON Protocol for Elixir <-> Rust communication
//!
//! Message format: 4-byte big-endian length prefix + JSON payload
//! This matches Erlang's `{packet, 4}` port option.
//!
//! Design rationale: JSON chosen over ETF for "audit-first" logging.
//! The Auditor appends raw bytes to audit.jsonl BEFORE parsing, so the
//! log must be human-readable without special decoders.
//! See: openspec/changes/truman-fs/design.md - Decision 6

use anyhow::{Result, Context};
use serde::{Deserialize, Serialize};
use std::io::{self, Read, Write, BufReader, BufWriter};

/// Messages from Rust (FUSE) to Elixir (Auditor/Whitelist)
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum Request {
    /// Check if path is allowed
    Getattr { req_id: u64, path: String },

    /// List directory
    Readdir { req_id: u64, path: String },

    /// Open file
    Open { req_id: u64, path: String, flags: u32 },

    /// Read file
    Read { req_id: u64, path: String, offset: u64, size: u64 },

    /// Write file
    Write { req_id: u64, path: String, offset: u64, data: Vec<u8> },
}

/// Messages from Elixir back to Rust
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum Response {
    /// Allowed with optional file attributes
    Ok {
        req_id: u64,
        #[serde(skip_serializing_if = "Option::is_none")]
        attrs: Option<FileAttrs>,
        #[serde(skip_serializing_if = "Option::is_none")]
        entries: Option<Vec<String>>,
        #[serde(skip_serializing_if = "Option::is_none")]
        data: Option<Vec<u8>>,
        #[serde(skip_serializing_if = "Option::is_none")]
        size: Option<u64>,
    },

    /// Not found (404 principle)
    Enoent { req_id: u64 },

    /// Other error
    Error { req_id: u64, reason: String },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileAttrs {
    pub size: u64,
    pub mode: u32,
    pub mtime: i64,
    pub is_dir: bool,
}

/// Protocol handler for stdin/stdout communication
pub struct Protocol {
    reader: BufReader<io::Stdin>,
    writer: BufWriter<io::Stdout>,
}

impl Protocol {
    pub fn new() -> Self {
        Self {
            reader: BufReader::new(io::stdin()),
            writer: BufWriter::new(io::stdout()),
        }
    }

    /// Send a request to Elixir
    pub fn send(&mut self, request: &Request) -> Result<()> {
        let json = serde_json::to_string(request)
            .context("Failed to serialize request")?;

        // Write 4-byte length prefix (big-endian)
        let len = json.len() as u32;
        self.writer.write_all(&len.to_be_bytes())?;
        self.writer.write_all(json.as_bytes())?;
        self.writer.flush()?;

        Ok(())
    }

    /// Receive a response from Elixir
    pub fn recv(&mut self) -> Result<Response> {
        // Read 4-byte length prefix
        let mut len_buf = [0u8; 4];
        self.reader.read_exact(&mut len_buf)?;
        let len = u32::from_be_bytes(len_buf) as usize;

        // Read payload
        let mut payload = vec![0u8; len];
        self.reader.read_exact(&mut payload)?;

        // Decode JSON
        let response: Response = serde_json::from_slice(&payload)
            .context("Failed to decode JSON response")?;

        Ok(response)
    }
}

impl Default for Protocol {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_request_serialize() {
        let req = Request::Getattr {
            req_id: 42,
            path: "/home/user/file.txt".into(),
        };
        let json = serde_json::to_string(&req).unwrap();
        assert!(json.contains("\"op\":\"getattr\""));
        assert!(json.contains("\"req_id\":42"));
        assert!(json.contains("/home/user/file.txt"));
    }

    #[test]
    fn test_response_deserialize_ok() {
        let json = r#"{"status":"ok","req_id":42}"#;
        let resp: Response = serde_json::from_str(json).unwrap();
        match resp {
            Response::Ok { req_id, .. } => assert_eq!(req_id, 42),
            _ => panic!("Expected Ok response"),
        }
    }

    #[test]
    fn test_response_deserialize_enoent() {
        let json = r#"{"status":"enoent","req_id":42}"#;
        let resp: Response = serde_json::from_str(json).unwrap();
        match resp {
            Response::Enoent { req_id } => assert_eq!(req_id, 42),
            _ => panic!("Expected Enoent response"),
        }
    }

    #[test]
    fn test_roundtrip() {
        let req = Request::Read {
            req_id: 1,
            path: "/test".into(),
            offset: 0,
            size: 4096,
        };
        let json = serde_json::to_string(&req).unwrap();
        let decoded: Request = serde_json::from_str(&json).unwrap();

        match decoded {
            Request::Read { req_id, path, offset, size } => {
                assert_eq!(req_id, 1);
                assert_eq!(path, "/test");
                assert_eq!(offset, 0);
                assert_eq!(size, 4096);
            }
            _ => panic!("Expected Read request"),
        }
    }
}
