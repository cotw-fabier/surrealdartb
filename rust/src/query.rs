use std::ffi::{CStr, CString, c_char};
use std::panic;
use serde_json::Value;
use crate::database::Database;
use crate::error::set_last_error;
use crate::runtime::get_runtime;
use crate::connection_registry::is_handle_valid;

/// Opaque handle for query response
///
/// This type is never constructed in Dart; it only exists as a pointer.
/// Memory management: Created via db_query(), destroyed via response_free()
pub struct Response {
    pub results: Vec<Value>,
    pub errors: Vec<String>,
}

/// Helper function to convert surrealdb::types::Value to serde_json::Value
///
/// **SurrealDB 3.0.0 Changes:**
///
/// In SurrealDB 3.0.0-beta, the Value type has been reorganized into `surrealdb_types`.
/// The type is now a clean enum that can be pattern-matched directly without unsafe transmute.
///
/// **How This Works:**
///
/// 1. Pattern match on Value variants (String, Number, RecordId, Bool, etc.)
/// 2. Extract the actual value from each variant and convert to serde_json::Value
/// 3. Recursively process nested Objects, Arrays, and Sets
///
/// **Examples of Unwrapping:**
///
/// - `Value::String("text")` → `JsonValue::String("text")`
/// - `Value::Number(Number::Int(42))` → `JsonValue::Number(42)`
/// - `Value::RecordId(...)` → `JsonValue::String("table:id")`
/// - `Value::Bool(true)` → `JsonValue::Bool(true)`
/// - `Value::Object(...)` → `JsonValue::Object(...)` with recursively unwrapped values
/// - `Value::Array(...)` → `JsonValue::Array(...)` with recursively unwrapped elements
/// - `Value::Set(...)` → `JsonValue::Array(...)` (sets serialized as arrays)
///
/// This approach produces clean JSON that matches what users expect from a database query,
/// without any internal type system artifacts leaking through to the Dart layer.
pub fn surreal_value_to_json(value: &surrealdb::types::Value) -> Result<Value, String> {
    use surrealdb::types::Value as SurrealValue;
    use surrealdb::types::Number;

    match value {
        // String values - direct conversion
        SurrealValue::String(s) => Ok(Value::String(s.clone())),

        // Numeric values - match on the Number enum variants
        SurrealValue::Number(Number::Int(i)) => {
            Ok(Value::Number((*i).into()))
        },
        SurrealValue::Number(Number::Float(f)) => {
            // Handle Infinity values (new in SurrealDB 3.0)
            if f.is_infinite() {
                if f.is_sign_positive() {
                    Ok(Value::String("Infinity".to_string()))
                } else {
                    Ok(Value::String("-Infinity".to_string()))
                }
            } else if f.is_nan() {
                // NaN maps to null
                Ok(Value::Null)
            } else {
                // Convert float to JSON number
                Ok(serde_json::Number::from_f64(*f)
                    .map(Value::Number)
                    .unwrap_or(Value::Null))
            }
        },
        SurrealValue::Number(Number::Decimal(d)) => {
            // Decimal - convert to string to preserve arbitrary precision
            // JSON numbers have limited precision, so we use string representation
            Ok(Value::String(d.to_string()))
        },

        // Record ID - convert to "table:key" format string
        // This is the standard SurrealDB representation for record IDs
        SurrealValue::RecordId(record_id) => {
            use surrealdb::types::RecordIdKey;
            // Format key based on its type
            let key_str = match &record_id.key {
                RecordIdKey::Number(n) => n.to_string(),
                RecordIdKey::String(s) => s.clone(),
                RecordIdKey::Uuid(u) => u.to_string(),
                RecordIdKey::Array(arr) => {
                    // For arrays, serialize as JSON
                    let vals: Result<Vec<_>, _> = arr.iter()
                        .map(|v| surreal_value_to_json(v))
                        .collect();
                    serde_json::to_string(&vals?).unwrap_or_default()
                },
                RecordIdKey::Object(obj) => {
                    // For objects, serialize as JSON
                    let mut map = serde_json::Map::new();
                    for (k, v) in obj.iter() {
                        map.insert(k.clone(), surreal_value_to_json(v)?);
                    }
                    serde_json::to_string(&map).unwrap_or_default()
                },
                RecordIdKey::Range(_) => "<range>".to_string(),
            };
            Ok(Value::String(format!("{}:{}", record_id.table.as_str(), key_str)))
        },

        // Object - recursively unwrap all field values
        SurrealValue::Object(obj) => {
            let mut map = serde_json::Map::new();
            for (k, v) in obj.iter() {
                map.insert(k.clone(), surreal_value_to_json(v)?);
            }
            Ok(Value::Object(map))
        },

        // Array - recursively unwrap all element values
        SurrealValue::Array(arr) => {
            let values: Result<Vec<_>, _> = arr.iter()
                .map(|v| surreal_value_to_json(v))
                .collect();
            Ok(Value::Array(values?))
        },

        // Set - convert to JSON array (new in SurrealDB 3.0)
        SurrealValue::Set(set) => {
            let values: Result<Vec<_>, _> = set.iter()
                .map(|v| surreal_value_to_json(v))
                .collect();
            Ok(Value::Array(values?))
        },

        // Boolean values - direct conversion
        SurrealValue::Bool(b) => Ok(Value::Bool(*b)),

        // Null and None - both map to JSON null
        SurrealValue::None | SurrealValue::Null => Ok(Value::Null),

        // DateTime - convert to ISO 8601 string representation
        SurrealValue::Datetime(dt) => Ok(Value::String(dt.to_string())),

        // UUID - convert to standard UUID string format
        SurrealValue::Uuid(uuid) => Ok(Value::String(uuid.to_string())),

        // Duration - convert to string representation
        SurrealValue::Duration(d) => Ok(Value::String(d.to_string())),

        // Geometry types - convert to string representation
        SurrealValue::Geometry(geo) => {
            Ok(Value::String(geo.to_string()))
        },

        // Bytes - convert to base64 string for safe JSON transport
        SurrealValue::Bytes(bytes) => {
            use base64::{Engine as _, engine::general_purpose};
            let encoded = general_purpose::STANDARD.encode(bytes.as_ref());
            Ok(Value::String(encoded))
        },

        // Table - convert to string representation
        SurrealValue::Table(table) => {
            Ok(Value::String(table.to_string()))
        },

        // File - convert to "bucket:key" format (new in SurrealDB 3.0)
        SurrealValue::File(file) => {
            Ok(Value::String(format!("{}:{}", file.bucket(), file.key())))
        },

        // Range - convert to JSON object with start/end bounds
        SurrealValue::Range(range) => {
            use std::ops::Bound;
            let start = match range.start() {
                Bound::Included(v) => surreal_value_to_json(v)?,
                Bound::Excluded(v) => surreal_value_to_json(v)?,
                Bound::Unbounded => Value::Null,
            };
            let end = match range.end() {
                Bound::Included(v) => surreal_value_to_json(v)?,
                Bound::Excluded(v) => surreal_value_to_json(v)?,
                Bound::Unbounded => Value::Null,
            };
            let mut map = serde_json::Map::new();
            map.insert("start".to_string(), start);
            map.insert("end".to_string(), end);
            Ok(Value::Object(map))
        },

        // Regex - convert to string representation
        SurrealValue::Regex(regex) => {
            Ok(Value::String(regex.to_string()))
        },
    }
}

