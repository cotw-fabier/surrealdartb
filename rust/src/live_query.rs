/// Live query support for SurrealDB FFI
///
/// This module implements live query functionality using a polling-based approach
/// suitable for embedded mode. Notifications are stored in queues that Dart polls
/// periodically.
///
/// # Architecture
///
/// 1. Live query starts a background task that listens for changes
/// 2. Notifications are pushed into a thread-safe queue
/// 3. Dart polls the queue periodically via FFI
/// 4. Cleanup kills the live query and clears the queue
///
/// # Thread Safety
///
/// All notification queues are protected by Arc<Mutex<>>. Multiple Dart isolates
/// can safely poll different live query subscriptions concurrently.

use std::collections::HashMap;
use std::ffi::{CStr, CString, c_char};
use std::panic;
use std::ptr;
use std::sync::{Arc, Mutex};
use lazy_static::lazy_static;
use serde_json::{json, Value};
use surrealdb::sql::Thing;
use crate::database::Database;
use crate::error::set_last_error;
use crate::runtime::get_runtime;

/// A notification from a live query subscription
#[derive(Debug, Clone)]
pub struct LiveNotification {
    pub query_id: String,
    pub action: String, // "create", "update", "delete"
    pub data: Value,
}

/// A live query subscription handle
struct LiveSubscription {
    query_id: String,
    notifications: Arc<Mutex<Vec<LiveNotification>>>,
    // The actual SurrealDB live query stream would be stored here
    // but we'll use a simplified approach for embedded mode
}

lazy_static! {
    /// Global registry of active live query subscriptions
    /// Key: subscription ID (generated UUID)
    /// Value: LiveSubscription with notification queue
    static ref LIVE_SUBSCRIPTIONS: Arc<Mutex<HashMap<String, LiveSubscription>>> =
        Arc::new(Mutex::new(HashMap::new()));
}

/// Starts a live query subscription for a table
///
/// # Safety
///
/// - db_handle must be a valid Database pointer
/// - table must be a valid UTF-8 C string
/// - Returns a C string containing the subscription ID (must be freed with free_string)
/// - Returns nullptr on error (call get_last_error for details)
///
/// # Embedded Mode Behavior
///
/// In embedded mode, live queries use a polling mechanism rather than push notifications.
/// The Rust layer maintains a queue of notifications that Dart polls periodically.
#[no_mangle]
pub extern "C" fn db_select_live(
    db_handle: *mut Database,
    table: *const c_char,
) -> *mut c_char {
    // Wrap in catch_unwind to prevent panic across FFI boundary
    let result = panic::catch_unwind(|| {
        // Validate inputs
        if db_handle.is_null() {
            set_last_error("Database handle cannot be null");
            return ptr::null_mut();
        }

        if table.is_null() {
            set_last_error("Table name cannot be null");
            return ptr::null_mut();
        }

        // Convert C string to Rust string
        let table_str = match unsafe { CStr::from_ptr(table) }.to_str() {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&format!("Invalid UTF-8 in table name: {}", e));
                return ptr::null_mut();
            }
        };

        // Get database reference
        let db = unsafe { &*db_handle };
        let runtime = get_runtime();

        // Execute live query
        let result = runtime.block_on(async {
            db.inner.select(table_str).live().await
        });

        match result {
            Ok(mut stream) => {
                // Generate a unique subscription ID
                let subscription_id = uuid::Uuid::new_v4().to_string();
                let query_id = subscription_id.clone();

                // Create notification queue
                let notifications = Arc::new(Mutex::new(Vec::new()));
                let notifications_clone = Arc::clone(&notifications);

                // Spawn a background task to listen for notifications
                // This task will run until the live query is killed
                let table_owned = table_str.to_string();
                runtime.spawn(async move {
                    use futures::StreamExt;

                    while let Some(notification) = stream.next().await {
                        // Convert notification to our format
                        let action = match notification.action {
                            surrealdb::Action::Create => "create",
                            surrealdb::Action::Update => "update",
                            surrealdb::Action::Delete => "delete",
                            _ => "unknown",
                        };

                        // Convert the notification data to JSON
                        let data_json = match crate::query::surreal_value_to_json(&notification.data) {
                            Ok(json) => json,
                            Err(e) => {
                                eprintln!("Failed to convert notification data to JSON: {}", e);
                                json!({"error": format!("Conversion failed: {}", e)})
                            }
                        };

                        let live_notif = LiveNotification {
                            query_id: query_id.clone(),
                            action: action.to_string(),
                            data: data_json,
                        };

                        // Add to queue
                        if let Ok(mut queue) = notifications_clone.lock() {
                            queue.push(live_notif);

                            // Prevent unbounded growth - keep only last 1000 notifications
                            if queue.len() > 1000 {
                                queue.drain(0..queue.len() - 1000);
                            }
                        }
                    }
                });

                // Store subscription
                let subscription = LiveSubscription {
                    query_id: query_id.clone(),
                    notifications,
                };

                if let Ok(mut subs) = LIVE_SUBSCRIPTIONS.lock() {
                    subs.insert(subscription_id.clone(), subscription);
                }

                // Return subscription ID as C string
                match CString::new(subscription_id) {
                    Ok(c_str) => c_str.into_raw(),
                    Err(e) => {
                        set_last_error(&format!("Failed to create subscription ID string: {}", e));
                        ptr::null_mut()
                    }
                }
            }
            Err(e) => {
                set_last_error(&format!("Failed to start live query: {}", e));
                ptr::null_mut()
            }
        }
    });

    result.unwrap_or_else(|e| {
        set_last_error(&format!("Panic in db_select_live: {:?}", e));
        ptr::null_mut()
    })
}

