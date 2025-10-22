# Spec Requirements: SDK Parity Issues Resolution

## Initial Description
"Resolve critical issues and complete remaining features from the SurrealDB Dart SDK Parity implementation. This includes:

1. **CRITICAL - Fix Transaction Rollback Bug**: Transaction rollback is not properly discarding changes (data integrity issue)

2. **HIGH - Resolve Insert/Upsert Implementation Gap**: Tests exist but methods (insertContent, insertRelation, upsertContent, upsertMerge, upsertPatch) are missing from Database class

3. **HIGH - Clarify Export/Import Status**: Implementation reports claim completion but methods appear to be missing

4. **MEDIUM - Fix Type Casting Issues**: Parameter and integration tests have type mismatch issues (6/8 and 9/15 passing)

5. **MEDIUM - Complete Live Queries**: Currently 30% complete with design done, needs full implementation (7-10 days estimated)

**Context from Previous Spec:**

The previous spec (2025-10-21-sdk-parity) achieved:
- Core type system (RecordId, Datetime, SurrealDuration, PatchOp) - 100% complete
- Authentication system - 100% complete
- Function execution - 100% complete
- Basic CRUD operations - Working
- Transactions - 88% working (rollback bug)
- Parameters - 75% working (type issues)
- Insert/Upsert - Implementation unclear
- Export/Import - Implementation unclear
- Live Queries - 30% complete

**Overall Status:** 40% production ready, 86% test pass rate (119/139 tests passing)

**Goal:** Address critical issues and complete remaining features to achieve 100% production readiness."

## Requirements Discussion

### First Round Questions

**User's Approach Decisions:**

1. **Priority Approach:** Sequential - fix transaction rollback bug first, then move to other issues

2. **Insert/Upsert Gap:** Reimplement based on previous spec - one of the agents accidentally rolled back the implementation during development

3. **Export/Import:** Defer for the moment, but make a note of it being deferred for future reference

4. **Live Queries:** Defer for the moment, but make a note of it being deferred for future reference

5. **Type Casting Strategy:** Shoot for a consistent spec - library should feel uniform

6. **Testing Target:** 100% passing tests if possible, but only for tests specifically related to what we are fixing in this run. Deferred options can be ignored for the time being.

7. **Integration Test Behavior:** Follow documented behavior for the time being

8. **FFI Patterns:** The patterns we have are ideal - stick with what works

9. **Rollback Bug Investigation:** Will need to dig in and figure it out through experimentation. Use tracing and logging to find the issue.

### Existing Code to Reference

**Similar Features Identified:**

Previous implementation reports from: `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-21-sdk-parity/implementation/`

**Insert Operations (Task 2.1):**
- Implementation report: `2.1-insert-operations-implementation.md`
- Rust FFI function: `db_insert` in `rust/src/query.rs`
- Dart methods: `insertContent()` and `insertRelation()` in `lib/src/database.dart`
- Test file: `test/unit/insert_test.dart` (8 tests, 6 passing before rollback)
- FFI binding: `dbInsert` in `lib/src/ffi/bindings.dart`
- Method variants approach chosen over builder pattern
- RecordId serialization support for graph relationships

**Upsert Operations (Task 2.2):**
- Implementation report: `2.2-upsert-operations-implementation.md`
- Rust FFI functions: `db_upsert_content`, `db_upsert_merge`, `db_upsert_patch` in `rust/src/query.rs`
- Dart methods: `upsertContent()`, `upsertMerge()`, `upsertPatch()` in `lib/src/database.dart`
- Test file: `test/unit/upsert_operations_test.dart` (8 tests, all passing before rollback)
- FFI bindings: `dbUpsertContent`, `dbUpsertMerge`, `dbUpsertPatch` in `lib/src/ffi/bindings.dart`
- Three separate FFI functions for clarity and type safety
- PatchOp integration for patch variant

**Transaction Support (Task 7.1):**
- Implementation report: `7.1-transaction-support-implementation.md`
- Rust FFI functions: `db_begin`, `db_commit`, `db_rollback` in `rust/src/database.rs`
- Dart method: `transaction<T>()` in `lib/src/database.dart`
- Test file: `test/transaction_test.dart` (8 tests, 7 passing - 1 failure due to rollback bug)
- FFI bindings: `dbBegin`, `dbCommit`, `dbRollback` in `lib/src/ffi/bindings.dart`
- Known issue: Rollback executes without error but changes are not actually discarded

**Testing Infrastructure (Task 8.1):**
- Implementation report: `8.1-comprehensive-testing-implementation.md`
- Integration tests: `test/integration/sdk_parity_integration_test.dart` (15 tests, 9 passing)
- Test coverage analysis of 76 existing tests
- Identified gaps in error recovery, storage backend testing, and feature combinations

