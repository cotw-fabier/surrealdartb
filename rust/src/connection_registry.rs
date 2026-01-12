//! Global connection registry for managing RocksDB database connections
//!
//! This module solves the Flutter Hot Restart problem where:
//! 1. Dart isolate restarts, destroying Database objects
//! 2. Native Rust library stays loaded with connections still active
//! 3. RocksDB file locks are held by the still-active connections
//! 4. New connection attempts fail with "lock held by current process"
//!
//! The solution uses connection reuse with reference counting:
//! - When a connection request comes for an already-open path, return the existing handle
//! - Reference counting ensures the connection stays alive until all Dart references are gone
//! - This avoids the timing issues with closing and reopening connections

use std::collections::HashMap;
use std::sync::RwLock;
use lazy_static::lazy_static;
use log::{info, warn, debug};
use crate::database::Database;
use crate::runtime::get_runtime;

/// Wrapper for raw pointer with reference counting
///
/// # Safety
/// This is safe because:
/// 1. Access to the registry is synchronized via RwLock
/// 2. The Database handles are only accessed from a single Dart isolate
/// 3. The Tokio runtime handles async safety internally
#[derive(Clone)]
struct DatabaseHandle {
    ptr: *mut Database,
    ref_count: usize,
}

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

/// Check if there's an active connection for a given path
///
/// This is used by verification to skip closing active connections,
/// which would cause use-after-free crashes on the Dart side.
pub fn has_active_connection(path: &str) -> bool {
    let registry = match CONNECTION_REGISTRY.read() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    };
    registry.contains_key(path)
}

/// Get an existing connection for reuse, incrementing its reference count
///
/// This is the primary mechanism for handling Flutter Hot Restart:
/// instead of closing and reopening (which has lock timing issues),
/// we return the existing connection and increment its ref count.
///
/// Returns Some(handle) if a connection exists for the path, None otherwise.
pub fn get_or_reuse_connection(path: &str) -> Option<*mut Database> {
    let mut registry = match CONNECTION_REGISTRY.write() {
        Ok(guard) => guard,
        Err(poisoned) => {
            warn!("Connection registry lock was poisoned, recovering");
            poisoned.into_inner()
        }
    };

    if let Some(handle) = registry.get_mut(path) {
        handle.ref_count += 1;
        info!(
            "Reusing existing connection for path: {} (ref_count now {})",
            path, handle.ref_count
        );
        Some(handle.ptr)
    } else {
        None
    }
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
/// Creates a new registry entry with ref_count = 1.
/// If a connection already exists for this path, it is returned so the caller
/// can close it properly (this should not normally happen with the reuse pattern).
pub fn register_connection(path: String, handle: *mut Database) -> Option<*mut Database> {
    debug!("register_connection: handle {:p} for path '{}'", handle, path);

    let mut registry = match CONNECTION_REGISTRY.write() {
        Ok(guard) => guard,
        Err(poisoned) => {
            warn!("Connection registry lock was poisoned, recovering");
            poisoned.into_inner()
        }
    };

    let new_handle = DatabaseHandle {
        ptr: handle,
        ref_count: 1,
    };

    let old = registry.insert(path.clone(), new_handle);
    if old.is_some() {
        warn!("Replaced existing connection for path: {}", path);
    } else {
        debug!("Registered new connection for path: {} (ref_count=1, registry now has {} entries)", path, registry.len());
    }
    old.map(|h| h.ptr)
}

/// Decrement reference count for a connection
///
/// Returns true if ref_count reached 0 and the connection was removed
/// (caller should actually close the connection).
/// Returns false if ref_count is still > 0 (caller should NOT close).
pub fn unregister_connection(path: &str) -> bool {
    let mut registry = match CONNECTION_REGISTRY.write() {
        Ok(guard) => guard,
        Err(poisoned) => {
            warn!("Connection registry lock was poisoned, recovering");
            poisoned.into_inner()
        }
    };

    if let Some(handle) = registry.get_mut(path) {
        if handle.ref_count > 1 {
            handle.ref_count -= 1;
            info!(
                "Decremented ref_count for path: {} (ref_count now {})",
                path, handle.ref_count
            );
            return false; // Don't close yet, still has references
        }
    }

    // ref_count is 1 or entry doesn't exist - remove and close
    if registry.remove(path).is_some() {
        info!("Unregistered connection for path: {} (ref_count reached 0)", path);
        true // Caller should close the connection
    } else {
        debug!("No connection found to unregister for path: {}", path);
        true // No entry, but still return true to allow close attempt
    }
}

/// Check if a database handle is still valid (registered in the connection registry)
///
/// This function should be called before dereferencing a handle to prevent
/// use-after-free crashes when a database has been closed but the Dart side
/// still holds a stale pointer.
///
/// # Safety
/// This only checks if the handle is registered. The caller must still ensure
/// proper synchronization when accessing the handle.
pub fn is_handle_valid(handle: *mut Database) -> bool {
    if handle.is_null() {
        return false;
    }

    let registry = match CONNECTION_REGISTRY.read() {
        Ok(guard) => guard,
        Err(poisoned) => {
            warn!("Connection registry lock was poisoned during validation, recovering");
            poisoned.into_inner()
        }
    };

    registry.values().any(|h| h.ptr == handle)
}

/// Force close and unregister an existing connection for a path
///
/// This is a fallback for when connection reuse isn't possible.
/// It forcefully closes the connection regardless of ref_count.
///
/// Note: With the new reuse pattern, this should rarely be needed.
/// Prefer get_or_reuse_connection() for normal Hot Restart handling.
pub fn close_existing_connection(path: &str) {
    debug!("close_existing_connection: called for path '{}'", path);

    // First, check if there's an existing connection and remove it from registry
    let old_handle = {
        let mut registry = match CONNECTION_REGISTRY.write() {
            Ok(guard) => guard,
            Err(poisoned) => {
                warn!("Connection registry lock was poisoned, recovering");
                poisoned.into_inner()
            }
        };
        registry.remove(path).map(|h| h.ptr)
    };

    // If we found an old connection, close it properly
    if let Some(handle) = old_handle {
        if !handle.is_null() {
            info!("Force closing existing connection for path: {}", path);

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

            info!("Successfully force closed connection for path: {}", path);
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

        // Unregister should succeed and return true (ref_count was 1)
        assert!(unregister_connection(&path));

        // Register again should return None (was unregistered)
        assert!(register_connection(path.clone(), fake_handle).is_none());

        // Clean up
        let _ = unregister_connection(&path);
    }

    #[test]
    fn test_ref_counting() {
        let path = "/test/db/refcount".to_string();
        let fake_handle = 0x1234 as *mut Database;

        // Register new connection (ref_count = 1)
        assert!(register_connection(path.clone(), fake_handle).is_none());

        // Reuse should return the same handle and increment ref_count
        let reused = get_or_reuse_connection(&path);
        assert_eq!(reused, Some(fake_handle));

        // First unregister: ref_count 2 -> 1, should return false (don't close)
        assert!(!unregister_connection(&path));

        // Second unregister: ref_count 1 -> 0, should return true (close now)
        assert!(unregister_connection(&path));

        // Third unregister: already removed, should return true (no entry)
        assert!(unregister_connection(&path));
    }

    #[test]
    fn test_get_or_reuse_nonexistent() {
        let path = "/test/db/nonexistent".to_string();

        // Should return None for path that doesn't exist
        assert!(get_or_reuse_connection(&path).is_none());
    }
}
