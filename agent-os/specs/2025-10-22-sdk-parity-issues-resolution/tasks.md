# Task Breakdown: SDK Parity Issues Resolution

## Overview
Total Tasks: 5 major phases with 21 task groups
Assigned roles: api-engineer, testing-engineer
Timeline: 6-10 days (sequential implementation)

## Task List

---

### Phase 1: Transaction Rollback Bug Investigation & Fix (CRITICAL - Days 1-2)

**DEPENDENCIES:** None - MUST complete before any other phase
**PRIORITY:** CRITICAL - Data integrity risk

---

#### Task Group 1.1: Add Instrumentation and Logging
**Assigned Implementer:** api-engineer
**Dependencies:** None
**Estimated Effort:** 4-6 hours (Day 1 Morning)

- [ ] 1.1.0 Add instrumentation to transaction rollback
  - [ ] 1.1.1 Add Rust-level logging to db_rollback function
    - Add log statements before CANCEL TRANSACTION execution
    - Add log statements after CANCEL TRANSACTION execution
    - Log transaction state at each lifecycle point
    - Log query execution details and responses
    - Use env_logger or similar for Rust logging
  - [ ] 1.1.2 Add logging to db_begin and db_commit for comparison
    - Log execution flow for successful paths
    - Log SurrealDB responses to identify patterns
    - Track transaction lifecycle across all three functions
  - [ ] 1.1.3 Enable SurrealDB query tracing if available
    - Research SurrealDB tracing capabilities
    - Enable detailed query logging in embedded mode
    - Capture transaction state transitions
  - [ ] 1.1.4 Add test instrumentation
    - Modify transaction_test.dart to add debug logging
    - Log database state before and after rollback
    - Add query to count records at each stage
  - [ ] 1.1.5 Rebuild native library with instrumentation
    - Compile Rust code with logging enabled
    - Verify logs are output during test execution
    - Document logging setup for future debugging

**Acceptance Criteria:**
- Logging outputs transaction lifecycle events
- Can trace CANCEL TRANSACTION execution
- Logs show database state before and after rollback
- Test suite outputs detailed debugging information
- No impact on test functionality (still 7/8 passing)

---

#### Task Group 1.2: Backend Testing and Comparison
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 1.1
**Estimated Effort:** 4-6 hours (Day 1 Afternoon)

- [ ] 1.2.0 Test transaction rollback with multiple backends
  - [ ] 1.2.1 Test with mem:// backend (current failing case)
    - Run existing transaction_test.dart with mem:// backend
    - Capture detailed logs from Task Group 1.1
    - Document specific behavior (records not rolled back)
    - Verify CANCEL TRANSACTION executes without error
  - [ ] 1.2.2 Test with rocksdb:// backend
    - Modify test setup to use rocksdb:// instead of mem://
    - Run "transaction rollback discards all changes" test
    - Compare behavior with mem:// backend
    - Document any differences in rollback behavior
  - [ ] 1.2.3 Compare transaction support across backends
    - Document which backends properly support rollback
    - Identify if this is a mem:// limitation
    - Review SurrealDB documentation for backend-specific behavior
  - [ ] 1.2.4 Analyze log outputs from both backends
    - Compare query execution traces
    - Identify differences in transaction state handling
    - Look for auto-commit indicators
    - Check for transaction isolation level differences
  - [ ] 1.2.5 Document findings in investigation report
    - Create markdown file with test results
    - Include log excerpts showing key differences
    - Summarize backend-specific behaviors
    - Propose hypotheses for root cause

**Acceptance Criteria:**
- Transaction tests run on both mem:// and rocksdb:// backends
- Detailed comparison document created
- Behavior differences (if any) are documented
- Log analysis provides insights into rollback execution
- Clear hypothesis about root cause emerges

---

#### Task Group 1.3: Root Cause Analysis
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 1.2
**Estimated Effort:** 4-6 hours (Day 2 Morning)

- [ ] 1.3.0 Identify root cause of rollback failure
  - [ ] 1.3.1 Review SurrealDB documentation for CANCEL TRANSACTION
    - Check if CANCEL TRANSACTION requires specific syntax
    - Verify if parameters or options are needed
    - Review transaction isolation level requirements
    - Check embedded mode specific constraints
  - [ ] 1.3.2 Verify transaction state maintenance across FFI
    - Confirm transaction state is preserved across FFI calls
    - Check if runtime.block_on() interferes with state
    - Verify db handle maintains transaction context
    - Test if connection state is properly managed
  - [ ] 1.3.3 Test for auto-commit behavior
    - Check if auto-commit is enabled by default
    - Research how to explicitly disable auto-commit
    - Test if each query() call implicitly commits
    - Verify transaction isolation is maintained
  - [ ] 1.3.4 Compare with SurrealDB Rust SDK examples
    - Review official SurrealDB Rust SDK transaction examples
    - Identify any missing setup or configuration
    - Compare statement execution patterns
    - Check if additional transaction parameters needed
  - [ ] 1.3.5 Test alternative rollback approaches
    - Try different CANCEL TRANSACTION syntax variations
    - Test explicit transaction isolation level setting
    - Try wrapping all operations in single query() call
    - Experiment with different query execution patterns
  - [ ] 1.3.6 Document root cause findings
    - Create detailed analysis document
    - Include supporting evidence from logs and tests
    - Propose specific fix approach
    - Identify any SurrealDB version dependencies

**Acceptance Criteria:**
- Root cause is clearly identified and documented
- Supporting evidence from tests and logs is provided
- Specific fix approach is proposed with rationale
- Any SurrealDB limitations are documented
- Clear understanding of why rollback is failing

---

#### Task Group 1.4: Implement Rollback Fix
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 1.3
**Estimated Effort:** 4-6 hours (Day 2 Afternoon)