### Follow-up Questions

None required - user provided clear direction for sequential implementation and investigation approach.

## Visual Assets

### Files Provided:
No visual assets provided.

### Visual Insights:
Not applicable - this is a bug fix and reimplementation spec.

## Requirements Summary

### Functional Requirements

**PRIORITY 1: Fix Transaction Rollback Bug (CRITICAL)**
- Investigate why `CANCEL TRANSACTION` executes without error but doesn't discard changes
- Use tracing and logging to identify root cause
- Possible causes to investigate:
  - SurrealDB mem:// storage backend transaction limitations
  - CANCEL TRANSACTION syntax or parameter requirements
  - Auto-commit behavior that needs to be disabled
  - Transaction isolation level configuration
- Test with both mem:// and rocksdb:// backends to isolate issue
- Fix implementation in `rust/src/database.rs` (db_rollback function)
- Verify all 8 transaction tests pass after fix
- **Success Criteria:** Transaction rollback test passes - changes made before exception are properly discarded

**PRIORITY 2: Reimplement Insert Operations**
Based on `2.1-insert-operations-implementation.md`:
- Rust FFI function `db_insert` in `rust/src/query.rs`
  - Uses `panic::catch_unwind` for panic safety
  - Generates SurrealQL: `INSERT INTO {resource} {data}`
  - Returns JSON response with inserted record
- Dart method `insertContent(String resource, Map<String, dynamic> data)` in `lib/src/database.dart`
  - Validates resource is not empty
  - Validates data is not null
  - JSON encodes data for FFI transport
  - Unwraps nested response structure
- Dart method `insertRelation(String table, Map<String, dynamic> data)` in `lib/src/database.dart`
  - Validates 'in' and 'out' fields are present
  - Converts RecordId objects to strings if needed
  - Delegates to insertContent() after validation
- FFI binding `dbInsert` in `lib/src/ffi/bindings.dart`
- Test file: `test/unit/insert_test.dart` (8 tests)
- **Success Criteria:** 6 of 8 tests passing (same as original implementation)
- **Known limitations to preserve:**
  - INSERT with specific record ID not supported (use create() instead)
  - Null data validation throws TypeError instead of ArgumentError

**PRIORITY 3: Reimplement Upsert Operations**
Based on `2.2-upsert-operations-implementation.md`:
- Rust FFI functions in `rust/src/query.rs`:
  - `db_upsert_content`: Executes `UPSERT {resource} CONTENT {data}`
  - `db_upsert_merge`: Executes `UPSERT {resource} MERGE {data}`
  - `db_upsert_patch`: Executes `UPSERT {resource} PATCH {patches}`
- Dart methods in `lib/src/database.dart`:
  - `upsertContent(String resource, Map<String, dynamic> data)`
  - `upsertMerge(String resource, Map<String, dynamic> data)`
  - `upsertPatch(String resource, List<PatchOp> patches)`
- FFI bindings in `lib/src/ffi/bindings.dart`:
  - `dbUpsertContent`, `dbUpsertMerge`, `dbUpsertPatch`
- Test file: `test/unit/upsert_operations_test.dart` (8 tests)
- **Success Criteria:** All 8 tests passing (as in original implementation)
- **Implementation notes:**
  - Validates resource is in table:id format
  - Validates patches list is non-empty for patch variant
  - PatchOp serialization to RFC 6902 JSON Patch format

**PRIORITY 4: Fix Type Casting Issues**
- Parameter management tests: 2 of 8 tests failing due to type casting errors
- Integration tests: 6 of 15 tests failing due to type issues
- Investigate query response structure handling
- Ensure consistent type handling across all CRUD operations
- Focus on:
  - Query result unwrapping consistency
  - Parameter value type preservation
  - Response structure documentation
- **Success Criteria:** All in-scope tests passing (parameter tests: 8/8, relevant integration tests)

### Reusability Opportunities

**Existing Patterns to Follow:**
- FFI function pattern from `rust/src/query.rs`:
  - `panic::catch_unwind` wrapper
  - Null pointer validation
  - `set_last_error()` for error propagation
  - `Box::into_raw() / Box::from_raw()` memory management
  - `runtime.block_on()` for async operations
  - `surreal_value_to_json()` for response unwrapping

- Dart wrapper pattern from `lib/src/database.dart`:
  - `_ensureNotClosed()` validation
  - `Future(() {...})` async wrapping
  - `try/finally` with `malloc.free()` for pointer cleanup
  - `_processResponse()` for response handling
  - `_getLastErrorString()` for error context

- Test pattern from existing test files:
  - Memory storage for fast execution
  - `setUp()` / `tearDown()` lifecycle
  - Descriptive test names
  - Focused tests (not exhaustive)
  - Error case coverage

