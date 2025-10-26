# SurrealDB Dart SDK - Current Progress

**Last Updated:** October 22, 2025
**Current Phase:** Phase 1 - Transaction Rollback Bug Investigation (75% complete)
**Status:** Root cause identified, implementation plan approved, ready to implement fix

---

## 🎯 Quick Start - Where We Are

### Current Situation
- **Original SDK Parity:** 40% production ready (86% test pass rate)
- **Phase 1 Status:** Investigation complete, fix ready to implement
- **Blocking Issue:** Transaction rollback doesn't work - changes persist after CANCEL TRANSACTION
- **Root Cause:** Statement-based approach - each query() call is isolated, no transaction context
- **Solution:** Buffered transaction pattern using SurrealDB's query chaining

### What's Been Completed ✅

1. **Full Investigation (Task Groups 1.1, 1.2, 1.3)**
   - Rust logging infrastructure added (env_logger, log crate)
   - Logger FFI binding implemented and working
   - Tested with both mem:// and rocksdb:// backends
   - Comprehensive Rust logs captured
   - Root cause identified with evidence

2. **Documentation**
   - 70+ page investigation report
   - Root cause analysis
   - Architectural solution designed
   - Implementation plan approved

### What Needs to Be Done ⏳

**Task Group 1.4: Implement Rollback Fix (14-21 hours)**
- Implement buffered transaction pattern
- Create Rust FFI function for batched execution
- Update Dart transaction() method
- Test and verify all 8 transaction tests pass

---

## 🔍 Technical Deep Dive

### The Problem

**Current Implementation:**
```rust
// These are SEPARATE, ISOLATED calls:
db.query("BEGIN TRANSACTION")      // Call 1
// ... operations ...
db.query("CANCEL TRANSACTION")     // Call 2 - doesn't know about Call 1!
```

**Why It Fails:**
- Each `query()` call operates independently
- CANCEL TRANSACTION has no knowledge of previous BEGIN
- Both execute successfully but don't create actual transaction scope
- Changes persist after CANCEL (not rolled back)