- [ ] 1.4.0 Implement fix for transaction rollback
  - [ ] 1.4.1 Implement fix in rust/src/database.rs
    - Modify db_rollback function based on root cause findings
    - Add any required transaction configuration
    - Update CANCEL TRANSACTION statement if needed
    - Add proper transaction state management if required
    - Follow existing FFI patterns and error handling
  - [ ] 1.4.2 Update transaction lifecycle if needed
    - Modify db_begin if initialization changes required
    - Update db_commit for consistency if needed
    - Ensure proper transaction isolation configuration
    - Add any missing transaction setup steps
  - [ ] 1.4.3 Add defensive checks and validation
    - Validate transaction state before rollback
    - Add checks for active transaction existence
    - Implement guards against double-rollback
    - Add clear error messages for invalid states
  - [ ] 1.4.4 Rebuild native library with fix
    - Compile Rust code with fix
    - Verify symbols are exported correctly
    - Test library loads in Dart tests
  - [ ] 1.4.5 Run transaction tests to verify fix
    - Run all 8 transaction tests
    - Verify "transaction rollback discards all changes" now passes
    - Verify "transaction rolls back on exception" now passes
    - Ensure no regressions in other 6 passing tests
    - Test with both mem:// and rocksdb:// backends
  - [ ] 1.4.6 Document fix approach and rationale
    - Create implementation report for Phase 1
    - Document what was changed and why
    - Include before/after test results
    - Note any limitations or caveats
    - Update spec.md if findings require it

**Acceptance Criteria:**
- All 8 transaction tests pass (target: 8/8)
- Rollback actually discards changes (verified by test)
- Fix works on both mem:// and rocksdb:// backends
- No regressions in other database functionality
- Implementation report documents fix thoroughly
- Code follows existing FFI patterns

---

### Phase 2: Insert Operations Reimplementation (Days 3-4)

**DEPENDENCIES:** Phase 1 complete
**PRIORITY:** HIGH - Critical CRUD functionality

---

#### Task Group 2.1: Rust FFI Function for Insert
**Assigned Implementer:** api-engineer
**Dependencies:** Phase 1 Task Group 1.4
**Estimated Effort:** 3-4 hours (Day 3 Morning)

- [ ] 2.1.0 Implement db_insert FFI function in Rust
  - [ ] 2.1.1 Review implementation report 2.1-insert-operations-implementation.md
    - Study lines 926-1026 from report (original db_insert implementation)
    - Note panic::catch_unwind usage pattern
    - Review SQL generation: "INSERT INTO {resource} {data}"
    - Understand surreal_value_to_json response unwrapping
  - [ ] 2.1.2 Implement db_insert in rust/src/query.rs
    - Add function signature: `pub extern "C" fn db_insert(handle: *mut Database, resource: *const c_char, data: *const c_char) -> *mut c_char`
    - Wrap entire function in panic::catch_unwind
    - Validate null pointers before dereferencing
    - Convert resource and data from C strings to Rust strings
    - Generate SQL: `format!("INSERT INTO {} {}", resource_str, data_str)`
    - Execute via runtime.block_on(db.query(query_sql).await)
    - Use surreal_value_to_json for response unwrapping
    - Return JSON response pointer via Box::into_raw
    - Use set_last_error() for error propagation
  - [ ] 2.1.3 Export db_insert in rust/src/lib.rs
    - Add pub use query::db_insert
    - Verify symbol is exported in dylib
  - [ ] 2.1.4 Add comprehensive Rust doc comments
    - Document safety requirements
    - Document parameters and return value
    - Note that resource can be table or table:id format
    - Document error handling via set_last_error
  - [ ] 2.1.5 Build and verify Rust implementation
    - Compile Rust code: cargo build --release
    - Verify db_insert symbol is exported: nm -g target/release/libsurrealdartb.dylib | grep db_insert
    - Check for compilation warnings

**Acceptance Criteria:**
- db_insert function implemented in rust/src/query.rs
- Function follows existing FFI patterns exactly
- Uses panic::catch_unwind for safety
- Proper null pointer validation
- SQL generation matches implementation report
- Error handling via set_last_error
- Symbol exported in native library

---

#### Task Group 2.2: Dart FFI Bindings for Insert
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 2.1
**Estimated Effort:** 1-2 hours (Day 3 Late Morning)

- [ ] 2.2.0 Add Dart FFI bindings for insert
  - [ ] 2.2.1 Add NativeDbInsert typedef in lib/src/ffi/native_types.dart
    - Define: `typedef NativeDbInsert = Pointer<NativeResponse> Function(Pointer<NativeDatabase>, Pointer<Utf8>, Pointer<Utf8>);`
    - Follow pattern from existing typedefs
  - [ ] 2.2.2 Add dbInsert binding in lib/src/ffi/bindings.dart
    - Use @Native annotation
    - Symbol: 'db_insert'
    - Signature: `external Pointer<NativeResponse> dbInsert(Pointer<NativeDatabase> handle, Pointer<Utf8> resource, Pointer<Utf8> data);`
    - Include assetId matching other bindings
  - [ ] 2.2.3 Verify binding compiles
    - Run dart pub get
    - Check for Dart analyzer errors
    - Verify @Native annotation is correct

**Acceptance Criteria:**
- NativeDbInsert typedef added to native_types.dart
- dbInsert external function declared in bindings.dart
- Follows @Native annotation pattern consistently
- No Dart analyzer warnings or errors
- Ready for use in Database class methods

---

#### Task Group 2.3: Dart Wrapper Methods for Insert
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 2.2
**Estimated Effort:** 4-5 hours (Day 3 Afternoon)

