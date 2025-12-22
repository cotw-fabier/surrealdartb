use std::ffi::{CStr, c_char};
use std::panic;
use surrealdb::Surreal;
use surrealdb::engine::any::{Any, connect};
use crate::error::set_last_error;
use crate::runtime::get_runtime;
use crate::connection_registry::{extract_rocksdb_path, register_connection, unregister_connection, close_existing_connection};
use log::{info, debug, warn, error};

/// Opaque handle for SurrealDB database instance
///
/// This type is never constructed in Dart; it only exists as a pointer.
/// Memory management: Created via db_new(), destroyed via db_close()
pub struct Database {
    pub inner: Surreal<Any>,
    /// The original endpoint used to create this connection.
    /// Used for unregistering from the connection registry on close.
    pub endpoint: Option<String>,
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

        // For RocksDB endpoints, check if there's an existing connection and close it.
        // This handles the Flutter Hot Restart scenario where the old Dart isolate is gone
        // but the Rust-side connection is still holding the file lock.
        let rocksdb_path = extract_rocksdb_path(endpoint_str);
        if let Some(ref path) = rocksdb_path {
            info!("RocksDB endpoint detected, checking for existing connection at: {}", path);
            close_existing_connection(path);
            // Small delay to ensure RocksDB lock is fully released
            std::thread::sleep(std::time::Duration::from_millis(100));
        }