**Evidence:**
- Test expects: 1 record after rollback
- Test finds: 3 records (changes NOT discarded)
- Affects ALL backends (mem:// and rocksdb://)
- Only test verifying rollback by counting records fails

### The Solution: Buffered Transaction Pattern

**How SurrealDB Really Works:**
```rust
// Must chain queries in SINGLE operation:
db.query("BEGIN")
  .query("CREATE ...")
  .query("UPDATE ...")
  .query("COMMIT")  // All execute together
  .await?
```

**Architecture:**

```
┌─────────────────────────────────────────┐
│ Dart: transaction((txn) => { ... })    │
│                                         │
│ 1. Create _TransactionRecorder         │
│    - Buffers queries, doesn't execute  │
│                                         │
│ 2. Execute callback                    │
│    - txn.create() → buffer query       │
│    - txn.update() → buffer query       │
│                                         │
│ 3. On success:                         │
│    ┌────────────────────────────┐     │
│    │ Send to Rust FFI:          │     │
│    │ ["BEGIN",                  │     │
│    │  "CREATE ...",             │     │
│    │  "UPDATE ...",             │     │
│    │  "COMMIT"]                 │     │
│    └────────────────────────────┘     │
│                                         │
│ 4. On error:                           │
│    ┌────────────────────────────┐     │
│    │ Send to Rust FFI:          │     │
│    │ ["BEGIN",                  │     │
│    │  "CREATE ...",             │     │
│    │  "UPDATE ...",             │     │
│    │  "CANCEL"]                 │     │
│    └────────────────────────────┘     │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ Rust: db_execute_transaction()         │
│                                         │
│ 1. Chain all queries:                  │
│    db.query(queries[0])               │
│      .query(queries[1])               │
│      .query(queries[2])               │
│      ...                               │
│      .query(queries[n])               │
│                                         │
│ 2. Execute as ONE operation:          │
│    .await? ← Everything happens here  │
│                                         │
│ 3. Return combined response            │
└─────────────────────────────────────────┘
```

**Key Benefits:**
- ✅ Stateless FFI (single function call)
- ✅ Proper transactions (uses SurrealDB's official pattern)
- ✅ Rollback works (all queries execute together)
- ✅ Maintains API (user's callback pattern preserved)

**Trade-offs:**
- ⚠️ No intermediate results during transaction
- ⚠️ Need to convert method calls to SurrealQL strings
- ⚠️ All operations must be buffered before execution

---

## 📁 Important File Locations

### Investigation Report
`/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-22-sdk-parity-issues-resolution/implementation/phase-1-transaction-rollback-fix.md`
- 70+ page comprehensive investigation
- Root cause analysis with evidence
- Backend comparison results
- Rust log excerpts

### Specification Files
- **Spec:** `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-22-sdk-parity-issues-resolution/spec.md`
- **Tasks:** `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-22-sdk-parity-issues-resolution/tasks.md`
- **Task Assignments:** `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-22-sdk-parity-issues-resolution/planning/task-assignments.yml`

### Code Files to Modify
- **Dart Transaction Logic:** `/Users/fabier/Documents/code/surrealdartb/lib/src/database.dart` (line 528+)
- **Rust Transaction Functions:** `/Users/fabier/Documents/code/surrealdartb/rust/src/database.rs`
- **Rust FFI Exports:** `/Users/fabier/Documents/code/surrealdartb/rust/src/lib.rs`
- **Dart FFI Types:** `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/native_types.dart`
- **Dart FFI Bindings:** `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/bindings.dart`

### Test Files
- **Transaction Tests:** `/Users/fabier/Documents/code/surrealdartb/test/transaction_test.dart`
  - Currently: 7/8 passing
  - Failing: "transaction rollback discards all changes"

---

## 🚀 Implementation Steps - Ready to Execute

### Step 1: Dart-Side Buffering (6-8 hours)

**Create `_TransactionRecorder` class** in `/Users/fabier/Documents/code/surrealdartb/lib/src/database.dart`:

```dart
/// Internal class that records database operations as SurrealQL queries
/// instead of executing them immediately. Used for transaction buffering.
class _TransactionRecorder extends Database {
  final List<String> queries = [];
  bool _closed = false;

  _TransactionRecorder(Pointer<NativeDatabase> handle) : super._(handle);

  @override
  Future<Map<String, dynamic>> create(String table, Map<String, dynamic> data) async {
    queries.add("CREATE $table CONTENT ${jsonEncode(data)}");
    // Return optimistic result - real results come from transaction execution
    return {'id': '$table:pending'};
  }

  @override
  Future<Map<String, dynamic>> update(String resource, Map<String, dynamic> data) async {
    queries.add("UPDATE $resource CONTENT ${jsonEncode(data)}");
    return {};
  }

  @override
  Future<void> delete(String resource) async {
    queries.add("DELETE $resource");
  }

  @override
  Future<Response> query(String sql, [Map<String, dynamic>? bindings]) async {
    queries.add(sql);
    return Response([]);
  }

  // Override other methods as needed...
}
```

**Update `transaction()` method**:

```dart
Future<T> transaction<T>(Future<T> Function(Database txn) callback) async {
  _ensureNotClosed();

  // Create recording database
  final recorder = _TransactionRecorder(_handle);

  try {
    // Execute callback - operations get buffered
    final result = await callback(recorder);

    // Success: execute transaction with COMMIT
    await _executeTransaction(recorder.queries, commit: true);

    return result;
  } catch (e) {
    // Error: execute transaction with ROLLBACK
    try {
      await _executeTransaction(recorder.queries, commit: false);
    } catch (rollbackError) {
      // Log rollback error but rethrow original
      print('Warning: Rollback failed: $rollbackError');
    }
    rethrow;
  }
}

/// Helper method to execute buffered transaction
Future<void> _executeTransaction(List<String> queries, {required bool commit}) async {
  return Future(() {
    // Convert Dart List<String> to C array
    final queryPtrs = queries.map((q) => q.toNativeUtf8()).toList();
    final arrayPtr = malloc<Pointer<Utf8>>(queries.length);

    try {
      // Fill array
      for (var i = 0; i < queries.length; i++) {
        arrayPtr[i] = queryPtrs[i];
      }

      // Call FFI function
      final responsePtr = dbExecuteTransaction(
        _handle,
        arrayPtr,
        queries.length,
        commit ? 0 : 1, // 0 = commit, 1 = rollback
      );

      // Process response
      _processResponse(responsePtr);
    } finally {
      // Free all allocated memory
      for (var ptr in queryPtrs) {
        malloc.free(ptr);
      }
      malloc.free(arrayPtr);
    }
  });
}
```

### Step 2: Rust FFI Function (4-6 hours)

**Add to `/Users/fabier/Documents/code/surrealdartb/rust/src/database.rs`**:

```rust
use std::slice;

/// Execute a transaction with multiple queries as a single chained operation
///
/// # Arguments
/// * `handle` - Pointer to Database instance
/// * `queries` - Array of C strings containing SurrealQL queries
/// * `query_count` - Number of queries in the array
/// * `mode` - 0 for COMMIT, 1 for ROLLBACK (CANCEL)
///
/// # Returns
/// Pointer to NativeResponse with combined results
///
/// # Safety
/// - handle must be valid Database pointer
/// - queries must be valid array of C strings
/// - query_count must match actual array length
#[no_mangle]
pub extern "C" fn db_execute_transaction(
    handle: *mut Database,
    queries: *const *const c_char,
    query_count: usize,
    mode: i32,
) -> *mut NativeResponse {
    match panic::catch_unwind(|| {
        if handle.is_null() {
            set_last_error("Database handle cannot be null");
            return std::ptr::null_mut();
        }

        let db = unsafe { &*handle };

        // Convert C array to Rust Vec
        let query_slice = unsafe { slice::from_raw_parts(queries, query_count) };
        let mut query_strings = Vec::new();

        for &query_ptr in query_slice {
            if query_ptr.is_null() {
                set_last_error("Null query in array");
                return std::ptr::null_mut();
            }

            let query = unsafe {
                match CStr::from_ptr(query_ptr).to_str() {
                    Ok(s) => s.to_string(),
                    Err(_) => {
                        set_last_error("Invalid UTF-8 in query");
                        return std::ptr::null_mut();
                    }
                }
            };
            query_strings.push(query);
        }

        info!("[TRANSACTION] Executing transaction with {} queries, mode: {}",
              query_count, if mode == 0 { "COMMIT" } else { "ROLLBACK" });

        let runtime = get_runtime();
        match runtime.block_on(async {
            // Start chain with BEGIN TRANSACTION
            let mut chain = db.inner.query("BEGIN TRANSACTION");

            // Add all user queries
            for query in &query_strings {
                debug!("[TRANSACTION] Chaining query: {}", query);
                chain = chain.query(query.as_str());
            }

            // Add final COMMIT or CANCEL
            if mode == 0 {
                info!("[TRANSACTION] Finalizing with COMMIT");
                chain = chain.query("COMMIT TRANSACTION");
            } else {
                info!("[TRANSACTION] Finalizing with CANCEL");
                chain = chain.query("CANCEL TRANSACTION");
            }

            // Execute entire chain as ONE operation
            chain.await
        }) {
            Ok(response) => {
                info!("[TRANSACTION] Transaction executed successfully");
                // Convert response to JSON and wrap in NativeResponse
                let json = surreal_value_to_json(&response);
                create_response(&json)
            }
            Err(e) => {
                error!("[TRANSACTION] Transaction failed: {}", e);
                set_last_error(&format!("Transaction execution failed: {}", e));
                std::ptr::null_mut()
            }
        }
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("Panic in db_execute_transaction");
            std::ptr::null_mut()
        }
    }
}
```

**Export in `/Users/fabier/Documents/code/surrealdartb/rust/src/lib.rs`**:

```rust
pub use database::{
    db_new, db_connect, db_close, db_use_ns, db_use_db,
    db_begin, db_commit, db_rollback,
    db_execute_transaction,  // ← Add this
    init_logger
};
```

### Step 3: Dart FFI Bindings (2-3 hours)

**Add typedef to `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/native_types.dart`**:

```dart
/// Execute transaction with array of queries
///
/// Parameters:
/// - handle: Database pointer
/// - queries: Array of C strings
/// - queryCount: Number of queries
/// - mode: 0 for COMMIT, 1 for ROLLBACK
///
/// Returns: NativeResponse pointer
typedef NativeDbExecuteTransaction = Pointer<NativeResponse> Function(
  Pointer<NativeDatabase> handle,
  Pointer<Pointer<Utf8>> queries,
  Int32 queryCount,
  Int32 mode,
);
```

**Add binding to `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/bindings.dart`**:

```dart
/// Execute transaction with multiple queries in a single chained operation
///
/// This function executes all queries as a single transaction chain:
/// BEGIN → query1 → query2 → ... → COMMIT/CANCEL
///
/// Parameters:
/// - [handle] - Database instance pointer
/// - [queries] - Array of query strings as C strings
/// - [queryCount] - Number of queries in the array
/// - [mode] - 0 for COMMIT, 1 for ROLLBACK
///
/// Returns pointer to NativeResponse containing combined results
@Native<NativeDbExecuteTransaction>(symbol: 'db_execute_transaction')
external Pointer<NativeResponse> dbExecuteTransaction(
  Pointer<NativeDatabase> handle,
  Pointer<Pointer<Utf8>> queries,
  int queryCount,
  int mode,
);
```

### Step 4: Testing & Verification (2-4 hours)

**Run transaction tests:**
```bash
RUST_LOG=info dart test test/transaction_test.dart
```

**Expected Results:**
- All 8/8 transaction tests passing
- "transaction rollback discards all changes" now passes
- Rust logs show single chained execution
- Rollback properly discards changes

**Verify:**
```bash
# Test with mem://
dart test test/transaction_test.dart --name "rollback"

# Test with rocksdb://
# (modify test temporarily to use rocksdb://)
dart test test/transaction_test.dart --name "rollback"
```

---

## 📊 Test Status

### Current (Before Fix)
```
Transaction Tests: 7/8 passing (87.5%)

✅ transaction commits on success
✅ transaction rolls back on exception
✅ transaction-scoped database operations
✅ callback return value propagates
✅ transaction with query operations
✅ nested operations within transaction
✅ transaction with delete operations
❌ transaction rollback discards all changes  ← FAILS

Issue: Expects 1 record, finds 3 records
```

### Target (After Fix)
```
Transaction Tests: 8/8 passing (100%)

✅ All tests passing
✅ Rollback properly discards changes
✅ Works with both mem:// and rocksdb://
✅ Proper transaction isolation
```

---

## 🎯 Success Criteria

**Phase 1 Complete When:**
1. ✅ All 8 transaction tests pass
2. ✅ Rollback test verifies only 1 record remains (not 3)
3. ✅ Works with both mem:// and rocksdb:// backends
4. ✅ No regressions in other tests
5. ✅ Rust logs show chained query execution
6. ✅ Documentation updated
7. ✅ tasks.md updated (Task Groups 1.1-1.4 complete)

---

## 🔄 After Phase 1

### Phase 2: Insert Operations (Days 3-4)
- Reimplement based on previous spec Task 2.1
- Methods: insertContent(), insertRelation()
- Target: 6/8 tests passing

### Phase 3: Upsert Operations (Days 5-6)
- Reimplement based on previous spec Task 2.2
- Methods: upsertContent(), upsertMerge(), upsertPatch()
- Target: 8/8 tests passing

### Phase 4: Type Casting Fixes (Days 7-8)
- Fix parameter and integration test type mismatches
- Target: 100% pass rate for in-scope features

### Phase 5: Final Verification (Days 9-10)
- Comprehensive testing
- Documentation updates
- Release preparation

---

## 💡 Quick Tips

### Running Tests with Logging
```bash
# Full logging
RUST_LOG=debug dart test test/transaction_test.dart

# Transaction logging only
RUST_LOG=info dart test test/transaction_test.dart --name "rollback"

# Grep for transaction events
RUST_LOG=info dart test test/transaction_test.dart 2>&1 | grep TRANSACTION
```

### Rebuilding Native Library
```bash
cd rust
cargo build --release
cd ..
```

### Debugging FFI Issues
```bash
# Check native library size and timestamp
ls -lh rust/target/release/libsurrealdartb_bindings.dylib

# Check exports
nm -g rust/target/release/libsurrealdartb_bindings.dylib | grep transaction
```

---

## 📚 Reference Documentation

### SurrealDB Transaction Docs
- https://surrealdb.com/docs/sdk/rust/concepts/transaction
- Key insight: Must chain queries in single operation

### Investigation Report
- Full 70+ page analysis with evidence
- Location: `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-22-sdk-parity-issues-resolution/implementation/phase-1-transaction-rollback-fix.md`

### Spec Files
- Comprehensive specification and task breakdown
- Location: `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-22-sdk-parity-issues-resolution/`

---

## ⚠️ Important Notes

1. **Query Buffering Limitation:** Operations in transaction callback can't access real results until transaction completes. They get optimistic/placeholder responses.

2. **Query String Conversion:** Need to convert Dart method calls to valid SurrealQL strings. Pay attention to syntax for CREATE, UPDATE, DELETE.

3. **Memory Management:** Carefully free all C string allocations in _executeTransaction helper.

4. **Error Handling:** Ensure rollback attempts even if callback throws, but original exception is preserved.

5. **Logging:** Use RUST_LOG=info to see transaction execution flow during development.

---

## 🎉 When You're Ready to Start

1. Review this document
2. Open the implementation plan above
3. Start with Step 1 (Dart-side buffering)
4. Test incrementally
5. Move to Step 2 (Rust FFI)
6. Complete bindings and test

**Estimated Total Time:** 14-21 hours over 2-3 days

**Current Status:** Investigation complete, plan approved, ready to code!

---

**Good luck! 🚀**