/// Execute a SurrealQL query
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `sql` - C string containing the SurrealQL query
///
/// # Returns
/// Pointer to Response handle, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - sql must be a valid null-terminated C string
/// - Returned pointer must be freed via response_free()
/// - Passing null for either parameter returns null
///
/// # Errors
/// Returns null and sets last error if:
/// - handle or sql is null
/// - sql is not valid UTF-8
/// - Query execution fails
#[no_mangle]
pub extern "C" fn db_query(handle: *mut Database, sql: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if sql.is_null() {
            set_last_error("SQL query cannot be null");
            return std::ptr::null_mut();
        }

        let sql_str = unsafe {
            match CStr::from_ptr(sql).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in SQL query");
                    return std::ptr::null_mut();
                }
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        match runtime.block_on(async {
            db.inner.query(sql_str).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                // Get the number of statements to know how many results to extract
                let num_statements = response.num_statements();

                // Extract errors first using take_errors()
                // This removes errors from the response and returns them as a map
                let error_map = response.take_errors();

                // Convert error map to a vector of error messages
                // The error map has statement index as key and error as value
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract all results from the response
                // Use surrealdb::Value type and convert to serde_json::Value
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            // Convert surrealdb::Value to serde_json::Value using manual unwrapper
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    // If we can't serialize the value, push an error
                                    errors.push(format!("Statement {}: Failed to serialize result: {}", idx, e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            // If take fails for a statement that had an error, it's already captured
                            // in the errors vector from take_errors() above
                            // Push null as a placeholder for this result
                            results.push(Value::Null);

                            // Only add additional error if it wasn't already captured
                            if !errors.iter().any(|err_msg| err_msg.starts_with(&format!("Statement {}:", idx))) {
                                errors.push(format!("Statement {}: {}", idx, e));
                            }
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Query execution failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_query");
            std::ptr::null_mut()
        }
    }
}

/// Get query results as JSON string
///
/// # Arguments
/// * `handle` - Pointer to Response instance
///
/// # Returns
/// Pointer to C string containing JSON array of results, or null on failure
/// The caller is responsible for freeing the returned string via free_error_string()
///
/// # Safety
/// - handle must be a valid pointer obtained from db_query()
/// - Returned pointer must be freed to avoid memory leaks
/// - Passing null returns null
#[no_mangle]
pub extern "C" fn response_get_results(handle: *mut Response) -> *mut c_char {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Response handle cannot be null");
            return std::ptr::null_mut();
        }

        let response = unsafe { &*handle };

        match serde_json::to_string(&response.results) {
            Ok(json) => {
                match CString::new(json) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(_) => {
                        set_last_error("Failed to create C string from JSON");
                        std::ptr::null_mut()
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("Failed to serialize results: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in response_get_results");
            std::ptr::null_mut()
        }
    }
}

/// Check if the response contains errors
///
/// # Arguments
/// * `handle` - Pointer to Response instance
///
/// # Returns
/// 1 if errors exist, 0 if no errors, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_query()
/// - Passing null returns -1
#[no_mangle]
pub extern "C" fn response_has_errors(handle: *mut Response) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Response handle cannot be null");
            return -1;
        }

        let response = unsafe { &*handle };
        if response.errors.is_empty() {
            0
        } else {
            1
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in response_has_errors");
            -1
        }
    }
}

