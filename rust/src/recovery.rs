//! Database recovery functions for RocksDB
//!
//! This module provides FFI functions for verifying database integrity
//! and repairing corrupted RocksDB databases.
//!
//! # Usage
//!
//! These functions work directly on file system paths, not through SurrealDB.
//! They should be called before attempting to open a database that might be corrupted.
//!
//! # Safety
//!
//! All functions:
//! - Are wrapped in panic::catch_unwind for FFI safety
//! - Close any existing connections to the path before operating
//! - Set error messages via thread-local storage on failure

use std::ffi::{CStr, c_char};
use std::panic;
use std::path::Path;
use rocksdb::{DB, Options};
use crate::error::set_last_error;
use crate::connection_registry::close_existing_connection;
use log::{info, warn, error, debug};

/// Repair a corrupted RocksDB database
///
/// This function attempts to repair a RocksDB database that has become corrupted
/// due to improper shutdown, missing files, or other issues.
///
/// # Arguments
/// * `path` - C string pointer to the file system path of the RocksDB database directory
///
/// # Returns
/// * `0` - Repair successful
/// * `-1` - Repair failed (check get_last_error() for details)
///
/// # Safety
/// - path must be a valid null-terminated C string
/// - The function will close any existing connections to this path before repair
/// - A 500ms delay is used after closing to ensure lock release
///
/// # Example (from Dart)
/// ```dart
/// final result = dbRepairRocksDB(pathPtr);
/// if (result != 0) {
///     final error = getLastError();
///     // Handle error
/// }
/// ```
#[no_mangle]
pub extern "C" fn db_repair_rocksdb(path: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        // Null check
        if path.is_null() {
            set_last_error("Path cannot be null");
            return -1;
        }

        // Convert C string to Rust
        let path_str = unsafe {
            match CStr::from_ptr(path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in path");
                    return -1;
                }
            }
        };

        info!("Attempting to repair RocksDB at: {}", path_str);

        // Close any existing connection to this path
        close_existing_connection(path_str);

        // Wait for file locks to be released
        std::thread::sleep(std::time::Duration::from_millis(500));

        // Verify the path exists
        let db_path = Path::new(path_str);
        if !db_path.exists() {
            set_last_error(&format!("Database path does not exist: {}", path_str));
            return -1;
        }

        // Configure repair options
        let opts = Options::default();

        // Attempt repair
        match DB::repair(&opts, path_str) {
            Ok(_) => {
                info!("Successfully repaired RocksDB at: {}", path_str);
                0
            }
            Err(e) => {
                let error_msg = format!("Failed to repair RocksDB: {}", e);
                error!("{}", error_msg);
                set_last_error(&error_msg);
                -1
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred during database repair");
            -1
        }
    }
}

