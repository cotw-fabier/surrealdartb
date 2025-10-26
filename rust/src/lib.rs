/// SurrealDB FFI Bindings for Dart
///
/// This library provides C-compatible FFI functions for accessing SurrealDB
/// from Dart via the dart:ffi package.
///
/// # Architecture
///
/// The FFI layer follows these key principles:
/// - All functions use #[no_mangle] and extern "C" for C ABI compatibility
/// - Panic safety: All entry points wrapped with std::panic::catch_unwind
/// - Error handling: Integer return codes (0=success, -1=error) with thread-local error messages
/// - Memory management: Opaque handles using Box::into_raw/Box::from_raw pattern
/// - Async operations: Tokio runtime with block_on() for SurrealDB async functions
///
/// # Threading Model
///
/// All FFI functions are designed to be called from a single Dart isolate.
/// The underlying Tokio runtime is thread-safe and handles async operations.
///
/// # Safety Contracts
///
/// Rust Side Guarantees:
/// - Never panic across FFI boundary (use catch_unwind)
/// - Return error codes, never Result types
/// - Null pointer checks before all dereferencing
/// - Thread-safe via single-isolate design
/// - Store error messages in thread-local storage
///
/// Dart Side Requirements:
/// - Validate non-null before passing pointers to native
/// - Free all allocated strings in finally blocks
/// - Attach finalizers to all native resource wrappers
/// - Never expose raw Pointer types in public API
/// - Catch all exceptions in isolate message handlers

use std::sync::Once;

pub mod error;
pub mod runtime;
pub mod database;
pub mod query;
pub mod auth;
// pub mod live_query;

// Re-export main FFI functions for convenience
pub use error::{get_last_error, free_string, free_error_string};
pub use database::{db_new, db_connect, db_use_ns, db_use_db, db_close, db_begin, db_commit, db_rollback};
pub use query::{
    db_query, response_get_results, response_has_errors, response_free, response_get_errors,
    db_select, db_get, db_create, db_update, db_delete,
    db_upsert_content, db_upsert_merge, db_upsert_patch, db_insert,
    db_export, db_import, db_set, db_unset, db_run, db_version
};
pub use auth::{db_signin, db_signup, db_authenticate, db_invalidate};
// pub use live_query::{db_select_live, db_live_poll, db_kill_live};

static INIT_LOGGER: Once = Once::new();

/// Initialize the Rust logger for FFI debugging
///
/// This function initializes env_logger to enable logging from Rust code.
/// Call this once at the start of your application before making any other FFI calls.
///
/// Logging can be controlled via the RUST_LOG environment variable:
/// - RUST_LOG=info  - Show info, warn, and error logs
/// - RUST_LOG=debug - Show debug, info, warn, and error logs
/// - RUST_LOG=trace - Show all logs including trace level
///
/// # Safety
/// This function is safe to call multiple times. Only the first call will initialize the logger.
#[no_mangle]
pub extern "C" fn init_logger() {
    INIT_LOGGER.call_once(|| {
        let _ = env_logger::try_init();
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn test_end_to_end_workflow() {
        // Create database
        let endpoint = CString::new("mem://").unwrap();
        let db_handle = db_new(endpoint.as_ptr());
        assert!(!db_handle.is_null());

        // Connect
        let result = db_connect(db_handle);
        assert_eq!(result, 0);

        // Use namespace and database
        let ns = CString::new("test").unwrap();
        let result = db_use_ns(db_handle, ns.as_ptr());
        assert_eq!(result, 0);

        let db = CString::new("test").unwrap();
        let result = db_use_db(db_handle, db.as_ptr());
        assert_eq!(result, 0);

        // Execute query
        let sql = CString::new("INFO FOR DB;").unwrap();
        let response = db_query(db_handle, sql.as_ptr());
        assert!(!response.is_null());

        // Check for errors
        let has_errors = response_has_errors(response);
        assert_eq!(result, 0);

        // Clean up
        response_free(response);
        db_close(db_handle);
    }

    #[test]
    fn test_crud_operations() {
        // Create database
        let endpoint = CString::new("mem://").unwrap();
        let db_handle = db_new(endpoint.as_ptr());
        assert!(!db_handle.is_null());

        // Set namespace and database
        let ns = CString::new("test").unwrap();
        let result = db_use_ns(db_handle, ns.as_ptr());
        assert_eq!(result, 0, "use_ns should succeed");

        let db = CString::new("test").unwrap();
        let result = db_use_db(db_handle, db.as_ptr());
        assert_eq!(result, 0, "use_db should succeed");

        // Create a record
        let table = CString::new("person").unwrap();
        let data = CString::new(r#"{"name": "John", "age": 30}"#).unwrap();
        let create_response = db_create(db_handle, table.as_ptr(), data.as_ptr());
        assert!(!create_response.is_null(), "create should return a valid response");
        response_free(create_response);

        // Select records
        let select_response = db_select(db_handle, table.as_ptr());
        assert!(!select_response.is_null());

        let results_json = response_get_results(select_response);
        assert!(!results_json.is_null());

        unsafe {
            let c_str = std::ffi::CStr::from_ptr(results_json);
            let json_str = c_str.to_str().unwrap();
            // Results should be a JSON array
            assert!(json_str.starts_with('['));
        }

        free_string(results_json);
        response_free(select_response);

        // Clean up
        db_close(db_handle);
    }

    #[test]
    fn test_error_handling() {
        // Test with null handle
        let result = db_connect(std::ptr::null_mut());
        assert_eq!(result, -1);

        // Get error message
        let error_ptr = get_last_error();
        assert!(!error_ptr.is_null());

        unsafe {
            let c_str = std::ffi::CStr::from_ptr(error_ptr);
            let error_msg = c_str.to_str().unwrap();
            assert!(error_msg.contains("cannot be null"));
        }

        free_string(error_ptr);
    }

    #[test]
    fn test_string_allocation() {
        // Test that we can allocate and free strings without leaks
        let endpoint = CString::new("mem://").unwrap();
        let db_handle = db_new(endpoint.as_ptr());
        assert!(!db_handle.is_null());

        let ns = CString::new("test").unwrap();
        db_use_ns(db_handle, ns.as_ptr());

        let db = CString::new("test").unwrap();
        db_use_db(db_handle, db.as_ptr());

        let sql = CString::new("SELECT * FROM nonexistent").unwrap();
        let response = db_query(db_handle, sql.as_ptr());
        assert!(!response.is_null());

        let results = response_get_results(response);
        assert!(!results.is_null());

        free_string(results);
        response_free(response);
        db_close(db_handle);
    }
}