- [ ] 2.3.0 Implement insertContent and insertRelation methods
  - [ ] 2.3.1 Review implementation report for Dart patterns
    - Study lines 768-930 from 2.1 implementation report
    - Note validation patterns (resource not empty, data not null)
    - Review try/finally cleanup pattern with malloc.free
    - Understand response unwrapping (handles [[{record}]] and [{record}])
  - [ ] 2.3.2 Implement insertContent() in lib/src/database.dart
    - Method signature: `Future<Map<String, dynamic>> insertContent(String resource, Map<String, dynamic> data)`
    - Add comprehensive dartdoc comment with example
    - Validate: _ensureNotClosed()
    - Validate: resource.isNotEmpty (throw ArgumentError if empty)
    - Validate: data not null (throw ArgumentError if null)
    - Wrap in Future(() {...}) for async behavior
    - JSON encode data: jsonEncode(data)
    - Convert to native strings: resourcePtr = resource.toNativeUtf8(), dataPtr = dataJson.toNativeUtf8()
    - Call FFI: responsePtr = bindings.dbInsert(_handle, resourcePtr, dataPtr)
    - Use try/finally to ensure malloc.free(resourcePtr) and malloc.free(dataPtr)
    - Process response: _processResponse(responsePtr)
    - Unwrap nested response: handle both [[{record}]] and [{record}] formats
    - Return first record as Map<String, dynamic>
  - [ ] 2.3.3 Implement insertRelation() in lib/src/database.dart
    - Method signature: `Future<Map<String, dynamic>> insertRelation(String table, Map<String, dynamic> data)`
    - Add comprehensive dartdoc comment with graph relationship example
    - Validate: _ensureNotClosed()
    - Validate: data['in'] exists (throw ArgumentError if missing)
    - Validate: data['out'] exists (throw ArgumentError if missing)
    - Convert RecordId objects to strings if needed:
      - if (data['in'] is RecordId) processedData['in'] = (data['in'] as RecordId).toString()
      - if (data['out'] is RecordId) processedData['out'] = (data['out'] as RecordId).toString()
    - Delegate to insertContent(table, processedData)
    - Return result from insertContent
  - [ ] 2.3.4 Add import for RecordId if needed
    - Ensure RecordId type is accessible
    - Add import statement if in separate file
  - [ ] 2.3.5 Verify implementation compiles
    - Run dart analyze
    - Fix any type errors or warnings
    - Ensure methods are properly formatted

**Acceptance Criteria:**
- insertContent() method implemented following report exactly
- insertRelation() method implemented with 'in'/'out' validation
- RecordId serialization works correctly
- try/finally cleanup pattern used for all pointers
- Response unwrapping handles nested arrays
- Comprehensive dartdoc comments with examples
- ArgumentError thrown for invalid inputs
- QueryException thrown for database errors

---

#### Task Group 2.4: Insert Operations Testing
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 2.3
**Estimated Effort:** 2-3 hours (Day 4 Morning)

- [ ] 2.4.0 Verify insert operations work correctly
  - [ ] 2.4.1 Review existing test file test/unit/insert_test.dart
    - Note that 8 tests already exist
    - Review test expectations
    - Understand the 2 known limitations
  - [ ] 2.4.2 Run insert_test.dart
    - Execute: dart test test/unit/insert_test.dart
    - Verify 6 of 8 tests pass (matching original implementation)
    - Identify which 2 tests fail (should match known limitations)
  - [ ] 2.4.3 Verify known limitations match expectations
    - Test "insertContent with specified record ID" should fail (INSERT syntax limitation)
    - Test "insertContent throws on null data" should fail (TypeError vs ArgumentError)
    - Document that these match implementation report known issues
  - [ ] 2.4.4 Verify passing tests cover critical functionality
    - "insertContent creates a standard record" - MUST pass
    - "insertRelation creates graph relationship" - MUST pass
    - "insertContent throws on empty table name" - MUST pass
    - "insertRelation throws on missing in field" - MUST pass
    - "insertRelation throws on missing out field" - MUST pass
    - "multiple insertContent operations in sequence" - MUST pass
  - [ ] 2.4.5 Run broader test suite to check for regressions
    - Run: dart test test/unit/
    - Verify no regressions in other unit tests
    - Ensure authentication tests still pass (8/8)
    - Ensure function execution tests still pass (8/8)
  - [ ] 2.4.6 Document test results
    - Create brief test results summary
    - Note 6/8 pass rate achieved
    - Confirm known limitations are acceptable
    - Document any unexpected behaviors

**Acceptance Criteria:**
- 6 of 8 insert tests passing (target met)
- Known limitations match implementation report
- Critical insert functionality verified working
- No regressions in other test suites
- RecordId serialization works in insertRelation
- Test results documented

---

### Phase 3: Upsert Operations Reimplementation (Days 5-6)

**DEPENDENCIES:** Phase 2 complete
**PRIORITY:** HIGH - Critical CRUD functionality

---

#### Task Group 3.1: Rust FFI Functions for Upsert
**Assigned Implementer:** api-engineer
**Dependencies:** Phase 2 Task Group 2.4
**Estimated Effort:** 5-6 hours (Day 5 Morning & Afternoon)

