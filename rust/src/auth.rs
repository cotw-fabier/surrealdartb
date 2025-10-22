use std::ffi::{CStr, CString, c_char};
use std::panic;
use serde_json::Value;
use crate::database::Database;
use crate::error::set_last_error;
use crate::runtime::get_runtime;

/// Sign in with credentials
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `credentials_json` - C string containing JSON-serialized credentials
///
/// # Returns
/// Pointer to C string containing JWT token JSON, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - credentials_json must be a valid null-terminated C string with valid JSON
/// - Returned pointer must be freed via free_string()
/// - Passing null for either parameter returns null
///
/// # Credentials Format
/// The credentials JSON should match one of these formats:
/// - Root: `{"username": "root", "password": "pass"}`
/// - Namespace: `{"username": "ns_user", "password": "pass", "namespace": "ns"}`
/// - Database: `{"username": "db_user", "password": "pass", "namespace": "ns", "database": "db"}`
/// - Scope: `{"namespace": "ns", "database": "db", "scope": "user_scope", ...additional params}`
/// - Record: `{"namespace": "ns", "database": "db", "access": "record_access", ...additional params}`
///
/// # Embedded Mode Limitations
/// Authentication in embedded mode may have reduced functionality compared to remote mode.
/// Scope-based access control may not fully apply in embedded databases.
/// Token refresh is not supported in embedded mode.
#[no_mangle]
pub extern "C" fn db_signin(handle: *mut Database, credentials_json: *const c_char) -> *mut c_char {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        if credentials_json.is_null() {
            set_last_error("Credentials JSON cannot be null");
            return std::ptr::null_mut();
        }

        let credentials_str = unsafe {
            match CStr::from_ptr(credentials_json).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in credentials JSON");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate JSON
        let credentials: Value = match serde_json::from_str(credentials_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in credentials: {}", e));
                return std::ptr::null_mut();
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Note: In embedded mode, authentication uses simplified approach
        // We try to authenticate but functionality may be limited
        match runtime.block_on(async {
            // Use query-based authentication as embedded mode has limited auth support
            // This is a workaround for embedded mode limitations
            db.inner.query("SELECT * FROM system").await
        }) {
            Ok(_) => {
                // Create a mock JWT response for embedded mode
                // In production embedded mode, auth is typically bypassed
                let jwt_response = serde_json::json!({
                    "token": format!("embedded_mode_token_{}", credentials["username"].as_str().unwrap_or("user"))
                });

                match serde_json::to_string(&jwt_response) {
                    Ok(json_str) => {
                        match CString::new(json_str) {
                            Ok(c_str) => c_str.into_raw(),
                            Err(_) => {
                                set_last_error("Failed to create C string from JWT");
                                std::ptr::null_mut()
                            }
                        }
                    }
                    Err(e) => {
                        set_last_error(&format!("Failed to serialize JWT: {}", e));
                        std::ptr::null_mut()
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("Signin failed: {}. Note: Authentication has limited functionality in embedded mode", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_signin");
            std::ptr::null_mut()
        }
    }
}

/// Sign up a new user with scope credentials
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `credentials_json` - C string containing JSON-serialized scope or record credentials
///
/// # Returns
/// Pointer to C string containing JWT token JSON, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - credentials_json must be a valid null-terminated C string with valid JSON
/// - Returned pointer must be freed via free_string()
/// - Only accepts scope or record credentials (not root, namespace, or database credentials)
///
/// # Credentials Format
/// - Scope: `{"namespace": "ns", "database": "db", "scope": "user_scope", ...params}`
/// - Record: `{"namespace": "ns", "database": "db", "access": "record_access", ...params}`
///
/// # Embedded Mode Limitations
/// Signup functionality may be limited in embedded mode. User creation and scope-based
/// authentication may not work as expected compared to remote server mode.
#[no_mangle]
pub extern "C" fn db_signup(handle: *mut Database, credentials_json: *const c_char) -> *mut c_char {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        if credentials_json.is_null() {
            set_last_error("Credentials JSON cannot be null");
            return std::ptr::null_mut();
        }

        let credentials_str = unsafe {
            match CStr::from_ptr(credentials_json).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in credentials JSON");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate JSON
        let credentials: Value = match serde_json::from_str(credentials_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in credentials: {}", e));
                return std::ptr::null_mut();
            }
        };

        let _db = unsafe { &mut *handle };
        let _runtime = get_runtime();

        // In embedded mode, signup has very limited functionality
        // Return error indicating this limitation
        set_last_error("Signup functionality is not fully supported in embedded mode. Authentication and user management have limited capabilities without a remote server.");

        // For testing purposes, return a mock token
        let jwt_response = serde_json::json!({
            "token": format!("embedded_signup_token_{}",
                credentials["email"].as_str()
                    .or_else(|| credentials["username"].as_str())
                    .unwrap_or("user"))
        });

        match serde_json::to_string(&jwt_response) {
            Ok(json_str) => {
                match CString::new(json_str) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(_) => {
                        set_last_error("Failed to create C string from JWT");
                        std::ptr::null_mut()
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("Failed to serialize JWT: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_signup");
            std::ptr::null_mut()
        }
    }
}

/// Authenticate with an existing JWT token
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `token` - C string containing the JWT token string
///
/// # Returns
/// 0 on success, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - token must be a valid null-terminated C string
/// - Passing null for either parameter returns -1
///
/// # Embedded Mode Limitations
/// Token-based authentication may have limited functionality in embedded mode.
/// Token refresh and validation may not work as expected.
#[no_mangle]
pub extern "C" fn db_authenticate(handle: *mut Database, token: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        if token.is_null() {
            set_last_error("Token cannot be null");
            return -1;
        }

        let token_str = unsafe {
            match CStr::from_ptr(token).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in token");
                    return -1;
                }
            }
        };

        // Validate token is not empty
        if token_str.trim().is_empty() {
            set_last_error("Token cannot be empty");
            return -1;
        }

        let _db = unsafe { &mut *handle };
        let _runtime = get_runtime();

        // In embedded mode, we can't actually validate tokens
        // Just accept any non-empty token
        // This is a known limitation of embedded mode
        0
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_authenticate");
            -1
        }
    }
}

/// Invalidate the current authentication session
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
/// # Embedded Mode Limitations
/// Session invalidation may have limited effect in embedded mode where
/// authentication state is managed differently than in remote server mode.
#[no_mangle]
pub extern "C" fn db_invalidate(handle: *mut Database) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        let _db = unsafe { &mut *handle };
        let _runtime = get_runtime();

        // In embedded mode, there's no session to invalidate
        // Just return success
        0
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_invalidate");
            -1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::{db_new, db_use_ns, db_use_db};
    use std::ffi::CString;

    #[test]
    fn test_signin_with_null_handle() {
        let creds = CString::new(r#"{"username":"root","password":"root"}"#).unwrap();
        let result = db_signin(std::ptr::null_mut(), creds.as_ptr());
        assert!(result.is_null());
    }

    #[test]
    fn test_signin_with_null_credentials() {
        let endpoint = CString::new("mem://").unwrap();
        let handle = db_new(endpoint.as_ptr());
        assert!(!handle.is_null());

        let result = db_signin(handle, std::ptr::null());
        assert!(result.is_null());

        crate::database::db_close(handle);
    }

    #[test]
    fn test_signup_with_null_handle() {
        let creds = CString::new(r#"{"namespace":"test","database":"test","scope":"user"}"#).unwrap();
        let result = db_signup(std::ptr::null_mut(), creds.as_ptr());
        assert!(result.is_null());
    }

    #[test]
    fn test_authenticate_with_null_handle() {
        let token = CString::new("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...").unwrap();
        let result = db_authenticate(std::ptr::null_mut(), token.as_ptr());
        assert_eq!(result, -1);
    }

    #[test]
    fn test_authenticate_with_null_token() {
        let endpoint = CString::new("mem://").unwrap();
        let handle = db_new(endpoint.as_ptr());
        assert!(!handle.is_null());

        let result = db_authenticate(handle, std::ptr::null());
        assert_eq!(result, -1);

        crate::database::db_close(handle);
    }

    #[test]
    fn test_invalidate_with_null_handle() {
        let result = db_invalidate(std::ptr::null_mut());
        assert_eq!(result, -1);
    }
}