/// Polls for new notifications from a live query subscription
///
/// # Safety
///
/// - subscription_id must be a valid UTF-8 C string returned from db_select_live
/// - Returns a C string containing JSON array of notifications (must be freed with free_string)
/// - Returns nullptr on error (call get_last_error for details)
/// - Returns empty JSON array "[]" if no new notifications
///
/// # Return Format
///
/// JSON array of notification objects:
/// ```json
/// [
///   {
///     "queryId": "uuid",
///     "action": "create",
///     "data": {...}
///   },
///   ...
/// ]
/// ```
#[no_mangle]
pub extern "C" fn db_live_poll(
    subscription_id: *const c_char,
) -> *mut c_char {
    let result = panic::catch_unwind(|| {
        if subscription_id.is_null() {
            set_last_error("Subscription ID cannot be null");
            return ptr::null_mut();
        }

        // Convert C string to Rust string
        let sub_id_str = match unsafe { CStr::from_ptr(subscription_id) }.to_str() {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&format!("Invalid UTF-8 in subscription ID: {}", e));
                return ptr::null_mut();
            }
        };

        // Get subscription
        let notifications = {
            let subs = match LIVE_SUBSCRIPTIONS.lock() {
                Ok(s) => s,
                Err(e) => {
                    set_last_error(&format!("Failed to lock subscriptions: {}", e));
                    return ptr::null_mut();
                }
            };

            match subs.get(sub_id_str) {
                Some(sub) => {
                    // Get all pending notifications and clear the queue
                    let mut queue = match sub.notifications.lock() {
                        Ok(q) => q,
                        Err(e) => {
                            set_last_error(&format!("Failed to lock notification queue: {}", e));
                            return ptr::null_mut();
                        }
                    };

                    let notifs = queue.drain(..).collect::<Vec<_>>();
                    notifs
                }
                None => {
                    set_last_error(&format!("Subscription not found: {}", sub_id_str));
                    return ptr::null_mut();
                }
            }
        };

        // Convert notifications to JSON
        let json_notifications: Vec<Value> = notifications.iter().map(|n| {
            json!({
                "queryId": n.query_id,
                "action": n.action,
                "data": n.data
            })
        }).collect();

        let json_str = match serde_json::to_string(&json_notifications) {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&format!("Failed to serialize notifications: {}", e));
                return ptr::null_mut();
            }
        };

        match CString::new(json_str) {
            Ok(c_str) => c_str.into_raw(),
            Err(e) => {
                set_last_error(&format!("Failed to create result string: {}", e));
                ptr::null_mut()
            }
        }
    });

    result.unwrap_or_else(|e| {
        set_last_error(&format!("Panic in db_live_poll: {:?}", e));
        ptr::null_mut()
    })
}