/// Get query errors as JSON string
///
/// # Arguments
/// * `handle` - Pointer to Response instance
///
/// # Returns
/// Pointer to C string containing JSON array of error messages, or null on failure
/// The caller is responsible for freeing the returned string via free_error_string()
///
/// # Safety
/// - handle must be a valid pointer obtained from db_query()
/// - Returned pointer must be freed to avoid memory leaks
/// - Passing null returns null
#[no_mangle]
pub extern "C" fn response_get_errors(handle: *mut Response) -> *mut c_char {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Response handle cannot be null");
            return std::ptr::null_mut();
        }

        let response = unsafe { &*handle };

        match serde_json::to_string(&response.errors) {
            Ok(json) => {
                match CString::new(json) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(_) => {
                        set_last_error("Failed to create C string from JSON");
                        std::ptr::null_mut()
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("Failed to serialize errors: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in response_get_errors");
            std::ptr::null_mut()
        }
    }
}

/// Free a response handle
///
/// # Arguments
/// * `handle` - Pointer to Response instance
///
/// # Safety
/// - handle should be a valid pointer obtained from db_query()
/// - After calling this function, the handle is invalid and must not be used
/// - Passing null is safe and does nothing
/// - Do not call this function twice on the same pointer
#[no_mangle]
pub extern "C" fn response_free(handle: *mut Response) {
    let _ = panic::catch_unwind(|| {
        if !handle.is_null() {
            unsafe {
                let _ = Box::from_raw(handle);
            }
        }
    });
}

/// Select all records from a table
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `table` - C string specifying the table name
///
/// # Returns
/// Pointer to Response handle, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - table must be a valid null-terminated C string
/// - Returned pointer must be freed via response_free()
#[no_mangle]
pub extern "C" fn db_select(handle: *mut Database, table: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if table.is_null() {
            set_last_error("Table name cannot be null");
            return std::ptr::null_mut();
        }

        let table_str = unsafe {
            match CStr::from_ptr(table).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in table name");
                    return std::ptr::null_mut();
                }
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() instead of select() to get consistent Value types
        let query_sql = format!("SELECT * FROM {}", table_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                // Get the number of statements (should be 1 for SELECT)
                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Select failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_select");
            std::ptr::null_mut()
        }
    }
}

/// Get a specific record by resource identifier
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `resource` - C string specifying the resource (table:id)
///
/// # Returns
/// Pointer to Response handle containing the record (or null if not found), or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - resource must be a valid null-terminated C string
/// - Returned pointer must be freed via response_free()
///
/// # Note
/// Unlike other operations, this returns null in the results array if the record doesn't exist,
/// rather than throwing an error. The caller should check if the first result is null.
#[no_mangle]
pub extern "C" fn db_get(handle: *mut Database, resource: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if resource.is_null() {
            set_last_error("Resource cannot be null");
            return std::ptr::null_mut();
        }

        let resource_str = unsafe {
            match CStr::from_ptr(resource).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in resource");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate resource is not empty
        if resource_str.trim().is_empty() {
            set_last_error("Resource cannot be empty");
            return std::ptr::null_mut();
        }

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() with SELECT for consistent Value handling
        let query_sql = format!("SELECT * FROM {}", resource_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Get failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_get");
            std::ptr::null_mut()
        }
    }
}