/// Verify integrity of a RocksDB database
///
/// This function checks the health of a RocksDB database by examining its
/// critical files (MANIFEST, CURRENT) and attempting a read-only open.
///
/// # Arguments
/// * `path` - C string pointer to the file system path of the RocksDB database directory
///
/// # Returns
/// * `0` - Database is healthy (or path doesn't exist, meaning new DB can be created)
/// * `1` - Database is corrupted but likely repairable (missing/corrupted MANIFEST, SST files)
/// * `2` - Database has severe corruption (missing CURRENT file, no MANIFEST)
/// * `-1` - Error during verification (check get_last_error() for details)
///
/// # Corruption Detection
///
/// The function detects corruption by:
/// 1. Checking for existence of CURRENT file
/// 2. Checking for existence of at least one MANIFEST file
/// 3. Attempting to open the database in read-only mode
///
/// # Safety
/// - path must be a valid null-terminated C string
/// - The function will close any existing connections to this path
/// - Read-only open ensures no modifications to the database
///
/// # Example (from Dart)
/// ```dart
/// final health = dbVerifyRocksDB(pathPtr);
/// switch (health) {
///     case 0: print('Database is healthy');
///     case 1: print('Database is corrupted but repairable');
///     case 2: print('Database has severe corruption');
///     default: print('Verification error: ${getLastError()}');
/// }
/// ```
#[no_mangle]
pub extern "C" fn db_verify_rocksdb(path: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        // Null check
        if path.is_null() {
            set_last_error("Path cannot be null");
            return -1;
        }

        // Convert C string to Rust
        let path_str = unsafe {
            match CStr::from_ptr(path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in path");
                    return -1;
                }
            }
        };

        debug!("Verifying RocksDB integrity at: {}", path_str);

        let db_path = Path::new(path_str);

        // If path doesn't exist, database is "healthy" (will be created fresh)
        if !db_path.exists() {
            debug!("Database path does not exist, reporting as healthy (new DB)");
            return 0;
        }

        // If path exists but is not a directory, that's an error
        if !db_path.is_dir() {
            set_last_error(&format!("Path exists but is not a directory: {}", path_str));
            return -1;
        }

        // Check for CURRENT file (critical)
        let current_file = db_path.join("CURRENT");
        let has_current = current_file.exists();

        // Check for MANIFEST files
        let has_manifest = match db_path.read_dir() {
            Ok(entries) => entries
                .filter_map(|e| e.ok())
                .any(|e| {
                    let name = e.file_name();
                    let name_str = name.to_string_lossy();
                    name_str.starts_with("MANIFEST-")
                }),
            Err(e) => {
                set_last_error(&format!("Failed to read database directory: {}", e));
                return -1;
            }
        };

        // If missing critical files, report severe corruption
        if !has_current {
            warn!("CURRENT file missing at: {}", path_str);
            set_last_error("CURRENT file is missing - severe corruption");
            return 2;
        }

        if !has_manifest {
            warn!("No MANIFEST file found at: {}", path_str);
            set_last_error("No MANIFEST file found - severe corruption");
            return 2;
        }

        // Check if there's an active connection - if so, the database is healthy
        // (it's currently in use). We should NOT close it as that would cause
        // use-after-free crashes on the Dart side.
        if crate::connection_registry::has_active_connection(path_str) {
            debug!("Database at {} has active connection, assuming healthy", path_str);
            return 0; // Healthy - it's actively being used
        }

        // No active connection, safe to do read-only verification
        // Try to open in read-only mode to verify integrity
        let mut opts = Options::default();
        // Limit resources for verification
        opts.set_max_open_files(10);

        match DB::open_for_read_only(&opts, path_str, false) {
            Ok(db) => {
                // Explicitly drop to release resources
                drop(db);
                debug!("Database verified healthy at: {}", path_str);
                0 // Healthy
            }
            Err(e) => {
                let err_str = e.to_string().to_lowercase();

                // Check for corruption indicators
                if err_str.contains("corruption")
                    || err_str.contains("manifest")
                    || err_str.contains("sst")
                    || err_str.contains("no such file")
                    || err_str.contains("invalid argument") {

                    warn!("Corruption detected at {}: {}", path_str, e);
                    set_last_error(&format!("Corruption detected: {}", e));
                    1 // Repairable corruption
                } else if err_str.contains("lock") || err_str.contains("resource busy") {
                    // Lock issues aren't corruption, they're access problems
                    warn!("Lock issue at {}: {}", path_str, e);
                    set_last_error(&format!("Database is locked: {}", e));
                    -1
                } else {
                    // Unknown error during verification
                    error!("Verification failed at {}: {}", path_str, e);
                    set_last_error(&format!("Verification failed: {}", e));
                    -1
                }
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred during database verification");
            -1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn test_verify_nonexistent_path() {
        let path = CString::new("/nonexistent/path/that/does/not/exist").unwrap();
        let result = db_verify_rocksdb(path.as_ptr());
        assert_eq!(result, 0, "Non-existent path should be considered healthy (new DB)");
    }

    #[test]
    fn test_verify_null_path() {
        let result = db_verify_rocksdb(std::ptr::null());
        assert_eq!(result, -1, "Null path should return error");
    }

    #[test]
    fn test_repair_null_path() {
        let result = db_repair_rocksdb(std::ptr::null());
        assert_eq!(result, -1, "Null path should return error");
    }

    #[test]
    fn test_repair_nonexistent_path() {
        let path = CString::new("/nonexistent/path/that/does/not/exist").unwrap();
        let result = db_repair_rocksdb(path.as_ptr());
        assert_eq!(result, -1, "Non-existent path should fail repair");
    }

    #[test]
    fn test_verify_empty_directory() {
        let dir = tempdir().unwrap();
        let path = CString::new(dir.path().to_str().unwrap()).unwrap();

        // Empty directory should report severe corruption (no CURRENT file)
        let result = db_verify_rocksdb(path.as_ptr());
        assert_eq!(result, 2, "Empty directory should report severe corruption");
    }

    #[test]
    fn test_verify_missing_manifest() {
        let dir = tempdir().unwrap();

        // Create CURRENT file but no MANIFEST
        fs::write(dir.path().join("CURRENT"), "MANIFEST-000001\n").unwrap();

        let path = CString::new(dir.path().to_str().unwrap()).unwrap();
        let result = db_verify_rocksdb(path.as_ptr());
        assert_eq!(result, 2, "Missing MANIFEST should report severe corruption");
    }

    #[test]
    fn test_verify_healthy_db() {
        // Create a real RocksDB database
        let dir = tempdir().unwrap();
        let db_path = dir.path().to_str().unwrap();

        // Create and close a database to generate valid files
        {
            let db = DB::open_default(db_path).unwrap();
            db.put(b"test", b"value").unwrap();
            // db drops here, closing the database
        }

        // Now verify it
        let path = CString::new(db_path).unwrap();
        let result = db_verify_rocksdb(path.as_ptr());
        assert_eq!(result, 0, "Healthy database should return 0");
    }

    #[test]
    fn test_repair_healthy_db() {
        // Create a real RocksDB database
        let dir = tempdir().unwrap();
        let db_path = dir.path().to_str().unwrap();

        // Create and close a database
        {
            let db = DB::open_default(db_path).unwrap();
            db.put(b"test", b"value").unwrap();
        }

        // Repair should succeed even on healthy DB
        let path = CString::new(db_path).unwrap();
        let result = db_repair_rocksdb(path.as_ptr());
        assert_eq!(result, 0, "Repair on healthy database should succeed");

        // Database should still be accessible after repair
        let db = DB::open_default(db_path).unwrap();
        let value = db.get(b"test").unwrap().unwrap();
        assert_eq!(&value[..], b"value", "Data should be preserved after repair");
    }
}
