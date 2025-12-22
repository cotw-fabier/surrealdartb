//! Global connection registry for managing RocksDB database connections
//!
//! This module solves the Flutter Hot Restart problem where:
//! 1. Dart isolate restarts, destroying Database objects
//! 2. Native Rust library stays loaded with connections still active
//! 3. RocksDB file locks are held by the still-active connections
//! 4. New connection attempts fail with "lock held by current process"
//!
//! The solution is to track active RocksDB connections by path and automatically
//! close existing connections before creating new ones to the same path.

use std::collections::HashMap;
use std::sync::RwLock;
use lazy_static::lazy_static;
use log::{info, warn, debug};
use crate::database::Database;
use crate::runtime::get_runtime;

/// Wrapper for raw pointer to make it Send + Sync
///
/// # Safety
/// This is safe because:
/// 1. Access to the registry is synchronized via RwLock
/// 2. The Database handles are only accessed from a single Dart isolate
/// 3. The Tokio runtime handles async safety internally
#[derive(Clone, Copy)]
struct DatabaseHandle(*mut Database);

// SAFETY: We ensure thread-safety through RwLock synchronization
// and the single-isolate design of the FFI layer
unsafe impl Send for DatabaseHandle {}
unsafe impl Sync for DatabaseHandle {}

lazy_static! {
    /// Global registry of active RocksDB connections by canonical path
    /// Key: Canonical path (e.g., "/Users/.../db")
    /// Value: Wrapped raw pointer to Database handle
    ///
    /// Thread-safety: RwLock allows concurrent reads, exclusive writes
    static ref CONNECTION_REGISTRY: RwLock<HashMap<String, DatabaseHandle>> =
        RwLock::new(HashMap::new());
}

/// Extract the path from a RocksDB endpoint
///
/// Returns Some(path) for RocksDB endpoints, None for other backends (e.g., mem://)
///
/// # Examples
/// - `rocksdb:///path/to/db` -> Some("/path/to/db")
/// - `rocksdb://path/to/db` -> Some("path/to/db")
/// - `mem://` -> None
///
/// Note: We intentionally do NOT canonicalize the path because:
/// 1. The first connection might create the directory, making canonicalize succeed
/// 2. The second connection would then get a canonicalized path
/// 3. These wouldn't match, defeating the registry lookup
///
/// Instead, we use a normalized but un-canonicalized path for consistent comparison.
pub fn extract_rocksdb_path(endpoint: &str) -> Option<String> {
    if endpoint.starts_with("rocksdb://") {
        let path = endpoint.strip_prefix("rocksdb://").unwrap();
        // Normalize the path without canonicalizing:
        // - Remove trailing slashes
        // - The path should already be absolute from Dart side
        let normalized = path.trim_end_matches('/').to_string();
        debug!("Extracted RocksDB path: {} from endpoint: {}", normalized, endpoint);
        Some(normalized)
    } else {
        None
    }
}

/// Register a new connection for a RocksDB path
///
/// If a connection already exists for this path, it is returned so the caller
/// can close it properly. This should not normally happen if close_existing_connection
/// is called before creating new connections.
pub fn register_connection(path: String, handle: *mut Database) -> Option<*mut Database> {
    let mut registry = match CONNECTION_REGISTRY.write() {
        Ok(guard) => guard,
        Err(poisoned) => {
            warn!("Connection registry lock was poisoned, recovering");
            poisoned.into_inner()
        }
    };

    let old = registry.insert(path.clone(), DatabaseHandle(handle));
    if old.is_some() {
        warn!("Replaced existing connection for path: {}", path);
    } else {
        debug!("Registered new connection for path: {}", path);
    }
    old.map(|h| h.0)
}

/// Unregister a connection when it's explicitly closed
pub fn unregister_connection(path: &str) {
    let mut registry = match CONNECTION_REGISTRY.write() {
        Ok(guard) => guard,
        Err(poisoned) => {
            warn!("Connection registry lock was poisoned, recovering");
            poisoned.into_inner()
        }
    };

    if registry.remove(path).is_some() {
        debug!("Unregistered connection for path: {}", path);
    }
}

/// Close and unregister an existing connection for a path
///
/// This should be called before creating a new connection to the same path.
/// It handles the Hot Restart scenario where the old Dart isolate is gone
/// but the Rust-side connection is still active.
pub fn close_existing_connection(path: &str) {
    // First, check if there's an existing connection and remove it from registry
    let old_handle = {
        let mut registry = match CONNECTION_REGISTRY.write() {
            Ok(guard) => guard,
            Err(poisoned) => {
                warn!("Connection registry lock was poisoned, recovering");
                poisoned.into_inner()
            }
        };
        registry.remove(path).map(|h| h.0)
    };

    // If we found an old connection, close it properly
    if let Some(handle) = old_handle {
        if !handle.is_null() {
            info!("Closing existing connection for path before reconnecting: {}", path);

            unsafe {
                // Take ownership of the Database
                let db = Box::from_raw(handle);

                // Get the runtime to ensure async cleanup can complete
                let runtime = get_runtime();

                // Drop the database in an async context with cleanup delay
                let _ = runtime.block_on(async {
                    drop(db);

                    // Give RocksDB time to release file locks
                    tokio::time::sleep(std::time::Duration::from_millis(500)).await;

                    // Yield to ensure all pending tasks complete
                    for _ in 0..10 {
                        tokio::task::yield_now().await;
                    }
                });
            }

            info!("Successfully closed existing connection for path: {}", path);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_rocksdb_path() {
        // RocksDB paths should be extracted
        assert_eq!(
            extract_rocksdb_path("rocksdb:///path/to/db"),
            Some("/path/to/db".to_string())
        );
        assert_eq!(
            extract_rocksdb_path("rocksdb://relative/path"),
            Some("relative/path".to_string())
        );

        // Trailing slashes should be normalized
        assert_eq!(
            extract_rocksdb_path("rocksdb:///path/to/db/"),
            Some("/path/to/db".to_string())
        );

        // Non-RocksDB endpoints should return None
        assert_eq!(extract_rocksdb_path("mem://"), None);
        assert_eq!(extract_rocksdb_path("memory://"), None);
        assert_eq!(extract_rocksdb_path("ws://localhost:8000"), None);
    }

    #[test]
    fn test_register_unregister() {
        let path = "/test/db/path".to_string();
        let fake_handle = std::ptr::null_mut::<Database>();

        // Register should return None for new path
        assert!(register_connection(path.clone(), fake_handle).is_none());

        // Unregister should succeed
        unregister_connection(&path);

        // Register again should return None (was unregistered)
        assert!(register_connection(path.clone(), fake_handle).is_none());

        // Clean up
        unregister_connection(&path);
    }
}