/// Create a new record in a table
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `table` - C string specifying the table name
/// * `data` - C string containing JSON data for the new record
///
/// # Returns
/// Pointer to Response handle containing the created record, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - table and data must be valid null-terminated C strings
/// - data must be valid JSON
/// - Returned pointer must be freed via response_free()
#[no_mangle]
pub extern "C" fn db_create(handle: *mut Database, table: *const c_char, data: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if table.is_null() {
            set_last_error("Table name cannot be null");
            return std::ptr::null_mut();
        }

        if data.is_null() {
            set_last_error("Data cannot be null");
            return std::ptr::null_mut();
        }

        let table_str = unsafe {
            match CStr::from_ptr(table).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in table name");
                    return std::ptr::null_mut();
                }
            }
        };

        let data_str = unsafe {
            match CStr::from_ptr(data).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in data");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate JSON
        let _: Value = match serde_json::from_str(data_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in data: {}", e));
                return std::ptr::null_mut();
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() with CREATE statement for consistent Value handling
        let query_sql = format!("CREATE {} CONTENT {}", table_str, data_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Create failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_create");
            std::ptr::null_mut()
        }
    }
}

/// Update a record
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `resource` - C string specifying the resource (table:id)
/// * `data` - C string containing JSON data for the update
///
/// # Returns
/// Pointer to Response handle containing the updated record, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - resource and data must be valid null-terminated C strings
/// - data must be valid JSON
/// - Returned pointer must be freed via response_free()
#[no_mangle]
pub extern "C" fn db_update(handle: *mut Database, resource: *const c_char, data: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if resource.is_null() {
            set_last_error("Resource cannot be null");
            return std::ptr::null_mut();
        }

        if data.is_null() {
            set_last_error("Data cannot be null");
            return std::ptr::null_mut();
        }

        let resource_str = unsafe {
            match CStr::from_ptr(resource).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in resource");
                    return std::ptr::null_mut();
                }
            }
        };

        let data_str = unsafe {
            match CStr::from_ptr(data).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in data");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate JSON
        let _: Value = match serde_json::from_str(data_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in data: {}", e));
                return std::ptr::null_mut();
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() with UPDATE statement for consistent Value handling
        let query_sql = format!("UPDATE {} CONTENT {}", resource_str, data_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Update failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_update");
            std::ptr::null_mut()
        }
    }
}

/// Delete a record
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `resource` - C string specifying the resource (table:id or table)
///
/// # Returns
/// Pointer to Response handle, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - resource must be a valid null-terminated C string
/// - Returned pointer must be freed via response_free()
#[no_mangle]
pub extern "C" fn db_delete(handle: *mut Database, resource: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if resource.is_null() {
            set_last_error("Resource cannot be null");
            return std::ptr::null_mut();
        }

        let resource_str = unsafe {
            match CStr::from_ptr(resource).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in resource");
                    return std::ptr::null_mut();
                }
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() with DELETE statement for consistent Value handling
        let query_sql = format!("DELETE {}", resource_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Delete failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_delete");
            std::ptr::null_mut()
        }
    }
}

/// Upsert a record with CONTENT (full replacement)
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `resource` - C string specifying the resource (must be table:id, not just table)
/// * `data` - C string containing JSON data for the record
///
/// # Returns
/// Pointer to Response handle containing the upserted record, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - resource and data must be valid null-terminated C strings
/// - resource must be in table:id format, not just table name
/// - data must be valid JSON
/// - Returned pointer must be freed via response_free()
#[no_mangle]
pub extern "C" fn db_upsert_content(handle: *mut Database, resource: *const c_char, data: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if resource.is_null() {
            set_last_error("Resource cannot be null");
            return std::ptr::null_mut();
        }

        if data.is_null() {
            set_last_error("Data cannot be null");
            return std::ptr::null_mut();
        }

        let resource_str = unsafe {
            match CStr::from_ptr(resource).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in resource");
                    return std::ptr::null_mut();
                }
            }
        };

        let data_str = unsafe {
            match CStr::from_ptr(data).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in data");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate that resource contains a colon (table:id format)
        if !resource_str.contains(':') {
            set_last_error("Upsert requires a specific record ID (table:id format), not just a table name");
            return std::ptr::null_mut();
        }

        // Validate JSON
        let _: Value = match serde_json::from_str(data_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in data: {}", e));
                return std::ptr::null_mut();
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() with UPSERT ... CONTENT statement
        let query_sql = format!("UPSERT {} CONTENT {}", resource_str, data_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Upsert content failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_upsert_content");
            std::ptr::null_mut()
        }
    }
}