/// Kills a live query subscription and cleans up resources
///
/// # Safety
///
/// - db_handle must be a valid Database pointer
/// - subscription_id must be a valid UTF-8 C string returned from db_select_live
/// - Returns 0 on success, -1 on error
/// - After calling this, the subscription_id is invalid and should not be used
#[no_mangle]
pub extern "C" fn db_kill_live(
    db_handle: *mut Database,
    subscription_id: *const c_char,
) -> i32 {
    let result = panic::catch_unwind(|| {
        if db_handle.is_null() {
            set_last_error("Database handle cannot be null");
            return -1;
        }

        if subscription_id.is_null() {
            set_last_error("Subscription ID cannot be null");
            return -1;
        }

        // Convert C string to Rust string
        let sub_id_str = match unsafe { CStr::from_ptr(subscription_id) }.to_str() {
            Ok(s) => s,
            Err(e) => {
                set_last_error(&format!("Invalid UTF-8 in subscription ID: {}", e));
                return -1;
            }
        };

        // Get database reference
        let db = unsafe { &*db_handle };
        let runtime = get_runtime();

        // Remove subscription from registry
        let subscription = {
            let mut subs = match LIVE_SUBSCRIPTIONS.lock() {
                Ok(s) => s,
                Err(e) => {
                    set_last_error(&format!("Failed to lock subscriptions: {}", e));
                    return -1;
                }
            };

            match subs.remove(sub_id_str) {
                Some(sub) => sub,
                None => {
                    // Already removed or never existed - this is OK
                    return 0;
                }
            }
        };

        // Kill the live query in SurrealDB
        let result = runtime.block_on(async {
            // SurrealDB's kill method takes the query ID as a UUID
            let query_uuid = match uuid::Uuid::parse_str(&subscription.query_id) {
                Ok(uuid) => uuid,
                Err(e) => {
                    return Err(format!("Invalid query UUID: {}", e));
                }
            };

            db.inner.kill(query_uuid).await
                .map_err(|e| format!("Failed to kill live query: {}", e))
        });

        match result {
            Ok(_) => 0,
            Err(e) => {
                set_last_error(&e);
                -1
            }
        }
    });

    result.unwrap_or_else(|e| {
        set_last_error(&format!("Panic in db_kill_live: {:?}", e));
        -1
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;
    use crate::database::db_new;
    use crate::query::{db_create, response_free};

    #[test]
    fn test_live_query_basic() {
        // Create database
        let endpoint = CString::new("mem://").unwrap();
        let db = db_new(endpoint.as_ptr());
        assert!(!db.is_null());

        // Set namespace and database
        let ns = CString::new("test").unwrap();
        let db_name = CString::new("test").unwrap();

        let db_ref = unsafe { &*db };
        let runtime = get_runtime();
        runtime.block_on(async {
            db_ref.db.use_ns("test").await.unwrap();
            db_ref.db.use_db("test").await.unwrap();
        });

        // Start live query
        let table = CString::new("person").unwrap();
        let sub_id = db_select_live(db, table.as_ptr());
        assert!(!sub_id.is_null());

        // Poll for notifications (should be empty initially)
        let notifications = db_live_poll(sub_id);
        assert!(!notifications.is_null());

        let notif_str = unsafe { CStr::from_ptr(notifications) }.to_str().unwrap();
        assert_eq!(notif_str, "[]");

        // Clean up
        db_kill_live(db, sub_id);
        crate::error::free_string(sub_id);
        crate::error::free_string(notifications);
        crate::database::db_close(db);
    }
}
