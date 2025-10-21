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
/// Recursively unwraps SurrealDB's internal type wrappers to produce plain JSON
fn surreal_value_to_json(value: &surrealdb::Value) -> Result<Value, String> {
    // Serialize the SurrealDB Value - this gives us the type-wrapped JSON
    let json_str = serde_json::to_string(value)
        .map_err(|e| format!("Serialization error: {}", e))?;

    eprintln!("[UNWRAP] Input JSON string: {}", &json_str[..std::cmp::min(500, json_str.len())]);

    // Parse it as a serde_json::Value
    let wrapped: serde_json::Value = serde_json::from_str(&json_str)
        .map_err(|e| format!("Parse error: {}", e))?;

    eprintln!("[UNWRAP] Parsed as serde_json::Value");

    // Recursively unwrap type tags
    let result = unwrap_value(wrapped);

    let result_str = serde_json::to_string(&result).unwrap_or_else(|_| "error".to_string());
    eprintln!("[UNWRAP] Output JSON string: {}", &result_str[..std::cmp::min(500, result_str.len())]);

    Ok(result)
}

/// Recursively unwraps SurrealDB type tags from JSON
fn unwrap_value(value: serde_json::Value) -> serde_json::Value {
    use serde_json::Value as JV;

    match &value {
        JV::Object(map) if map.len() == 1 => {
            let key = map.keys().next().unwrap();
            eprintln!("[UNWRAP] Single-key object with key: {}", key);
        }
        JV::Object(map) => {
            eprintln!("[UNWRAP] Multi-key object with {} keys", map.len());
        }
        JV::Array(arr) => {
            eprintln!("[UNWRAP] Array with {} elements", arr.len());
        }
        _ => {}
    }

    match value {
        JV::Object(mut map) if map.len() == 1 => {
            // Check for type wrapper patterns
            if let Some(v) = map.remove("Strand") {
                eprintln!("[UNWRAP] Unwrapping Strand");
                v
            } else if let Some(v) = map.remove("Number") {
                eprintln!("[UNWRAP] Unwrapping Number");
                unwrap_number(v)
            } else if let Some(v) = map.remove("Thing") {
                eprintln!("[UNWRAP] Unwrapping Thing");
                unwrap_thing(v)
            } else if let Some(v) = map.remove("Array") {
                eprintln!("[UNWRAP] Unwrapping Array wrapper");
                unwrap_array(v)
            } else if let Some(v) = map.remove("Object") {
                eprintln!("[UNWRAP] Unwrapping Object wrapper");
                unwrap_object(v)
            } else if let Some(v) = map.remove("Bool") {
                eprintln!("[UNWRAP] Unwrapping Bool");
                v
            } else if let Some(_v) = map.remove("Null") {
                eprintln!("[UNWRAP] Unwrapping Null");
                JV::Null
            } else if let Some(v) = map.remove("Uuid") {
                eprintln!("[UNWRAP] Unwrapping Uuid");
                v
            } else if let Some(v) = map.remove("Datetime") {
                eprintln!("[UNWRAP] Unwrapping Datetime");
                v
            } else {
                eprintln!("[UNWRAP] Not a recognized wrapper, recursing into object");
                JV::Object(map.into_iter().map(|(k, v)| (k, unwrap_value(v))).collect())
            }
        }
        JV::Object(map) => {
            eprintln!("[UNWRAP] Regular multi-key object, recursing");
            JV::Object(map.into_iter().map(|(k, v)| (k, unwrap_value(v))).collect())
        }
        JV::Array(arr) => {
            eprintln!("[UNWRAP] Processing array");
            JV::Array(arr.into_iter().map(unwrap_value).collect())
        }
        other => other, // Primitives pass through
    }
}

fn unwrap_number(value: serde_json::Value) -> serde_json::Value {
    use serde_json::Value as JV;

    if let JV::Object(mut map) = value {
        if let Some(v) = map.remove("Int") {
            v
        } else if let Some(v) = map.remove("Float") {
            v
        } else if let Some(v) = map.remove("Decimal") {
            v
        } else {
            JV::Object(map)
        }
    } else {
        value
    }
}