**Components That Exist:**
- RecordId type with serialization
- PatchOp type with JSON serialization
- Existing CRUD operations (create, update, delete, select, get)
- Authentication methods
- Parameter management
- Function execution
- Transaction infrastructure (needs bug fix)

### Scope Boundaries

**In Scope:**
1. Fix transaction rollback bug using tracing/logging investigation
2. Reimplement insert operations (insertContent, insertRelation)
3. Reimplement upsert operations (upsertContent, upsertMerge, upsertPatch)
4. Fix type casting issues in parameter and integration tests
5. Verify 100% test pass rate for in-scope features
6. Test with both mem:// and rocksdb:// storage backends where relevant
7. Preserve existing FFI patterns and coding standards
8. Document rollback bug root cause and fix

**Out of Scope:**
1. Export/Import implementation (deferred for future)
2. Live Queries implementation (deferred for future)
3. New features beyond fixing existing issues
4. Comprehensive edge case testing (focused testing only)
5. Performance optimization
6. Documentation updates (beyond code comments)
7. Tests for deferred features

**Explicitly Deferred (with notes for future):**
- **Export/Import**: Implementation status unclear from previous spec, needs investigation in future iteration
- **Live Queries**: 30% complete (design done), needs 7-10 days for full implementation in future iteration

### Technical Considerations

**Transaction Rollback Investigation Plan:**
1. Add Rust-level logging to `db_rollback` function
2. Add SurrealDB query execution tracing
3. Test transaction behavior with mem:// backend
4. Test transaction behavior with rocksdb:// backend
5. Review SurrealDB documentation for CANCEL TRANSACTION requirements
6. Check if transaction state is properly maintained across FFI boundary
7. Verify runtime.block_on() doesn't interfere with transaction lifecycle
8. Test nested operations within transactions
9. Compare behavior with SurrealDB Rust SDK examples

**Type Consistency Requirements:**
- Uniform response structure handling across all CRUD operations
- Consistent error types for validation failures
- Clear documentation of response unwrapping logic
- Preserve type information through FFI boundary
- Use existing type conversion patterns (RecordId, Datetime, SurrealDuration)

**Integration Points:**
- Rust FFI functions in `rust/src/query.rs` and `rust/src/database.rs`
- Dart FFI bindings in `lib/src/ffi/bindings.dart`
- Dart methods in `lib/src/database.dart`
- Test files in `test/unit/` and `test/integration/`
- Build system via native assets (no changes needed)

**Storage Backend Requirements:**
- All operations must work with mem:// backend
- Transaction fix must be tested with rocksdb:// backend
- Maintain existing storage backend abstraction

**Memory Management:**
- Follow existing patterns: `malloc.free()` in try/finally blocks
- Use `Box::into_raw() / Box::from_raw()` in Rust
- NativeFinalizer for automatic cleanup (where already used)
- No memory leaks in normal or error paths

**Error Handling:**
- Preserve existing exception hierarchy
- Use QueryException for SQL errors
- Use ArgumentError for validation failures
- Use TransactionException for transaction errors
- Include clear, actionable error messages
- Maintain error context through `_getLastErrorString()`

### Implementation Sequence

**Phase 1: Transaction Rollback Bug Fix**
1. Set up tracing/logging infrastructure
2. Investigate rollback behavior with mem:// backend
3. Test with rocksdb:// backend
4. Identify root cause
5. Implement fix in `rust/src/database.rs`
6. Verify all 8 transaction tests pass
7. Document findings and fix

**Phase 2: Insert Operations Reimplementation**
1. Review `2.1-insert-operations-implementation.md` thoroughly
2. Implement `db_insert` in `rust/src/query.rs`
3. Add FFI binding in `lib/src/ffi/bindings.dart`
4. Implement `insertContent()` in `lib/src/database.dart`
5. Implement `insertRelation()` in `lib/src/database.dart`
6. Run `test/unit/insert_test.dart` - target 6/8 passing
7. Document any deviations from original implementation

**Phase 3: Upsert Operations Reimplementation**
1. Review `2.2-upsert-operations-implementation.md` thoroughly
2. Implement three Rust FFI functions in `rust/src/query.rs`
3. Add three FFI bindings in `lib/src/ffi/bindings.dart`
4. Implement three Dart methods in `lib/src/database.dart`
5. Run `test/unit/upsert_operations_test.dart` - target 8/8 passing
6. Document any deviations from original implementation

**Phase 4: Type Casting Issues**
1. Analyze failing parameter tests
2. Analyze failing integration tests
3. Identify common type handling issues
4. Implement fixes for response structure handling
5. Verify all in-scope tests pass
6. Document type handling patterns