        let runtime = get_runtime();
        match runtime.block_on(async {
            connect(endpoint_str).await
        }) {
            Ok(db) => {
                let database = Box::new(Database {
                    inner: db,
                    endpoint: Some(endpoint_str.to_string()),
                });
                let handle = Box::into_raw(database);

                // Register the new connection in the registry
                if let Some(path) = rocksdb_path {
                    register_connection(path, handle);
                }

                handle
            }
            Err(e) => {
                let error_msg = e.to_string().to_lowercase();

                // If database exists or has lock issue, wait and retry
                // This handles the case where the database already exists at the path
                if error_msg.contains("already exists") ||
                   error_msg.contains("lock") ||
                   error_msg.contains("resource busy") {

                    warn!("Database exists at path, retrying connection: {}", e);
                    std::thread::sleep(std::time::Duration::from_millis(100));

                    // Retry connection
                    match runtime.block_on(async { connect(endpoint_str).await }) {
                        Ok(db) => {
                            info!("Successfully opened existing database");
                            let database = Box::new(Database {
                                inner: db,
                                endpoint: Some(endpoint_str.to_string()),
                            });
                            let handle = Box::into_raw(database);

                            // Register the new connection in the registry
                            if let Some(ref path) = extract_rocksdb_path(endpoint_str) {
                                register_connection(path.clone(), handle);
                            }

                            return handle;
                        }
                        Err(retry_err) => {
                            set_last_error(&format!(
                                "Failed to open database: {}. Original error: {}",
                                retry_err, e
                            ));
                            return std::ptr::null_mut();
                        }
                    }
                }

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

/// Begin a transaction
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
/// - Must call db_commit or db_rollback after successful begin
///
/// # Errors
/// Returns -1 and sets last error if:
/// - handle is null
/// - BEGIN TRANSACTION fails
///
/// # Implementation Note
/// This executes a "BEGIN TRANSACTION" statement to start a transaction.
/// All subsequent operations on this handle will be part of the transaction
/// until db_commit or db_rollback is called.
#[no_mangle]
pub extern "C" fn db_begin(handle: *mut Database) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            error!("[TRANSACTION] db_begin: Database handle is null");
            set_last_error("Database handle cannot be null");
            return -1;
        }

        info!("[TRANSACTION] db_begin: Starting transaction...");
        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        debug!("[TRANSACTION] db_begin: About to execute BEGIN TRANSACTION query");
        match runtime.block_on(async {
            db.inner.query("BEGIN TRANSACTION").await
        }) {
            Ok(response) => {
                info!("[TRANSACTION] db_begin: BEGIN TRANSACTION executed successfully");
                debug!("[TRANSACTION] db_begin: Response: {:?}", response);
                0
            }
            Err(e) => {
                error!("[TRANSACTION] db_begin: BEGIN TRANSACTION failed with error: {}", e);
                set_last_error(&format!("Failed to begin transaction: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => {
            info!("[TRANSACTION] db_begin: Returning result: {}", result);
            result
        }
        Err(e) => {
            error!("[TRANSACTION] db_begin: Panic occurred: {:?}", e);
            set_last_error("Panic occurred in db_begin");
            -1
        }
    }
}

/// Commit a transaction
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
/// - Must have called db_begin before calling this function
///
/// # Errors
/// Returns -1 and sets last error if:
/// - handle is null
/// - COMMIT TRANSACTION fails
/// - No transaction was started
///
/// # Implementation Note
/// This executes a "COMMIT TRANSACTION" statement to commit the current transaction.
/// If the commit fails, the transaction remains active and should be rolled back.
#[no_mangle]
pub extern "C" fn db_commit(handle: *mut Database) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            error!("[TRANSACTION] db_commit: Database handle is null");
            set_last_error("Database handle cannot be null");
            return -1;
        }

        info!("[TRANSACTION] db_commit: Committing transaction...");
        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        debug!("[TRANSACTION] db_commit: About to execute COMMIT TRANSACTION query");
        match runtime.block_on(async {
            db.inner.query("COMMIT TRANSACTION").await
        }) {
            Ok(response) => {
                info!("[TRANSACTION] db_commit: COMMIT TRANSACTION executed successfully");
                debug!("[TRANSACTION] db_commit: Response: {:?}", response);
                0
            }
            Err(e) => {
                error!("[TRANSACTION] db_commit: COMMIT TRANSACTION failed with error: {}", e);
                set_last_error(&format!("Failed to commit transaction: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => {
            info!("[TRANSACTION] db_commit: Returning result: {}", result);
            result
        }
        Err(e) => {
            error!("[TRANSACTION] db_commit: Panic occurred: {:?}", e);
            set_last_error("Panic occurred in db_commit");
            -1
        }
    }
}

/// Rollback a transaction
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
/// - Must have called db_begin before calling this function
///
/// # Errors
/// Returns -1 and sets last error if:
/// - handle is null
/// - CANCEL TRANSACTION fails
/// - No transaction was started
///
/// # Implementation Note
/// This executes a "CANCEL TRANSACTION" statement to rollback the current transaction.
/// All changes made within the transaction are discarded.
#[no_mangle]
pub extern "C" fn db_rollback(handle: *mut Database) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            error!("[TRANSACTION] db_rollback: Database handle is null");
            set_last_error("Database handle cannot be null");
            return -1;
        }

        info!("[TRANSACTION] db_rollback: Rolling back transaction...");
        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        debug!("[TRANSACTION] db_rollback: About to execute CANCEL TRANSACTION query");
        match runtime.block_on(async {
            let result = db.inner.query("CANCEL TRANSACTION").await;
            debug!("[TRANSACTION] db_rollback: CANCEL TRANSACTION query returned: {:?}", result);
            result
        }) {
            Ok(response) => {
                info!("[TRANSACTION] db_rollback: CANCEL TRANSACTION executed successfully");
                debug!("[TRANSACTION] db_rollback: Response details: {:?}", response);

                // Log additional information to help debug if changes are actually rolled back
                info!("[TRANSACTION] db_rollback: Transaction should now be rolled back");
                0
            }
            Err(e) => {
                error!("[TRANSACTION] db_rollback: CANCEL TRANSACTION failed with error: {}", e);
                set_last_error(&format!("Failed to rollback transaction: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => {
            info!("[TRANSACTION] db_rollback: Returning result: {}", result);
            result
        }
        Err(e) => {
            error!("[TRANSACTION] db_rollback: Panic occurred: {:?}", e);
            set_last_error("Panic occurred in db_rollback");
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

                // Unregister from the connection registry before closing
                // This must happen before drop so the path is still available
                if let Some(ref endpoint) = db.endpoint {
                    if let Some(path) = extract_rocksdb_path(endpoint) {
                        debug!("Unregistering connection for path: {}", path);
                        unregister_connection(&path);
                    }
                }

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

    #[test]
    fn test_transaction_begin_commit() {
        let endpoint = std::ffi::CString::new("mem://").unwrap();
        let handle = db_new(endpoint.as_ptr());
        assert!(!handle.is_null());

        let ns = std::ffi::CString::new("test").unwrap();
        assert_eq!(db_use_ns(handle, ns.as_ptr()), 0);

        let db = std::ffi::CString::new("test").unwrap();
        assert_eq!(db_use_db(handle, db.as_ptr()), 0);

        // Begin transaction
        let result = db_begin(handle);
        assert_eq!(result, 0, "BEGIN TRANSACTION should succeed");

        // Commit transaction
        let result = db_commit(handle);
        assert_eq!(result, 0, "COMMIT TRANSACTION should succeed");

        db_close(handle);
    }

    #[test]
    fn test_transaction_begin_rollback() {
        let endpoint = std::ffi::CString::new("mem://").unwrap();
        let handle = db_new(endpoint.as_ptr());
        assert!(!handle.is_null());

        let ns = std::ffi::CString::new("test").unwrap();
        assert_eq!(db_use_ns(handle, ns.as_ptr()), 0);

        let db = std::ffi::CString::new("test").unwrap();
        assert_eq!(db_use_db(handle, db.as_ptr()), 0);

        // Begin transaction
        let result = db_begin(handle);
        assert_eq!(result, 0, "BEGIN TRANSACTION should succeed");

        // Rollback transaction
        let result = db_rollback(handle);
        assert_eq!(result, 0, "CANCEL TRANSACTION should succeed");

        db_close(handle);
    }
}