- [ ] 3.1.0 Implement three upsert FFI functions in Rust
  - [ ] 3.1.1 Review implementation report 2.2-upsert-operations-implementation.md
    - Study Rust implementation details (lines 1030-1476)
    - Note three separate functions approach
    - Review resource validation (must be table:id format)
    - Understand CONTENT, MERGE, and PATCH variants
  - [ ] 3.1.2 Implement db_upsert_content in rust/src/query.rs
    - Function signature: `pub extern "C" fn db_upsert_content(handle: *mut Database, resource: *const c_char, data: *const c_char) -> *mut c_char`
    - Wrap in panic::catch_unwind
    - Validate null pointers
    - Validate resource contains ':' (table:id format required)
    - Generate SQL: `UPSERT {resource} CONTENT {data}`
    - Execute via runtime.block_on(db.query().await)
    - Use surreal_value_to_json for response unwrapping
    - Return JSON pointer via Box::into_raw
    - Use set_last_error() for errors
  - [ ] 3.1.3 Implement db_upsert_merge in rust/src/query.rs
    - Same pattern as db_upsert_content
    - Generate SQL: `UPSERT {resource} MERGE {data}`
    - Field merging semantics (preserves unspecified fields)
  - [ ] 3.1.4 Implement db_upsert_patch in rust/src/query.rs
    - Same pattern as previous two
    - Validate patches array is non-empty
    - Generate SQL: `UPSERT {resource} PATCH {patches}`
    - Accept RFC 6902 JSON Patch format
  - [ ] 3.1.5 Export all three functions in rust/src/lib.rs
    - Add pub use for db_upsert_content, db_upsert_merge, db_upsert_patch
    - Verify symbols exported: nm -g target/release/libsurrealdartb.dylib | grep upsert
  - [ ] 3.1.6 Add comprehensive Rust doc comments
    - Document each function's specific semantics
    - Note resource format requirement (table:id)
    - Document CONTENT vs MERGE vs PATCH differences
    - Include safety requirements and error handling
  - [ ] 3.1.7 Build and verify Rust implementation
    - Compile: cargo build --release
    - Check for warnings
    - Verify all three symbols exported

**Acceptance Criteria:**
- Three Rust FFI functions implemented in rust/src/query.rs
- db_upsert_content: Full record replacement
- db_upsert_merge: Field merging with preservation
- db_upsert_patch: JSON Patch operations
- All use panic::catch_unwind for safety
- Resource validation (table:id format) in all three
- Proper error handling via set_last_error
- All symbols exported in native library

---

#### Task Group 3.2: Dart FFI Bindings for Upsert
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 3.1
**Estimated Effort:** 1-2 hours (Day 5 Late Afternoon)

- [ ] 3.2.0 Add Dart FFI bindings for upsert
  - [ ] 3.2.1 Add typedef in lib/src/ffi/native_types.dart
    - Define: `typedef NativeDbUpsert = Pointer<NativeResponse> Function(Pointer<NativeDatabase>, Pointer<Utf8>, Pointer<Utf8>);`
    - Can reuse for all three functions (same signature)
  - [ ] 3.2.2 Add three bindings in lib/src/ffi/bindings.dart
    - dbUpsertContent with symbol 'db_upsert_content'
    - dbUpsertMerge with symbol 'db_upsert_merge'
    - dbUpsertPatch with symbol 'db_upsert_patch'
    - All use @Native annotation with proper assetId
  - [ ] 3.2.3 Verify bindings compile
    - Run dart pub get
    - Check for analyzer errors
    - Verify all three @Native annotations correct

**Acceptance Criteria:**
- NativeDbUpsert typedef added
- Three external functions declared (dbUpsertContent, dbUpsertMerge, dbUpsertPatch)
- Follows @Native annotation pattern
- No Dart analyzer errors
- Ready for Database class methods

---

#### Task Group 3.3: Dart Wrapper Methods for Upsert
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 3.2
**Estimated Effort:** 4-5 hours (Day 6 Morning)

- [ ] 3.3.0 Implement three upsert methods in Database class
  - [ ] 3.3.1 Review implementation report Dart patterns
    - Study lines 504-736 from 2.2 implementation report
    - Note method variants approach rationale
    - Review PatchOp serialization: patches.map((p) => p.toJson()).toList()
    - Understand response unwrapping pattern
  - [ ] 3.3.2 Implement upsertContent() in lib/src/database.dart
    - Method signature: `Future<Map<String, dynamic>> upsertContent(String resource, Map<String, dynamic> data)`
    - Add dartdoc with CONTENT semantics explanation
    - Validate: _ensureNotClosed()
    - Validate: resource.contains(':') (must be table:id format)
    - Wrap in Future(() {...})
    - JSON encode data
    - Convert to native strings (resourcePtr, dataPtr)
    - Call bindings.dbUpsertContent(_handle, resourcePtr, dataPtr)
    - Use try/finally for malloc.free cleanup
    - Process and unwrap response
    - Return Map<String, dynamic>
  - [ ] 3.3.3 Implement upsertMerge() in lib/src/database.dart
    - Same pattern as upsertContent
    - Document MERGE semantics (field preservation)
    - Call bindings.dbUpsertMerge
  - [ ] 3.3.4 Implement upsertPatch() in lib/src/database.dart
    - Method signature: `Future<Map<String, dynamic>> upsertPatch(String resource, List<PatchOp> patches)`
    - Add dartdoc with PATCH semantics explanation
    - Validate: _ensureNotClosed()
    - Validate: resource.contains(':')
    - Validate: patches.isNotEmpty (throw ArgumentError if empty)
    - Serialize PatchOp list: `final patchesJson = jsonEncode(patches.map((p) => p.toJson()).toList())`
    - Convert to native strings (resourcePtr, patchesPtr)
    - Call bindings.dbUpsertPatch(_handle, resourcePtr, patchesPtr)
    - Use try/finally for cleanup
    - Process and unwrap response
  - [ ] 3.3.5 Ensure PatchOp import if needed
    - Verify PatchOp type is accessible
    - Add import if in separate file
  - [ ] 3.3.6 Verify implementation compiles
    - Run dart analyze
    - Fix any errors or warnings
    - Check formatting

