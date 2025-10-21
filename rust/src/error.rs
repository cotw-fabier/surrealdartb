use std::cell::RefCell;
use std::ffi::{CString, c_char};

thread_local! {
    /// Thread-local storage for the last error message
    ///
    /// Each thread maintains its own error state to ensure thread safety.
    /// Errors are stored as strings and can be retrieved via get_last_error()
    static LAST_ERROR: RefCell<Option<String>> = const { RefCell::new(None) };
}

/// Store an error message in thread-local storage
///
/// # Arguments
/// * `msg` - The error message to store
///
/// # Thread Safety
/// This function is thread-safe. Each thread maintains its own error state.
pub fn set_last_error(msg: &str) {
    LAST_ERROR.with(|last| {
        *last.borrow_mut() = Some(msg.to_string());
    });
}

/// Retrieve the last error message from thread-local storage
///
/// # Returns
/// A pointer to a C string containing the error message, or null if no error.
/// The caller is responsible for freeing the returned string via free_string().
///
/// # Safety
/// The returned pointer must be freed by calling free_string() to avoid memory leaks.
/// The pointer is valid until free_string() is called or the program terminates.
#[no_mangle]
pub extern "C" fn get_last_error() -> *mut c_char {
    LAST_ERROR.with(|last| {
        match last.borrow_mut().take() {
            Some(err) => {
                match CString::new(err) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(_) => std::ptr::null_mut(),
                }
            }
            None => std::ptr::null_mut(),
        }
    })
}

/// Free a string allocated by native code
///
/// This function should be called to free any strings returned by:
/// - get_last_error()
/// - response_get_results()
/// - Any other FFI function that returns a *mut c_char
///
/// # Arguments
/// * `ptr` - Pointer to the string to free
///
/// # Safety
/// The pointer must have been obtained from a native function that allocates strings.
/// Do not call this function twice on the same pointer.
/// Passing a null pointer is safe and does nothing.
#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

/// Free an error string returned by get_last_error()
///
/// This is an alias for free_string() for backward compatibility.
///
/// # Arguments
/// * `ptr` - Pointer to the error string to free
///
/// # Safety
/// The pointer must have been obtained from get_last_error().
/// Do not call this function twice on the same pointer.
/// Passing a null pointer is safe and does nothing.
#[no_mangle]
pub extern "C" fn free_error_string(ptr: *mut c_char) {
    free_string(ptr);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_storage_and_retrieval() {
        set_last_error("test error");
        let ptr = get_last_error();
        assert!(!ptr.is_null());

        unsafe {
            let c_str = std::ffi::CStr::from_ptr(ptr);
            assert_eq!(c_str.to_str().unwrap(), "test error");
        }

        free_string(ptr);

        // Second retrieval should return null
        let ptr2 = get_last_error();
        assert!(ptr2.is_null());
    }

    #[test]
    fn test_free_null_pointer() {
        // Should not panic
        free_string(std::ptr::null_mut());
        free_error_string(std::ptr::null_mut());
    }

    #[test]
    fn test_free_error_string_alias() {
        set_last_error("test error");
        let ptr = get_last_error();
        assert!(!ptr.is_null());

        // Test that free_error_string works as an alias
        free_error_string(ptr);
    }
}
