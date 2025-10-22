use std::ffi::{CStr, CString, c_char};
use std::panic;
use serde_json::Value;
use crate::database::Database;
use crate::error::set_last_error;
use crate::runtime::get_runtime;

/// Opaque handle for query response
///
/// This type is never constructed in Dart; it only exists as a pointer.
/// Memory management: Created via db_query(), destroyed via response_free()
pub struct Response {
    pub results: Vec<Value>,
    pub errors: Vec<String>,
}

/// Helper function to convert surrealdb::Value to serde_json::Value
///
/// **Why Manual Unwrapping is Necessary:**
///
/// SurrealDB's Value type is an enum with variants like Strand, Number, Thing, Object, Array, etc.
/// Using serde_json::to_value() or to_string() preserves these enum tags in the serialized output:
/// - Example: `{"Strand": "Alice"}` instead of `"Alice"`
/// - Example: `{"Number": {"Int": 30}}` instead of `30`
///
/// This creates "type wrapper pollution" in the JSON returned to Dart, making all field values
/// appear as complex nested objects instead of simple values. This manual unwrapper solves this
/// by pattern matching on each variant and extracting the actual inner value.
///
/// **How This Works:**
///
/// 1. surrealdb::Value is a transparent wrapper: `pub struct Value(pub(crate) CoreValue)`
/// 2. We use unsafe transmute to access the inner CoreValue enum
/// 3. Pattern match on CoreValue variants (Strand, Number, Thing, Bool, etc.)
/// 4. Extract the actual value from each variant and convert to serde_json::Value
/// 5. Recursively process nested Objects and Arrays
///
/// **Safety:**
///
/// The transmute operations are safe because:
/// - surrealdb::Value has `#[repr(transparent)]` attribute
/// - Memory layout is identical to the wrapped CoreValue
/// - We only borrow through references, never move or mutate
/// - The transmute just changes the type's compile-time view, not runtime representation
///
/// **Examples of Unwrapping:**
///
/// - `CoreValue::Strand("text")` → `JsonValue::String("text")`
/// - `CoreValue::Number(Int(42))` → `JsonValue::Number(42)`
/// - `CoreValue::Thing{tb:"person",id:"123"}` → `JsonValue::String("person:123")`
/// - `CoreValue::Bool(true)` → `JsonValue::Bool(true)`
/// - `CoreValue::Object(...)` → `JsonValue::Object(...)` with recursively unwrapped values
/// - `CoreValue::Array(...)` → `JsonValue::Array(...)` with recursively unwrapped elements
/// - `CoreValue::Decimal(d)` → `JsonValue::String(d.to_string())` (preserves precision)
///
/// This approach produces clean JSON that matches what users expect from a database query,
/// without any internal type system artifacts leaking through to the Dart layer.
fn surreal_value_to_json(value: &surrealdb::Value) -> Result<Value, String> {
    use surrealdb_core::sql::Value as CoreValue;
    use surrealdb_core::sql::Number;

    // Access the inner CoreValue through the transparent wrapper
    // surrealdb::Value is defined as: pub struct Value(pub(crate) CoreValue)
    // We match on the reference to avoid cloning
    let core_value: &CoreValue = unsafe {
        // SAFETY: Value is a transparent wrapper around CoreValue with #[repr(transparent)]
        // This transmute is safe because the memory layout is identical - we're just changing
        // the compile-time type view. We only borrow, never move or mutate.
        std::mem::transmute(value)
    };

    match core_value {
        // String values - unwrap the Strand variant
        CoreValue::Strand(s) => Ok(Value::String(s.0.clone())),

        // Numeric values - match on the Number enum variants
        CoreValue::Number(Number::Int(i)) => {
            Ok(Value::Number((*i).into()))
        },
        CoreValue::Number(Number::Float(f)) => {
            // Convert float to JSON number, falling back to null if NaN/Inf
            Ok(serde_json::Number::from_f64(*f)
                .map(Value::Number)
                .unwrap_or(Value::Null))
        },
        CoreValue::Number(Number::Decimal(d)) => {
            // Decimal - convert to string to preserve arbitrary precision
            // JSON numbers have limited precision, so we use string representation
            Ok(Value::String(d.to_string()))
        },

        // Record ID (Thing) - convert to "table:id" format string
        // This is the standard SurrealDB representation for record IDs
        CoreValue::Thing(thing) => {
            Ok(Value::String(format!("{}:{}", thing.tb, thing.id)))
        },

        // Object - recursively unwrap all field values
        CoreValue::Object(obj) => {
            let mut map = serde_json::Map::new();
            for (k, v) in obj.0.iter() {
                // Need to wrap CoreValue back to Value for recursion
                let wrapped_v = unsafe {
                    // SAFETY: Same transparent wrapper logic - just changing type view
                    std::mem::transmute::<&CoreValue, &surrealdb::Value>(v)
                };
                map.insert(k.clone(), surreal_value_to_json(wrapped_v)?);
            }
            Ok(Value::Object(map))
        },

        // Array - recursively unwrap all element values
        CoreValue::Array(arr) => {
            let values: Result<Vec<_>, _> = arr.0.iter()
                .map(|v| {
                    let wrapped_v = unsafe {
                        // SAFETY: Same transparent wrapper logic
                        std::mem::transmute::<&CoreValue, &surrealdb::Value>(v)
                    };
                    surreal_value_to_json(wrapped_v)
                })
                .collect();
            Ok(Value::Array(values?))
        },

        // Boolean values - direct conversion
        CoreValue::Bool(b) => Ok(Value::Bool(*b)),

        // Null and None - both map to JSON null
        CoreValue::None | CoreValue::Null => Ok(Value::Null),

        // DateTime - convert to ISO 8601 string representation
        CoreValue::Datetime(dt) => Ok(Value::String(dt.to_string())),

        // UUID - convert to standard UUID string format
        CoreValue::Uuid(uuid) => Ok(Value::String(uuid.to_string())),

        // Duration - convert to string representation
        CoreValue::Duration(d) => Ok(Value::String(d.to_string())),

        // Geometry types - convert to string representation
        // TODO: Consider converting to proper GeoJSON format in future
        CoreValue::Geometry(geo) => {
            Ok(Value::String(geo.to_string()))
        },

        // Bytes - convert to base64 string for safe JSON transport
        CoreValue::Bytes(bytes) => {
            use base64::{Engine as _, engine::general_purpose};
            let encoded = general_purpose::STANDARD.encode(&**bytes);
            Ok(Value::String(encoded))
        },

        // Query/Subquery - convert to string representation
        CoreValue::Query(_) | CoreValue::Subquery(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Function - convert to string representation
        CoreValue::Function(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Model - convert to string representation
        CoreValue::Model(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Range - convert to string representation
        CoreValue::Range(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Param - convert to string representation
        CoreValue::Param(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Idiom - convert to string representation
        CoreValue::Idiom(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Table - convert to string representation
        CoreValue::Table(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Mock - convert to string representation
        CoreValue::Mock(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Regex - convert to string representation
        CoreValue::Regex(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Block - convert to string representation
        CoreValue::Block(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Constant - convert to string representation
        CoreValue::Constant(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Cast - convert to string representation
        CoreValue::Cast(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Expression - convert to string representation
        CoreValue::Expression(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Future - convert to string representation
        CoreValue::Future(_) => {
            Ok(Value::String(core_value.to_string()))
        },

        // Catch-all for any other types not explicitly handled
        // Uses Display trait as fallback
        _ => {
            Ok(Value::String(format!("{}", core_value)))
        }
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
                    match response.take::<surrealdb::Value>(idx) {
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
                    match response.take::<surrealdb::Value>(idx) {
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
                    match response.take::<surrealdb::Value>(idx) {
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
                    match response.take::<surrealdb::Value>(idx) {
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
                    match response.take::<surrealdb::Value>(idx) {
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