**Acceptance Criteria:**
- Three methods implemented: upsertContent, upsertMerge, upsertPatch
- All follow implementation report patterns exactly
- Resource validation (contains ':') in all methods
- PatchOp serialization to RFC 6902 format works
- try/finally cleanup for all pointers
- Response unwrapping handles nested arrays
- Comprehensive dartdoc comments
- ArgumentError for invalid inputs
- QueryException for database errors

---

#### Task Group 3.4: Upsert Operations Testing
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 3.3
**Estimated Effort:** 2-3 hours (Day 6 Afternoon)

- [ ] 3.4.0 Verify upsert operations work correctly
  - [ ] 3.4.1 Review existing test file test/unit/upsert_operations_test.dart
    - Note that 8 tests already exist
    - Review test organization (content, merge, patch, errors)
    - Understand expected behavior for each variant
  - [ ] 3.4.2 Run upsert_operations_test.dart
    - Execute: dart test test/unit/upsert_operations_test.dart
    - Verify all 8 tests pass (matching original implementation)
    - No known limitations expected for upsert
  - [ ] 3.4.3 Verify each variant behaves correctly
    - CONTENT variant replaces entire record (fields removed)
    - MERGE variant preserves unspecified fields
    - PATCH variant applies operations correctly
    - Create-or-update semantics work for all variants
    - Error handling for table-only resource works
  - [ ] 3.4.4 Test PatchOp integration
    - Verify PatchOp.toJson() serializes to RFC 6902 format
    - Test replace, add, remove operations
    - Verify path validation throws ArgumentError
  - [ ] 3.4.5 Run broader test suite to check for regressions
    - Run: dart test test/unit/
    - Verify no regressions from upsert addition
    - Ensure insert tests still pass (6/8)
    - Ensure other CRUD tests still pass
  - [ ] 3.4.6 Document test results
    - Create test results summary
    - Note 8/8 pass rate achieved
    - Document all three variants working
    - Note no regressions detected

**Acceptance Criteria:**
- All 8 upsert tests passing (target: 8/8)
- CONTENT, MERGE, and PATCH variants all work correctly
- Create-or-update semantics verified
- PatchOp serialization works
- Resource format validation works
- No regressions in other tests
- Test results documented

---

### Phase 4: Type Casting Issues Resolution (Days 7-8)

**DEPENDENCIES:** Phases 1-3 complete
**PRIORITY:** MEDIUM - Test stability

---

#### Task Group 4.1: Parameter Test Type Casting Fixes
**Assigned Implementer:** api-engineer
**Dependencies:** Phase 3 Task Group 3.4
**Estimated Effort:** 3-4 hours (Day 7 Morning)

- [ ] 4.1.0 Fix parameter management test type issues
  - [ ] 4.1.1 Analyze failing parameter tests
    - Review test/parameter_management_test.dart
    - Identify tests 4.1.4 and 4.1.7 (failing tests)
    - Understand what type expectations are failing
    - Check if issue is in test assertions or response handling
  - [ ] 4.1.2 Review _processResponse() method
    - Check how query responses are unwrapped in lib/src/database.dart
    - Verify type handling for parameter values
    - Look for inconsistent type casting
    - Compare with working tests to identify pattern
  - [ ] 4.1.3 Fix response type handling if needed
    - Update _processResponse() if response structure handling is wrong
    - Ensure consistent type unwrapping across all operations
    - Fix any int vs double type issues
    - Fix any List vs Map type issues
  - [ ] 4.1.4 Fix test assertions if needed
    - If response types are correct, update test expectations
    - Use proper type matchers (equals vs same)
    - Handle dynamic typing correctly in assertions
  - [ ] 4.1.5 Run parameter_management_test.dart
    - Execute: dart test test/parameter_management_test.dart
    - Verify all 8 tests now pass
    - Ensure no regressions in previously passing tests
  - [ ] 4.1.6 Document fixes made
    - Note what was changed and why
    - Document correct type handling pattern
    - Update comments if response structure clarified

**Acceptance Criteria:**
- All 8 parameter management tests passing (target: 8/8)
- Type casting issues resolved
- _processResponse() handles types consistently
- Test assertions match actual response types
- No regressions in other tests
- Fixes documented

---

#### Task Group 4.2: Integration Test Type Casting Fixes
**Assigned Implementer:** api-engineer
**Dependencies:** Task Group 4.1
**Estimated Effort:** 4-5 hours (Day 7 Afternoon & Day 8 Morning)

- [ ] 4.2.0 Fix integration test type issues
  - [ ] 4.2.1 Analyze failing integration tests
    - Review test/integration/sdk_parity_integration_test.dart
    - Identify the 6 failing tests (out of 15 total)
    - Categorize failures by type of issue
    - Check if type casting or assertion problems
  - [ ] 4.2.2 Review _processQueryResponse() method
    - Check query result unwrapping in lib/src/database.dart
    - Verify type handling for different query result structures
    - Look for inconsistencies with other response processing
    - Compare with parameter test fixes for patterns
  - [ ] 4.2.3 Fix query response type handling
    - Update _processQueryResponse() if needed
    - Ensure consistent array/object unwrapping
    - Handle null values correctly
    - Fix nested structure type issues
  - [ ] 4.2.4 Fix assertion type compatibility
    - Update test expectations to match actual types
    - Use proper dynamic type handling in tests
    - Fix List<dynamic> vs List<Map> issues
    - Fix int vs double comparison issues
  - [ ] 4.2.5 Ensure library behavior consistency
    - Review all CRUD operations for type consistency
    - Verify create, update, delete, select, insert, upsert all return consistent types
    - Document expected response structure for each operation
  - [ ] 4.2.6 Run integration test suite
    - Execute: dart test test/integration/sdk_parity_integration_test.dart
    - Verify all 15 tests now pass
    - Ensure end-to-end workflows work correctly
  - [ ] 4.2.7 Document type handling patterns
    - Create documentation of response structures
    - Note type unwrapping patterns for future reference
    - Document any SurrealDB-specific type behaviors
    - Update code comments for clarity