/// Upsert a record with MERGE (field merging)
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `resource` - C string specifying the resource (must be table:id, not just table)
/// * `data` - C string containing JSON data with fields to merge
///
/// # Returns
/// Pointer to Response handle containing the upserted record, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - resource and data must be valid null-terminated C strings
/// - resource must be in table:id format, not just table name
/// - data must be valid JSON
/// - Returned pointer must be freed via response_free()
#[no_mangle]
pub extern "C" fn db_upsert_merge(handle: *mut Database, resource: *const c_char, data: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if resource.is_null() {
            set_last_error("Resource cannot be null");
            return std::ptr::null_mut();
        }

        if data.is_null() {
            set_last_error("Data cannot be null");
            return std::ptr::null_mut();
        }

        let resource_str = unsafe {
            match CStr::from_ptr(resource).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in resource");
                    return std::ptr::null_mut();
                }
            }
        };

        let data_str = unsafe {
            match CStr::from_ptr(data).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in data");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate that resource contains a colon (table:id format)
        if !resource_str.contains(':') {
            set_last_error("Upsert requires a specific record ID (table:id format), not just a table name");
            return std::ptr::null_mut();
        }

        // Validate JSON
        let _: Value = match serde_json::from_str(data_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in data: {}", e));
                return std::ptr::null_mut();
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() with UPSERT ... MERGE statement
        let query_sql = format!("UPSERT {} MERGE {}", resource_str, data_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Upsert merge failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_upsert_merge");
            std::ptr::null_mut()
        }
    }
}

/// Upsert a record with PATCH (JSON patch operations)
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `resource` - C string specifying the resource (must be table:id, not just table)
/// * `patches` - C string containing JSON array of patch operations (RFC 6902 format)
///
/// # Returns
/// Pointer to Response handle containing the upserted record, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - resource and patches must be valid null-terminated C strings
/// - resource must be in table:id format, not just table name
/// - patches must be valid JSON array with patch operations
/// - Returned pointer must be freed via response_free()
///
/// # Patch Format
/// patches should be a JSON array of patch operations, each with:
/// - "op": "add" | "remove" | "replace" | "change"
/// - "path": JSON Pointer path (e.g., "/field")
/// - "value": value for add/replace/change operations (omit for remove)
///
/// Example: [{"op":"add","path":"/email","value":"user@example.com"},{"op":"remove","path":"/temp"}]
#[no_mangle]
pub extern "C" fn db_upsert_patch(handle: *mut Database, resource: *const c_char, patches: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if resource.is_null() {
            set_last_error("Resource cannot be null");
            return std::ptr::null_mut();
        }

        if patches.is_null() {
            set_last_error("Patches cannot be null");
            return std::ptr::null_mut();
        }

        let resource_str = unsafe {
            match CStr::from_ptr(resource).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in resource");
                    return std::ptr::null_mut();
                }
            }
        };

        let patches_str = unsafe {
            match CStr::from_ptr(patches).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in patches");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate that resource contains a colon (table:id format)
        if !resource_str.contains(':') {
            set_last_error("Upsert requires a specific record ID (table:id format), not just a table name");
            return std::ptr::null_mut();
        }

        // Validate JSON array
        let patches_array: Vec<Value> = match serde_json::from_str(patches_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in patches: {}", e));
                return std::ptr::null_mut();
            }
        };

        // Validate that patches is non-empty
        if patches_array.is_empty() {
            set_last_error("Patches array cannot be empty");
            return std::ptr::null_mut();
        }

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() with UPSERT ... PATCH statement
        let query_sql = format!("UPSERT {} PATCH {}", resource_str, patches_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Upsert patch failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_upsert_patch");
            std::ptr::null_mut()
        }
    }
}

/// Insert a record with content
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `resource` - C string specifying the resource (table or table:id)
/// * `data` - C string containing JSON data for the new record
///
/// # Returns
/// Pointer to Response handle containing the inserted record, or null on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - resource and data must be valid null-terminated C strings
/// - data must be valid JSON
/// - Returned pointer must be freed via response_free()
///
/// # Implementation Decision: Method Variants Approach
///
/// This function uses the method variants approach (insertContent/insertRelation)
/// instead of a builder pattern. After analyzing the existing FFI infrastructure,
/// the builder pattern would require:
/// - Stateful builder class managing FFI handles across method calls
/// - Complex state cleanup logic and error handling
/// - Additional FFI functions for builder lifecycle management
///
/// The method variants approach is simpler, more maintainable, and aligns with
/// the existing codebase patterns (create, update, delete, select all use direct calls).
/// This decision is documented here and in the Dart wrapper implementation.
#[no_mangle]
pub extern "C" fn db_insert(handle: *mut Database, resource: *const c_char, data: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if resource.is_null() {
            set_last_error("Resource cannot be null");
            return std::ptr::null_mut();
        }

        if data.is_null() {
            set_last_error("Data cannot be null");
            return std::ptr::null_mut();
        }

        let resource_str = unsafe {
            match CStr::from_ptr(resource).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in resource");
                    return std::ptr::null_mut();
                }
            }
        };

        let data_str = unsafe {
            match CStr::from_ptr(data).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in data");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate JSON
        let _: Value = match serde_json::from_str(data_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in data: {}", e));
                return std::ptr::null_mut();
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Use query() with INSERT statement for consistent Value handling
        let query_sql = format!("INSERT INTO {} {}", resource_str, data_str);

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Insert failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_insert");
            std::ptr::null_mut()
        }
    }
}