**Phase 5: Final Verification**
1. Run all SDK parity tests
2. Verify test pass rate for in-scope features
3. Test with both mem:// and rocksdb:// backends
4. Verify no memory leaks
5. Confirm all requirements met

### Testing Approach

**Test Execution Strategy:**
- Run only tests specifically related to features being fixed
- Ignore tests for deferred features (export/import, live queries)
- Target 100% pass rate for in-scope tests:
  - Transaction tests: 8/8 passing (currently 7/8)
  - Insert tests: 6/8 passing (currently 0/8 due to missing implementation)
  - Upsert tests: 8/8 passing (currently 0/8 due to missing implementation)
  - Parameter tests: 8/8 passing (currently 6/8)
  - Relevant integration tests: all passing

**Test Files In Scope:**
- `test/transaction_test.dart` (8 tests)
- `test/unit/insert_test.dart` (8 tests)
- `test/unit/upsert_operations_test.dart` (8 tests)
- `test/parameter_management_test.dart` (8 tests)
- `test/integration/sdk_parity_integration_test.dart` (15 tests - fix relevant ones)

**Test Files Out of Scope:**
- Export/import tests (deferred)
- Live query tests (deferred)
- Tests not related to bugs being fixed

**Storage Backend Testing:**
- Transaction fix: Test with both mem:// and rocksdb://
- Insert/upsert: Test with mem:// (as in original implementation)
- Integration tests: Use existing backend configurations

### Standards Compliance

**Coding Style:**
- Follow existing Dart formatting conventions
- Use descriptive variable names
- Add comprehensive dartdoc comments
- Maintain consistent indentation
- Follow method naming patterns in codebase

**FFI Patterns:**
- Use `@Native` annotations with symbol and assetId
- Wrap all FFI calls in `Future(() {...})`
- Implement panic safety with `std::panic::catch_unwind`
- Use JSON serialization for FFI data bridge
- Proper CString handling in Rust layer

**Error Handling:**
- Try/finally blocks for FFI resource cleanup
- Appropriate exception types
- Preserve error context from native layer
- Clear, actionable error messages
- Panic safety prevents crashes

**Async Patterns:**
- Return Future for all async methods
- Use `runtime.block_on()` in Rust FFI layer
- Wrap FFI calls in Future constructor
- Maintain proper async/await semantics

**Validation:**
- Validate inputs before FFI calls
- Clear error messages for validation failures
- Use ArgumentError for invalid arguments
- Database state validation with `_ensureNotClosed()`

**Testing Standards:**
- Focused tests (2-8 per feature)
- Descriptive test names
- Proper setUp/tearDown lifecycle
- Independent tests
- Error path coverage

### Success Metrics

**Critical Success Criteria:**
1. Transaction rollback bug fixed - all 8 transaction tests passing
2. Insert operations reimplemented - 6 of 8 tests passing (matches original)
3. Upsert operations reimplemented - all 8 tests passing (matches original)
4. Type casting issues fixed - all in-scope tests passing
5. No new memory leaks introduced
6. All existing passing tests still pass
7. Implementation follows existing FFI patterns
8. Code complies with all standards

**Test Pass Rate Targets:**
- Transaction tests: 100% (8/8)
- Insert tests: 75% (6/8) - matches original implementation
- Upsert tests: 100% (8/8)
- Parameter tests: 100% (8/8)
- Integration tests: All in-scope tests passing

**Documentation Requirements:**
- Rollback bug root cause documented
- Fix approach documented
- Known limitations preserved in comments
- Deferred features noted for future work

## Notes

**Context from User:**
- Previous implementations were completed successfully but accidentally rolled back during development
- Implementation reports provide complete specifications to follow
- User wants sequential approach: fix rollback bug first, then reimplementations
- Focus on getting tests passing, not comprehensive edge case coverage
- Stick with proven FFI patterns that already work
- Investigation approach for rollback bug: experimentation with tracing/logging

**Key Implementation Reports to Reference:**
1. `2.1-insert-operations-implementation.md` - Complete insert operations spec
2. `2.2-upsert-operations-implementation.md` - Complete upsert operations spec
3. `7.1-transaction-support-implementation.md` - Transaction implementation with known rollback bug
4. `8.1-comprehensive-testing-implementation.md` - Test coverage analysis

**Deferred for Future Iteration:**
- Export/Import: Status unclear, needs investigation
- Live Queries: 30% complete (design done), needs 7-10 days for full implementation

**Technical Notes:**
- Transaction rollback issue may be storage backend specific (mem:// vs rocksdb://)
- Insert operations use method variants pattern (not builder pattern)
- Upsert operations use three separate FFI functions for clarity
- Type casting issues appear in query response handling and assertions
- All operations follow consistent FFI patterns for maintainability