**Acceptance Criteria:**
- All 15 integration tests passing (target: 15/15)
- Type casting issues across all operations resolved
- Consistent response structure handling
- Query results unwrapped correctly
- Test assertions match actual types
- Type handling patterns documented

---

#### Task Group 4.3: Comprehensive Type Consistency Verification
**Assigned Implementer:** testing-engineer
**Dependencies:** Task Group 4.2
**Estimated Effort:** 2-3 hours (Day 8 Afternoon)

- [ ] 4.3.0 Verify type consistency across entire SDK
  - [ ] 4.3.1 Run full test suite
    - Execute: dart test
    - Verify all in-scope tests pass
    - Count total passing vs total tests
    - Identify any remaining type-related failures
  - [ ] 4.3.2 Verify type consistency in CRUD operations
    - Test create() return type
    - Test update() return type
    - Test delete() return type
    - Test select() return type
    - Test insert() return types (content and relation)
    - Test upsert() return types (content, merge, patch)
    - Ensure all return Map<String, dynamic> or List<Map<String, dynamic>> consistently
  - [ ] 4.3.3 Verify parameter type preservation
    - Test set() with string, number, object, array
    - Verify query() retrieves parameters with correct types
    - Test type round-trip through FFI
  - [ ] 4.3.4 Test type handling in transactions
    - Verify transaction() preserves return types
    - Test rollback with different data types
    - Ensure transaction scope doesn't affect type handling
  - [ ] 4.3.5 Document any remaining type limitations
    - Note any unavoidable type conversions
    - Document int vs double behavior (Dart vs SurrealDB)
    - Document any Map vs dynamic issues
  - [ ] 4.3.6 Create type consistency verification report
    - Document all tested type scenarios
    - List any remaining type edge cases
    - Provide guidance for users on type handling
    - Update documentation if needed

**Acceptance Criteria:**
- Full test suite passes with no type-related failures
- All CRUD operations return consistent types
- Parameter types preserved through FFI
- Transaction operations don't affect types
- Type consistency verification report created
- Any limitations clearly documented

---

### Phase 5: Final Verification and Documentation (Days 9-10)

**DEPENDENCIES:** Phases 1-4 complete
**PRIORITY:** MEDIUM - Release preparation

---

#### Task Group 5.1: Comprehensive Test Suite Verification
**Assigned Implementer:** testing-engineer
**Dependencies:** Phase 4 Task Group 4.3
**Estimated Effort:** 4-5 hours (Day 9 Morning & Afternoon)

- [ ] 5.1.0 Run and verify complete test suite
  - [ ] 5.1.1 Run full test suite across all test files
    - Execute: dart test --reporter=expanded
    - Capture complete test output
    - Count total tests and passing tests
    - Identify any unexpected failures
  - [ ] 5.1.2 Verify target pass rates achieved
    - Transaction tests: 8/8 (was 7/8, fixed in Phase 1)
    - Insert tests: 6/8 (was 0/8 due to missing code, fixed in Phase 2)
    - Upsert tests: 8/8 (was 0/8 due to missing code, fixed in Phase 3)
    - Parameter tests: 8/8 (was 6/8, fixed in Phase 4)
    - Integration tests: 15/15 (was 9/15, fixed in Phase 4)
    - Authentication tests: 8/8 (should remain passing)
    - Function execution tests: 8/8 (should remain passing)
    - Core types tests: 15/15 (should remain passing)
  - [ ] 5.1.3 Verify no regressions in passing tests
    - Compare against baseline of 119 passing tests
    - Ensure all previously passing tests still pass
    - Note any unexpected changes
  - [ ] 5.1.4 Calculate overall test pass rate
    - Count total tests in scope
    - Calculate percentage passing
    - Verify 100% pass rate for in-scope features achieved
  - [ ] 5.1.5 Test with both mem:// and rocksdb:// backends
    - Run transaction tests specifically with rocksdb://
    - Verify rollback fix works on both backends
    - Document any backend-specific behaviors
  - [ ] 5.1.6 Create comprehensive test results report
    - List all test files with pass/fail counts
    - Document test pass rate improvements
    - Note any deferred test failures (out of scope features)
    - Provide evidence of success criteria met

**Acceptance Criteria:**
- All in-scope tests passing (target: 100%)
- Transaction rollback verified working (8/8)
- Insert operations verified working (6/8 with known limitations)
- Upsert operations verified working (8/8)
- Parameter tests verified working (8/8)
- Integration tests verified working (15/15)
- No regressions detected (119 baseline tests still pass)
- Test results report created

---

#### Task Group 5.2: Memory Leak and Stability Testing
**Assigned Implementer:** testing-engineer
**Dependencies:** Task Group 5.1
**Estimated Effort:** 3-4 hours (Day 10 Morning)

- [ ] 5.2.0 Verify no memory leaks introduced
  - [ ] 5.2.1 Review FFI memory management patterns
    - Check all malloc.free() calls in try/finally blocks
    - Verify all pointers are cleaned up
    - Review Rust Box::into_raw/Box::from_raw usage
    - Ensure no leaked pointers in error paths
  - [ ] 5.2.2 Run stress tests for insert operations
    - Create test that inserts 1000 records sequentially
    - Monitor memory usage during execution
    - Verify memory returns to baseline after test
  - [ ] 5.2.3 Run stress tests for upsert operations
    - Create test that upserts same record 1000 times
    - Test all three variants (content, merge, patch)
    - Monitor memory usage
  - [ ] 5.2.4 Run stress tests for transactions
    - Create test with 100 transactions (commit and rollback)
    - Verify no memory accumulation
    - Check for proper cleanup on rollback
  - [ ] 5.2.5 Test error path cleanup
    - Trigger intentional errors in each operation
    - Verify malloc.free() still executes
    - Check for orphaned resources
  - [ ] 5.2.6 Document memory testing results
    - Note memory usage patterns observed
    - Confirm no leaks detected
    - Document any resource cleanup improvements made