fn unwrap_thing(value: serde_json::Value) -> serde_json::Value {
    use serde_json::Value as JV;

    if let JV::Object(ref map) = value {
        let table = map.get("tb").and_then(|v| v.as_str()).unwrap_or("");
        let id = map.get("id").map(|v| unwrap_value(v.clone()));

        // Format as "table:id"
        if let Some(JV::String(id_str)) = id {
            JV::String(format!("{}:{}", table, id_str))
        } else if let Some(id_val) = id {
            // For complex IDs, convert to string representation
            JV::String(format!("{}:{}", table, id_val))
        } else {
            value
        }
    } else {
        value
    }
}

fn unwrap_array(value: serde_json::Value) -> serde_json::Value {
    use serde_json::Value as JV;

    if let JV::Array(arr) = value {
        JV::Array(arr.into_iter().map(unwrap_value).collect())
    } else {
        value
    }
}

fn unwrap_object(value: serde_json::Value) -> serde_json::Value {
    use serde_json::Value as JV;

    if let JV::Object(map) = value {
        JV::Object(map.into_iter().map(|(k, v)| (k, unwrap_value(v))).collect())
    } else {
        value
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
                            // Convert surrealdb::Value to serde_json::Value using helper
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

        // Use query() instead of select() to avoid deserialization issues
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

                // Extract results
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

        // Use query() with CREATE statement to avoid deserialization issues
        let query_sql = format!("CREATE {} CONTENT {}", table_str, data_str);

        eprintln!("[RUST] db_create SQL: {}", query_sql);
        eprintln!("[RUST] About to block_on...");

        match runtime.block_on(async {
            eprintln!("[RUST] Inside async block");
            let result = db.inner.query(&query_sql).await;
            eprintln!("[RUST] Query returned: {:?}", result.is_ok());
            result
        }) {
            Ok(mut response) => {
                let mut results = Vec::new();
                let mut errors = Vec::new();

                let num_statements = response.num_statements();
                eprintln!("[RUST CREATE] num_statements = {}", num_statements);

                // Extract errors
                let error_map = response.take_errors();
                for (idx, err) in error_map {
                    errors.push(format!("Statement {}: {}", idx, err));
                }

                // Extract results
                for idx in 0..num_statements {
                    eprintln!("[RUST CREATE] Extracting statement {} of {}", idx, num_statements);
                    match response.take::<surrealdb::Value>(idx) {
                        Ok(value) => {
                            eprintln!("[RUST CREATE] Got SurrealDB Value, calling unwrapper...");
                            match surreal_value_to_json(&value) {
                                Ok(json_value) => {
                                    eprintln!("[RUST CREATE] Unwrapper succeeded");
                                    results.push(json_value);
                                }
                                Err(e) => {
                                    eprintln!("[RUST CREATE] Unwrapper failed: {}", e);
                                    errors.push(format!("Failed to convert result: {}", e));
                                    results.push(Value::Null);
                                }
                            }
                        }
                        Err(e) => {
                            eprintln!("[RUST CREATE] take() failed: {}", e);
                            if !errors.iter().any(|err_msg| err_msg.contains(&format!("Statement {}:", idx))) {
                                errors.push(format!("Failed to extract result: {}", e));
                            }
                            results.push(Value::Null);
                        }
                    }
                }

                eprintln!("[RUST CREATE] Results vector has {} items", results.len());
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

        // Use query() with UPDATE statement to avoid deserialization issues
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

                // Extract results
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

        // Use query() with DELETE statement to avoid deserialization issues
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

                // Extract results
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
    use crate::database::{db_new, db_use_ns, db_use_db};

    #[test]
    fn test_query_execution() {
        let endpoint = std::ffi::CString::new("mem://").unwrap();
        let handle = db_new(endpoint.as_ptr());
        assert!(!handle.is_null());

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
}
