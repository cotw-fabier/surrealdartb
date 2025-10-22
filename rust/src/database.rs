use std::ffi::{CStr, c_char};
use std::panic;
use surrealdb::Surreal;
use surrealdb::engine::any::{Any, connect};
use crate::error::set_last_error;
use crate::runtime::get_runtime;

/// Opaque handle for SurrealDB database instance
///
/// This type is never constructed in Dart; it only exists as a pointer.
/// Memory management: Created via db_new(), destroyed via db_close()
pub struct Database {
    pub inner: Surreal<Any>,
}

/// Create a new SurrealDB database instance
///
/// # Arguments
/// * `endpoint` - C string specifying the database endpoint (e.g., "mem://", "rocksdb://path")
///
/// # Returns
/// Pointer to Database handle, or null on failure
///
/// # Safety
/// - endpoint must be a valid null-terminated C string
/// - Returned pointer must be freed via db_close()
/// - Passing null for endpoint returns null
///
/// # Errors
/// Returns null and sets last error if:
/// - endpoint is null
/// - endpoint is not valid UTF-8
/// - Connection creation fails
#[no_mangle]
pub extern "C" fn db_new(endpoint: *const c_char) -> *mut Database {
    match panic::catch_unwind(|| {
        if endpoint.is_null() {
            set_last_error("Endpoint cannot be null");
            return std::ptr::null_mut();
        }

        let endpoint_str = unsafe {
            match CStr::from_ptr(endpoint).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in endpoint");
                    return std::ptr::null_mut();
                }
            }
        };

        let runtime = get_runtime();
        match runtime.block_on(async {
            connect(endpoint_str).await
        }) {
            Ok(db) => {
                let database = Box::new(Database { inner: db });
                Box::into_raw(database)
            }
            Err(e) => {
                set_last_error(&format!("Failed to create database: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_new");
            std::ptr::null_mut()
        }
    }
}

/// Connect to the database asynchronously
///
/// # Arguments
/// * `handle` - Pointer to Database instance
///
/// # Returns
/// 0 on success, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - Passing null returns -1
///
/// # Errors
/// Returns -1 and sets last error if:
/// - handle is null
/// - Connection fails
#[no_mangle]
pub extern "C" fn db_connect(handle: *mut Database) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        let _db = unsafe { &mut *handle };

        // For SurrealDB 2.0, connection happens in db_new via connect()
        // This function is kept for API compatibility
        0
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_connect");
            -1
        }
    }
}

/// Set the namespace to use for database operations
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `ns` - C string specifying the namespace
///
/// # Returns
/// 0 on success, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - ns must be a valid null-terminated C string
/// - Passing null for either parameter returns -1
#[no_mangle]
pub extern "C" fn db_use_ns(handle: *mut Database, ns: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        if ns.is_null() {
            set_last_error("Namespace cannot be null");
            return -1;
        }

        let ns_str = unsafe {
            match CStr::from_ptr(ns).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in namespace");
                    return -1;
                }
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        match runtime.block_on(async {
            db.inner.use_ns(ns_str).await
        }) {
            Ok(_) => 0,
            Err(e) => {
                set_last_error(&format!("Failed to use namespace: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_use_ns");
            -1
        }
    }
}

/// Set the database to use for operations
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `db` - C string specifying the database name
///
/// # Returns
/// 0 on success, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - db must be a valid null-terminated C string
/// - Passing null for either parameter returns -1
#[no_mangle]
pub extern "C" fn db_use_db(handle: *mut Database, db: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        if db.is_null() {
            set_last_error("Database name cannot be null");
            return -1;
        }

        let db_str = unsafe {
            match CStr::from_ptr(db).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in database name");
                    return -1;
                }
            }
        };

        let database = unsafe { &mut *handle };
        let runtime = get_runtime();

        match runtime.block_on(async {
            database.inner.use_db(db_str).await
        }) {
            Ok(_) => 0,
            Err(e) => {
                set_last_error(&format!("Failed to use database: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_use_db");
            -1
        }
    }
}

/// Close and free the database instance
///
/// # Arguments
/// * `handle` - Pointer to Database instance
///
/// # Safety
/// - handle should be a valid pointer obtained from db_new()
/// - After calling this function, the handle is invalid and must not be used
/// - Passing null is safe and does nothing
/// - Do not call this function twice on the same pointer
///
/// # Implementation Details
/// This function performs graceful shutdown by:
/// 1. Taking ownership of the Database from the raw pointer
/// 2. Giving the async runtime time to flush pending operations
/// 3. Explicitly dropping the database to trigger cleanup
/// 4. Allowing the runtime to process any final cleanup tasks
///
/// This ensures RocksDB file locks and other resources are properly released
/// before the function returns, preventing "lock held by current process" errors
/// when reconnecting to the same database path.
#[no_mangle]
pub extern "C" fn db_close(handle: *mut Database) {
    let _ = panic::catch_unwind(|| {
        if !handle.is_null() {
            unsafe {
                // Take ownership of the Database
                let db = Box::from_raw(handle);

                // Get the runtime to ensure async cleanup can complete
                let runtime = get_runtime();

                // Explicitly drop the database in an async context
                // This ensures any background tasks spawned by the drop handler
                // have a chance to run before we return
                let _ = runtime.block_on(async {
                    // Drop the database first
                    drop(db);

                    // Critical: Give the runtime substantial time to process cleanup tasks
                    // SurrealDB's RocksDB backend spawns background tasks for shutdown
                    // that must complete before the file lock is released
                    //
                    // We use a long delay because:
                    // 1. RocksDB needs to flush WAL and memtables
                    // 2. Background cleanup tasks need to finish
                    // 3. File system locks take time to release
                    tokio::time::sleep(std::time::Duration::from_millis(500)).await;

                    // Yield multiple times to ensure all pending tasks complete
                    for _ in 0..10 {
                        tokio::task::yield_now().await;
                    }
                });
            }
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_db_new_with_mem_endpoint() {
        let endpoint = std::ffi::CString::new("mem://").unwrap();
        let handle = db_new(endpoint.as_ptr());
        assert!(!handle.is_null());
        db_close(handle);
    }

    #[test]
    fn test_db_new_with_null_endpoint() {
        let handle = db_new(std::ptr::null());
        assert!(handle.is_null());
    }

    #[test]
    fn test_db_use_ns_and_db() {
        let endpoint = std::ffi::CString::new("mem://").unwrap();
        let handle = db_new(endpoint.as_ptr());
        assert!(!handle.is_null());

        let ns = std::ffi::CString::new("test").unwrap();
        let result = db_use_ns(handle, ns.as_ptr());
        assert_eq!(result, 0);

        let db = std::ffi::CString::new("test").unwrap();
        let result = db_use_db(handle, db.as_ptr());
        assert_eq!(result, 0);

        db_close(handle);
    }

    #[test]
    fn test_db_close_null_handle() {
        // Should not panic
        db_close(std::ptr::null_mut());
    }
}