**Acceptance Criteria:**
- No memory leaks detected in insert operations
- No memory leaks detected in upsert operations
- No memory leaks detected in transaction operations
- Error paths properly clean up resources
- Stress tests complete without memory accumulation
- Memory testing results documented

---

#### Task Group 5.3: Documentation Updates
**Assigned Implementer:** api-engineer
**Dependencies:** Task Groups 5.1 and 5.2
**Estimated Effort:** 3-4 hours (Day 10 Afternoon)

- [ ] 5.3.0 Update documentation and implementation reports
  - [ ] 5.3.1 Create Phase 1 implementation report
    - Document transaction rollback investigation
    - Explain root cause identified
    - Describe fix implemented
    - Include before/after test results
    - Note any backend-specific behaviors
  - [ ] 5.3.2 Verify Phase 2 and 3 match implementation reports
    - Confirm insert implementation matches 2.1 report
    - Confirm upsert implementation matches 2.2 report
    - Document any deviations from original implementations
    - Update reports if implementation differs
  - [ ] 5.3.3 Document type casting fixes
    - Create summary of type issues resolved
    - Document response structure handling patterns
    - Provide guidance for future type consistency
  - [ ] 5.3.4 Update spec.md success criteria
    - Mark all requirements as complete
    - Update test pass rates to achieved values
    - Note any deferred features remain out of scope
  - [ ] 5.3.5 Update main tasks.md status
    - Mark all task groups complete
    - Update test pass counts
    - Document completion of all 5 phases
  - [ ] 5.3.6 Create completion summary report
    - List all features reimplemented
    - Document all bugs fixed
    - Provide final test pass rate statistics
    - Note timeline and effort actual vs estimated
    - Include recommendations for future work

**Acceptance Criteria:**
- Phase 1 implementation report created
- Phase 2 and 3 implementations verified against reports
- Type casting fixes documented
- spec.md updated with completion status
- tasks.md marked complete
- Completion summary report created
- All documentation clear and accurate

---

## Implementation Notes

### Sequential Execution Philosophy

This spec REQUIRES sequential execution. Each phase must complete before the next begins:
1. **Phase 1 is BLOCKING** - Transaction rollback bug is a data integrity issue that must be fixed first
2. **Phase 2 and 3 can proceed** - Insert and upsert reimplementation after Phase 1
3. **Phase 4 depends on 1-3** - Type casting fixes require all operations implemented first
4. **Phase 5 is final** - Comprehensive verification after all fixes complete

**Do NOT start Phase 2 until Phase 1 is 100% complete with all tests passing.**

### Test Philosophy for This Spec

Unlike the original SDK parity spec, this is a **BUG FIX** spec, so testing approach differs:

1. **No new test writing** - Tests already exist from previous implementation
2. **Focus on test pass rates** - Goal is to get existing tests passing
3. **Verify against implementation reports** - Ensure code matches previous working implementations exactly
4. **Investigation required** - Phase 1 requires debugging, not just implementation

### FFI Pattern Consistency

All reimplemented code MUST follow existing FFI patterns exactly:
- Rust: panic::catch_unwind, set_last_error, Box::into_raw/from_raw
- Dart: Future(() {...}), try/finally cleanup, _processResponse()
- No deviations from established patterns

### Error Handling Pattern

All methods must:
1. Validate inputs before FFI calls
2. Use try/finally for all pointer cleanup
3. Throw appropriate exceptions (ArgumentError for validation, QueryException for DB errors)
4. Preserve error context from native layer

### Memory Management

Critical: This spec fixes previously working code that had proper memory management. Do NOT introduce memory leaks:
- All malloc.free() calls in finally blocks
- All Box::into_raw has corresponding Box::from_raw
- All pointers cleaned up even on error paths

---

## Priority Levels

1. **CRITICAL (Days 1-2)** - Transaction Rollback Bug Fix
   - Task Groups 1.1, 1.2, 1.3, 1.4

2. **HIGH (Days 3-4)** - Insert Operations Reimplementation
   - Task Groups 2.1, 2.2, 2.3, 2.4

3. **HIGH (Days 5-6)** - Upsert Operations Reimplementation
   - Task Groups 3.1, 3.2, 3.3, 3.4

4. **MEDIUM (Days 7-8)** - Type Casting Fixes
   - Task Groups 4.1, 4.2, 4.3

5. **MEDIUM (Days 9-10)** - Final Verification
   - Task Groups 5.1, 5.2, 5.3

---

## Task Group Dependencies

```
Phase 1: Transaction Rollback Bug Fix (BLOCKING)
├── 1.1 Add Instrumentation (NO DEPS)
├── 1.2 Backend Testing (depends on 1.1)
├── 1.3 Root Cause Analysis (depends on 1.2)
└── 1.4 Implement Fix (depends on 1.3)

Phase 2: Insert Operations (depends on Phase 1 complete)
├── 2.1 Rust FFI (depends on 1.4)
├── 2.2 Dart Bindings (depends on 2.1)
├── 2.3 Dart Methods (depends on 2.2)
└── 2.4 Testing (depends on 2.3)

Phase 3: Upsert Operations (depends on Phase 2 complete)
├── 3.1 Rust FFI (depends on 2.4)
├── 3.2 Dart Bindings (depends on 3.1)
├── 3.3 Dart Methods (depends on 3.2)
└── 3.4 Testing (depends on 3.3)

Phase 4: Type Casting Fixes (depends on Phase 3 complete)
├── 4.1 Parameter Tests (depends on 3.4)
├── 4.2 Integration Tests (depends on 4.1)
└── 4.3 Type Consistency (depends on 4.2)

Phase 5: Final Verification (depends on Phase 4 complete)
├── 5.1 Test Suite Verification (depends on 4.3)
├── 5.2 Memory Testing (depends on 5.1)
└── 5.3 Documentation (depends on 5.1, 5.2)
```