/// Export database to a file
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `path` - C string specifying the file path for export
///
/// # Returns
/// 0 on success, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - path must be a valid null-terminated C string
/// - Caller must have write permissions to the file path
///
/// # Implementation Note
/// This is a basic implementation that exports the entire database.
/// Advanced configuration options (table selection, format options,
/// ML model handling) are deferred to a future iteration.
///
/// # Errors
/// Returns -1 and sets last error if:
/// - handle or path is null
/// - path is not valid UTF-8
/// - File I/O fails (permissions, disk space, etc.)
/// - Export operation fails
#[no_mangle]
pub extern "C" fn db_export(handle: *mut Database, path: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return -1;
        }

        if path.is_null() {
            set_last_error("File path cannot be null");
            return -1;
        }

        let path_str = unsafe {
            match CStr::from_ptr(path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in file path");
                    return -1;
                }
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Export the database to file
        match runtime.block_on(async {
            db.inner.export(path_str).await
        }) {
            Ok(_) => 0,
            Err(e) => {
                set_last_error(&format!("Export failed: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_export");
            -1
        }
    }
}

/// Import database from a file
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `path` - C string specifying the file path for import
///
/// # Returns
/// 0 on success, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - path must be a valid null-terminated C string
/// - File must exist and be readable
/// - File must contain valid SurrealQL statements
///
/// # Implementation Note
/// This is a basic implementation that imports the entire file.
/// Advanced configuration options are deferred to a future iteration.
///
/// # Errors
/// Returns -1 and sets last error if:
/// - handle or path is null
/// - path is not valid UTF-8
/// - File doesn't exist or isn't readable
/// - File contains invalid SurrealQL
/// - Import operation fails
#[no_mangle]
pub extern "C" fn db_import(handle: *mut Database, path: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return -1;
        }

        if path.is_null() {
            set_last_error("File path cannot be null");
            return -1;
        }

        let path_str = unsafe {
            match CStr::from_ptr(path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in file path");
                    return -1;
                }
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Import the database from file
        match runtime.block_on(async {
            db.inner.import(path_str).await
        }) {
            Ok(_) => 0,
            Err(e) => {
                set_last_error(&format!("Import failed: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_import");
            -1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::database::{db_new, db_use_ns, db_use_db, db_connect};

    #[test]
    fn test_query_execution() {
        let endpoint = std::ffi::CString::new("mem://").unwrap();
        let handle = db_new(endpoint.as_ptr());
        assert!(!handle.is_null());

        assert_eq!(db_connect(handle), 0);

        let ns = std::ffi::CString::new("test").unwrap();
        db_use_ns(handle, ns.as_ptr());

        let db = std::ffi::CString::new("test").unwrap();
        db_use_db(handle, db.as_ptr());

        let sql = std::ffi::CString::new("SELECT * FROM person").unwrap();
        let response = db_query(handle, sql.as_ptr());

        // Query should succeed even if table is empty
        assert!(!response.is_null());

        response_free(response);
        crate::database::db_close(handle);
    }

    #[test]
    fn test_response_free_null() {
        // Should not panic
        response_free(std::ptr::null_mut());
    }

    #[test]
    fn test_create_deserialization() {
        unsafe {
            // Setup
            let endpoint = CString::new("mem://").unwrap();
            let handle = db_new(endpoint.as_ptr());
            assert!(!handle.is_null(), "Failed to create database");

            assert_eq!(db_connect(handle), 0, "Failed to connect");

            let ns = CString::new("test").unwrap();
            db_use_ns(handle, ns.as_ptr());

            let db = CString::new("test").unwrap();
            db_use_db(handle, db.as_ptr());

            // Create record
            let table = CString::new("person").unwrap();
            let data = CString::new(r#"{"name":"Alice","age":30,"email":"alice@test.com","active":true,"tags":["developer","tester"],"metadata":{"created":"2025-10-21","department":"Engineering"}}"#).unwrap();

            let response = db_create(handle, table.as_ptr(), data.as_ptr());
            assert!(!response.is_null(), "CREATE failed");

            // Verify no errors
            assert_eq!(response_has_errors(response), 0, "CREATE returned errors");

            // Get results
            let results_ptr = response_get_results(response);
            assert!(!results_ptr.is_null(), "Failed to get results");

            let results_json = CStr::from_ptr(results_ptr).to_str().unwrap();
            println!("CREATE results: {}", results_json);

            // Verify no type wrappers
            assert!(!results_json.contains("\"Strand\""), "Found Strand wrapper");
            assert!(!results_json.contains("\"Number\""), "Found Number wrapper");
            assert!(!results_json.contains("\"Bool\""), "Found Bool wrapper");
            assert!(!results_json.contains("\"Thing\""), "Found Thing wrapper (should be string)");

            // Parse and validate
            let results: serde_json::Value = serde_json::from_str(results_json).unwrap();
            let results_array = results.as_array().unwrap();
            assert_eq!(results_array.len(), 1);

            let record = &results_array[0];
            let record_array = record.as_array().unwrap();
            let person = &record_array[0];

            // Verify field values
            assert_eq!(person["name"].as_str(), Some("Alice"));
            assert_eq!(person["age"].as_i64(), Some(30));
            assert_eq!(person["email"].as_str(), Some("alice@test.com"));
            assert_eq!(person["active"].as_bool(), Some(true));

            // Verify ID format
            let id = person["id"].as_str().unwrap();
            assert!(id.starts_with("person:"));
            assert!(!id.contains("Thing"));

            println!("✓ Deserialization test PASSED!");
            println!("  - No type wrappers found");
            println!("  - Field values correct");
            println!("  - Thing ID formatted as: {}", id);

            // Cleanup
            crate::error::free_error_string(results_ptr);
            response_free(response);
            crate::database::db_close(handle);
        }
    }
}

/// Set a parameter for the database connection
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `name` - C string specifying the parameter name
/// * `value` - C string containing JSON value for the parameter
///
/// # Returns
/// 0 on success, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - name and value must be valid null-terminated C strings
/// - value must be valid JSON
/// - Parameters persist per connection and can be used in queries with $name syntax
///
/// # Errors
/// Returns -1 and sets last error if:
/// - handle, name, or value is null
/// - name or value is not valid UTF-8
/// - value is not valid JSON
/// - Parameter set operation fails
#[no_mangle]
pub extern "C" fn db_set(handle: *mut Database, name: *const c_char, value: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return -1;
        }

        if name.is_null() {
            set_last_error("Parameter name cannot be null");
            return -1;
        }

        if value.is_null() {
            set_last_error("Parameter value cannot be null");
            return -1;
        }

        let name_str = unsafe {
            match CStr::from_ptr(name).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in parameter name");
                    return -1;
                }
            }
        };

        let value_str = unsafe {
            match CStr::from_ptr(value).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in parameter value");
                    return -1;
                }
            }
        };

        // Validate name is not empty
        if name_str.trim().is_empty() {
            set_last_error("Parameter name cannot be empty");
            return -1;
        }

        // Parse and validate JSON value
        let json_value: Value = match serde_json::from_str(value_str) {
            Ok(v) => v,
            Err(e) => {
                set_last_error(&format!("Invalid JSON in parameter value: {}", e));
                return -1;
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        match runtime.block_on(async {
            db.inner.set(name_str, json_value).await
        }) {
            Ok(_) => 0,
            Err(e) => {
                set_last_error(&format!("Failed to set parameter: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_set");
            -1
        }
    }
}

/// Unset a parameter from the database connection
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `name` - C string specifying the parameter name to remove
///
/// # Returns
/// 0 on success, -1 on failure
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - name must be a valid null-terminated C string
/// - No error is returned if the parameter doesn't exist
///
/// # Errors
/// Returns -1 and sets last error if:
/// - handle or name is null
/// - name is not valid UTF-8
/// - Unset operation fails
#[no_mangle]
pub extern "C" fn db_unset(handle: *mut Database, name: *const c_char) -> i32 {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return -1;
        }

        if name.is_null() {
            set_last_error("Parameter name cannot be null");
            return -1;
        }

        let name_str = unsafe {
            match CStr::from_ptr(name).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in parameter name");
                    return -1;
                }
            }
        };

        // Validate name is not empty
        if name_str.trim().is_empty() {
            set_last_error("Parameter name cannot be empty");
            return -1;
        }

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        match runtime.block_on(async {
            db.inner.unset(name_str).await
        }) {
            Ok(_) => 0,
            Err(e) => {
                set_last_error(&format!("Failed to unset parameter: {}", e));
                -1
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_unset");
            -1
        }
    }
}

