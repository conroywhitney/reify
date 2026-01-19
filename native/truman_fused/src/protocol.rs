//! JSON Protocol for Elixir <-> Rust communication
//!
//! # Wire Format
//!
//! Messages use a 4-byte big-endian length prefix followed by JSON payload.
//! This matches Erlang's `{packet, 4}` port option.
//!
//! ```text
//! +----------------+------------------+
//! | length (4B BE) | JSON payload     |
//! +----------------+------------------+
//! ```
//!
//! # Design Rationale
//!
//! JSON was chosen over ETF (Erlang Term Format) for "audit-first" logging.
//! The Auditor writes raw bytes to audit.jsonl BEFORE parsing, so logs must
//! be human-readable without special decoders.
//!
//! Binary data (file contents) is base64-encoded within JSON to ensure
//! safe transport and human-readable logs.
//!
//! See: openspec/changes/truman-fs/design.md - Decision 6

use anyhow::{bail, Result, Context};
use base64::{Engine, engine::general_purpose::STANDARD as BASE64};
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use std::io::{self, Read, Write, BufReader, BufWriter};

/// Maximum message size (16 MiB).
///
/// Protects against memory exhaustion from malicious/corrupted length prefixes.
/// This is generous for filesystem metadata; actual file I/O uses chunked reads.
const MAX_MESSAGE_SIZE: usize = 16 * 1024 * 1024;

/// Messages from Rust (FUSE) to Elixir (Auditor/Whitelist)
///
/// Each FUSE callback generates a request that is sent to Elixir for
/// whitelist checking and actual filesystem operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum Request {
    /// Get file/directory attributes (stat)
    Getattr { req_id: u64, path: String },

    /// List directory contents
    Readdir { req_id: u64, path: String },

    /// Open a file (check permissions)
    Open { req_id: u64, path: String, flags: u32 },

    /// Read file contents
    Read { req_id: u64, path: String, offset: u64, size: u64 },

    /// Write file contents (base64-encoded data)
    Write {
        req_id: u64,
        path: String,
        offset: u64,
        #[serde(serialize_with = "serialize_base64", deserialize_with = "deserialize_base64")]
        data: Vec<u8>,
    },
}

/// Messages from Elixir back to Rust
///
/// Responses indicate success/failure and carry any requested data.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum Response {
    /// Operation succeeded with optional payload
    Ok {
        req_id: u64,
        /// File attributes (for getattr)
        #[serde(skip_serializing_if = "Option::is_none")]
        attrs: Option<FileAttrs>,
        /// Directory entries (for readdir)
        #[serde(skip_serializing_if = "Option::is_none")]
        entries: Option<Vec<String>>,
        /// File contents, base64-encoded (for read)
        #[serde(
            skip_serializing_if = "Option::is_none",
            serialize_with = "serialize_base64_option",
            deserialize_with = "deserialize_base64_option",
            default
        )]
        data: Option<Vec<u8>>,
        /// Bytes written (for write)
        #[serde(skip_serializing_if = "Option::is_none")]
        size: Option<u64>,
    },

    /// Path not found (implements "404 principle" - no info leak about existence)
    Enoent { req_id: u64 },

    /// Other error with human-readable reason
    Error { req_id: u64, reason: String },
}

/// POSIX-like file attributes
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileAttrs {
    /// File size in bytes
    pub size: u64,
    /// File mode (permissions + type bits)
    pub mode: u32,
    /// Last modification time (Unix timestamp)
    pub mtime: i64,
    /// True if this is a directory
    pub is_dir: bool,
}

// === Base64 Serde Helpers ===

fn serialize_base64<S>(data: &[u8], serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    serializer.serialize_str(&BASE64.encode(data))
}

fn deserialize_base64<'de, D>(deserializer: D) -> Result<Vec<u8>, D::Error>
where
    D: Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;
    BASE64.decode(&s).map_err(serde::de::Error::custom)
}

fn serialize_base64_option<S>(data: &Option<Vec<u8>>, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    match data {
        Some(bytes) => serializer.serialize_some(&BASE64.encode(bytes)),
        None => serializer.serialize_none(),
    }
}

fn deserialize_base64_option<'de, D>(deserializer: D) -> Result<Option<Vec<u8>>, D::Error>
where
    D: Deserializer<'de>,
{
    let opt: Option<String> = Option::deserialize(deserializer)?;
    match opt {
        Some(s) => BASE64.decode(&s)
            .map(Some)
            .map_err(serde::de::Error::custom),
        None => Ok(None),
    }
}

/// Protocol handler for stdin/stdout communication with Elixir
///
/// Uses length-prefixed JSON messages matching Erlang's `{packet, 4}` option.
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

        // Write 4-byte length prefix (big-endian) + payload
        let len = json.len() as u32;
        self.writer.write_all(&len.to_be_bytes())?;
        self.writer.write_all(json.as_bytes())?;
        self.writer.flush()?;

        Ok(())
    }

    /// Receive a response from Elixir
    ///
    /// Includes bounds checking on length prefix to prevent memory exhaustion
    /// from malicious or corrupted messages (similar to MongoBleed CVE-2025-14847).
    pub fn recv(&mut self) -> Result<Response> {
        // Read 4-byte length prefix
        let mut len_buf = [0u8; 4];
        self.reader.read_exact(&mut len_buf)?;
        let len = u32::from_be_bytes(len_buf) as usize;

        // Bounds check: prevent memory exhaustion from malicious length prefix
        if len > MAX_MESSAGE_SIZE {
            bail!(
                "Message size {} exceeds maximum {} bytes",
                len,
                MAX_MESSAGE_SIZE
            );
        }

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
    fn test_write_request_base64() {
        let req = Request::Write {
            req_id: 1,
            path: "/test".into(),
            offset: 0,
            data: vec![0x00, 0x01, 0x02, 0xFF],
        };
        let json = serde_json::to_string(&req).unwrap();
        // Data should be base64-encoded, not raw bytes
        assert!(json.contains("\"data\":\"AAEC/w==\""));
    }

    #[test]
    fn test_write_request_roundtrip() {
        let original = Request::Write {
            req_id: 1,
            path: "/test".into(),
            offset: 100,
            data: vec![0xDE, 0xAD, 0xBE, 0xEF],
        };
        let json = serde_json::to_string(&original).unwrap();
        let decoded: Request = serde_json::from_str(&json).unwrap();

        match decoded {
            Request::Write { req_id, path, offset, data } => {
                assert_eq!(req_id, 1);
                assert_eq!(path, "/test");
                assert_eq!(offset, 100);
                assert_eq!(data, vec![0xDE, 0xAD, 0xBE, 0xEF]);
            }
            _ => panic!("Expected Write request"),
        }
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
    fn test_response_ok_with_base64_data() {
        // Test deserializing response with base64 data
        let json = r#"{"status":"ok","req_id":1,"data":"SGVsbG8gV29ybGQ="}"#;
        let resp: Response = serde_json::from_str(json).unwrap();
        match resp {
            Response::Ok { req_id, data, .. } => {
                assert_eq!(req_id, 1);
                assert_eq!(data, Some(b"Hello World".to_vec()));
            }
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
    fn test_roundtrip_read_request() {
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