---

## Completion Tracking

### Phase Status
- [ ] **Phase 1**: Transaction Rollback Bug Fix (CRITICAL - BLOCKING)
  - Task Group 1.1: Add Instrumentation
  - Task Group 1.2: Backend Testing
  - Task Group 1.3: Root Cause Analysis
  - Task Group 1.4: Implement Fix

- [ ] **Phase 2**: Insert Operations Reimplementation
  - Task Group 2.1: Rust FFI Function
  - Task Group 2.2: Dart Bindings
  - Task Group 2.3: Dart Methods
  - Task Group 2.4: Testing

- [ ] **Phase 3**: Upsert Operations Reimplementation
  - Task Group 3.1: Rust FFI Functions
  - Task Group 3.2: Dart Bindings
  - Task Group 3.3: Dart Methods
  - Task Group 3.4: Testing

- [ ] **Phase 4**: Type Casting Fixes
  - Task Group 4.1: Parameter Tests
  - Task Group 4.2: Integration Tests
  - Task Group 4.3: Type Consistency

- [ ] **Phase 5**: Final Verification
  - Task Group 5.1: Test Suite Verification
  - Task Group 5.2: Memory Testing
  - Task Group 5.3: Documentation

### Success Metrics Tracking

**Starting Point (Before This Spec):**
- Total Tests: 139
- Passing: 119 (86%)
- Failing: 20 (14%)
- Transaction tests: 7/8 (CRITICAL BUG - rollback broken)
- Insert tests: 0/8 (cannot load - methods missing)
- Upsert tests: 0/8 (cannot load - methods missing)
- Parameter tests: 6/8 (type casting issues)
- Integration tests: 9/15 (type casting issues)

**Target (After This Spec):**
- Transaction tests: 8/8 (100%)
- Insert tests: 6/8 (75% - known limitations acceptable)
- Upsert tests: 8/8 (100%)
- Parameter tests: 8/8 (100%)
- Integration tests: 15/15 (100%)
- Overall in-scope pass rate: 100%

**Overall Progress:**
- [ ] Phase 1 Complete (Transaction bug fixed)
- [ ] Phase 2 Complete (Insert reimplemented)
- [ ] Phase 3 Complete (Upsert reimplemented)
- [ ] Phase 4 Complete (Type issues fixed)
- [ ] Phase 5 Complete (Verification done)

---

## Critical Reminders

### For Phase 1 (Transaction Bug)

1. **Investigation First** - Don't jump to solutions, instrument and analyze
2. **Test Both Backends** - mem:// and rocksdb:// may behave differently
3. **Document Root Cause** - Future maintainers need to understand the fix
4. **Data Integrity** - This is the most critical bug, take time to fix it right

### For Phases 2 and 3 (Insert/Upsert)

1. **Follow Reports Exactly** - Implementation reports provide complete specification
2. **No Creativity** - Reimplement existing working code, don't improve or change
3. **Known Limitations OK** - Insert 6/8 pass rate is acceptable per original spec
4. **Test Before Proceeding** - Verify tests pass before moving to next phase

### For Phase 4 (Type Casting)

1. **Response Structure** - Understand [[{record}]] vs [{record}] unwrapping
2. **Consistency** - All operations should handle types the same way
3. **Test Assertions** - Fix tests if response types are actually correct
4. **Document Patterns** - Help future implementers understand type handling

### For Phase 5 (Verification)

1. **No New Features** - This is verification only, no additional implementation
2. **100% Target** - All in-scope tests must pass
3. **No Regressions** - Verify 119 baseline tests still pass
4. **Memory Safety** - Stress test to ensure no leaks introduced

---

## Timeline Summary

**Total Duration:** 6-10 days

| Phase | Days | Effort | Implementer |
|-------|------|--------|-------------|
| Phase 1: Transaction Bug | 1-2 | 16-24 hours | api-engineer |
| Phase 2: Insert Ops | 3-4 | 10-14 hours | api-engineer |
| Phase 3: Upsert Ops | 5-6 | 12-16 hours | api-engineer |
| Phase 4: Type Fixes | 7-8 | 9-12 hours | api-engineer |
| Phase 5: Verification | 9-10 | 10-13 hours | testing-engineer |

**Buffer Time:** 2-4 days included for investigation and unforeseen issues

---

## Reference Materials

**Implementation Reports to Reference:**
- `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-21-sdk-parity/implementation/2.1-insert-operations-implementation.md`
- `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-21-sdk-parity/implementation/2.2-upsert-operations-implementation.md`
- `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-21-sdk-parity/implementation/7.1-transaction-support-implementation.md`

**Test Files to Verify:**
- `test/transaction_test.dart` (8 tests)
- `test/unit/insert_test.dart` (8 tests)
- `test/unit/upsert_operations_test.dart` (8 tests)
- `test/parameter_management_test.dart` (8 tests)
- `test/integration/sdk_parity_integration_test.dart` (15 tests)

**Code Files to Modify:**
- `rust/src/query.rs` (insert and upsert FFI functions)
- `rust/src/database.rs` (transaction rollback fix)
- `lib/src/ffi/bindings.dart` (FFI bindings)
- `lib/src/database.dart` (Dart wrapper methods)