/// Execute a SurrealQL function
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `function` - C string specifying the function name (e.g., "rand::float", "fn::my_function")
/// * `args` - C string containing JSON array of arguments, or null/empty for no arguments
///
/// # Returns
/// Pointer to Response handle containing the function result, or null on failure
///
/// # Safety
/// - handle and function must be valid pointers
/// - function must be a valid null-terminated C string
/// - args must be null or a valid null-terminated C string containing a JSON array
/// - Returned pointer must be freed via response_free()
///
/// # Errors
/// Returns null and sets last error if:
/// - handle or function is null
/// - function or args is not valid UTF-8
/// - args is not a valid JSON array
/// - Function execution fails
///
/// # Examples
/// ```
/// // Execute function with no arguments
/// db_run(handle, "rand::float", null)
///
/// // Execute function with arguments
/// db_run(handle, "string::uppercase", "[\"hello\"]")
/// ```
#[no_mangle]
pub extern "C" fn db_run(handle: *mut Database, function: *const c_char, args: *const c_char) -> *mut Response {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        if function.is_null() {
            set_last_error("Function name cannot be null");
            return std::ptr::null_mut();
        }

        let function_str = unsafe {
            match CStr::from_ptr(function).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("Invalid UTF-8 in function name");
                    return std::ptr::null_mut();
                }
            }
        };

        // Validate function name is not empty
        if function_str.trim().is_empty() {
            set_last_error("Function name cannot be empty");
            return std::ptr::null_mut();
        }

        // Parse args if provided
        let args_vec: Vec<Value> = if args.is_null() {
            Vec::new()
        } else {
            let args_str = unsafe {
                match CStr::from_ptr(args).to_str() {
                    Ok(s) => s,
                    Err(_) => {
                        set_last_error("Invalid UTF-8 in arguments");
                        return std::ptr::null_mut();
                    }
                }
            };

            // Skip parsing if empty string
            if args_str.trim().is_empty() {
                Vec::new()
            } else {
                match serde_json::from_str::<Vec<Value>>(args_str) {
                    Ok(v) => v,
                    Err(e) => {
                        set_last_error(&format!("Invalid JSON array in arguments: {}", e));
                        return std::ptr::null_mut();
                    }
                }
            }
        };

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Build query string with RETURN statement
        // RETURN executes the function and returns its result
        let query_sql = if args_vec.is_empty() {
            format!("RETURN {}()", function_str)
        } else {
            // Serialize args back to JSON for embedding in query
            let args_json = match serde_json::to_string(&args_vec) {
                Ok(json) => json,
                Err(e) => {
                    set_last_error(&format!("Failed to serialize arguments: {}", e));
                    return std::ptr::null_mut();
                }
            };
            // Remove the array brackets and use the args directly
            let args_str = &args_json[1..args_json.len()-1];
            format!("RETURN {}({})", function_str, args_str)
        };

        match runtime.block_on(async {
            db.inner.query(&query_sql).await
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results and unwrap using manual unwrapper
                for idx in 0..num_statements {
                    match response.take::<surrealdb::types::Value>(idx) {
                        Ok(value) => {
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => results.push(json_value),
                                Err(e) => {
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                let response_obj = Box::new(Response { results, errors });
                Box::into_raw(response_obj)
            }
            Err(e) => {
                set_last_error(&format!("Function execution failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_run");
            std::ptr::null_mut()
        }
    }
}

/// Get the database version
///
/// # Arguments
/// * `handle` - Pointer to Database instance
///
/// # Returns
/// Pointer to C string containing the version (e.g., "1.5.0"), or null on failure
/// The caller is responsible for freeing the returned string via free_string()
///
/// # Safety
/// - handle must be a valid pointer obtained from db_new()
/// - Returned pointer must be freed to avoid memory leaks
/// - Passing null returns null
///
/// # Errors
/// Returns null and sets last error if:
/// - handle is null
/// - Version query fails
#[no_mangle]
pub extern "C" fn db_version(handle: *mut Database) -> *mut c_char {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        // Validate handle is still registered (prevents use-after-free)
        if !is_handle_valid(handle) {
            set_last_error("Database handle is no longer valid (connection was closed)");
            return std::ptr::null_mut();
        }

        let db = unsafe { &mut *handle };
        let runtime = get_runtime();

        // Execute version query
        match runtime.block_on(async {
            db.inner.version().await
        }) {
            Ok(version) => {
                // Convert version string to CString
                match CString::new(version.to_string()) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(_) => {
                        set_last_error("Failed to create C string from version");
                        std::ptr::null_mut()
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("Failed to get version: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic occurred in db_version");
            std::ptr::null_mut()
        }
    }
}
