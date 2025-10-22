# Specification: SDK Parity Issues Resolution

## Goal

Fix critical transaction rollback bug and reimplement accidentally rolled back insert/upsert operations to achieve reliable production-ready SDK functionality with 100% test pass rate for in-scope features.

## User Stories

- As a developer using surrealdartb, I need transaction rollback to actually discard changes so that I can ensure data integrity when exceptions occur during multi-step operations
- As a developer, I need insert operations (insertContent, insertRelation) to work so that I can create standard records and graph relationships efficiently
- As a developer, I need upsert operations (upsertContent, upsertMerge, upsertPatch) to work so that I can handle create-or-update scenarios with different merge strategies
- As a developer, I need consistent type handling across all SDK operations so that the library feels uniform and predictable
- As a developer, I need all documented features to work as expected so that I can rely on the SDK in production

## Core Requirements

### Functional Requirements

**PRIORITY 1 - Fix Transaction Rollback Bug (CRITICAL - Days 1-2):**
- Investigate why CANCEL TRANSACTION executes without error but doesn't discard changes
- Use tracing and logging to identify root cause in transaction lifecycle
- Test with both mem:// and rocksdb:// storage backends to isolate backend-specific behavior
- Potential causes to investigate:
  - SurrealDB mem:// storage backend transaction limitations
  - CANCEL TRANSACTION syntax or parameter requirements in embedded mode
  - Auto-commit behavior that may need explicit disabling
  - Transaction isolation level configuration issues
  - Runtime.block_on() interference with transaction state
- Fix implementation in rust/src/database.rs (db_rollback function)
- Verify all 8 transaction tests pass including the failing "rollback discards changes" test
- Document root cause and fix approach for future reference

**PRIORITY 2 - Reimplement Insert Operations (Days 3-4):**
- Implement db_insert FFI function in rust/src/query.rs based on 2.1 implementation report
  - Use panic::catch_unwind for panic safety
  - Generate SurrealQL: INSERT INTO {resource} {data}
  - Use surreal_value_to_json for response unwrapping
  - Return JSON response with inserted record
- Add dbInsert FFI binding in lib/src/ffi/bindings.dart
- Implement insertContent(String resource, Map<String, dynamic> data) in lib/src/database.dart
  - Validate resource not empty
  - Validate data not null
  - JSON encode data for FFI transport
  - Use try/finally for pointer cleanup
  - Unwrap nested response structure
- Implement insertRelation(String table, Map<String, dynamic> data) in lib/src/database.dart
  - Validate 'in' and 'out' fields present
  - Convert RecordId objects to strings if needed
  - Delegate to insertContent() after validation
- Target: 6 of 8 tests passing (matching original implementation)
- Known limitations to preserve:
  - INSERT with specific record ID not supported (use create() instead)
  - Null data validation throws TypeError instead of ArgumentError

**PRIORITY 3 - Reimplement Upsert Operations (Days 5-6):**
- Implement three Rust FFI functions in rust/src/query.rs based on 2.2 implementation report:
  - db_upsert_content: Executes UPSERT {resource} CONTENT {data}
  - db_upsert_merge: Executes UPSERT {resource} MERGE {data}
  - db_upsert_patch: Executes UPSERT {resource} PATCH {patches}
  - All validate resource is table:id format
  - Patch variant validates patches array non-empty
- Add three FFI bindings in lib/src/ffi/bindings.dart:
  - dbUpsertContent, dbUpsertMerge, dbUpsertPatch
- Implement three Dart methods in lib/src/database.dart:
  - upsertContent(String resource, Map<String, dynamic> data)
  - upsertMerge(String resource, Map<String, dynamic> data)
  - upsertPatch(String resource, List<PatchOp> patches)
  - All follow try/finally cleanup pattern
  - PatchOp serialization to RFC 6902 JSON Patch format
- Target: All 8 tests passing (matching original implementation)

**PRIORITY 4 - Fix Type Casting Issues (Days 7-8):**
- Investigate parameter management test failures (2 of 8 tests failing)
  - Test 4.1.4 and 4.1.7 have type casting issues in assertions
  - Focus on query response structure handling
- Investigate integration test failures (6 of 15 tests failing)
  - Type mismatches in query result unwrapping
  - Assertion type compatibility issues
- Ensure consistent type handling across all CRUD operations
- Fix response structure handling in _processResponse() and _processQueryResponse()
- Document type unwrapping patterns for future consistency
- Target: All in-scope tests passing (parameter tests: 8/8, integration tests: all relevant tests)

### Non-Functional Requirements

**Data Integrity:**
- Transaction rollback MUST actually discard changes (critical for production use)
- All database operations must maintain ACID properties where applicable
- No data corruption from failed transactions

**Consistency:**
- Uniform type handling across all SDK operations
- Consistent error types for similar failure modes
- Predictable response structure handling

**Reliability:**
- All implemented features must work reliably in both mem:// and rocksdb:// backends
- No memory leaks from any operations
- Proper cleanup on all error paths

**Maintainability:**
- Follow existing FFI patterns exactly for consistency
- Clear documentation of any deviations from original implementations
- Root cause analysis documented for future reference

## Visual Design

Not applicable - This is a bug fix and reimplementation spec.

## Reusable Components

### Existing Code to Leverage

**FFI Patterns from rust/src/query.rs and rust/src/database.rs:**
- panic::catch_unwind wrapper for all FFI entry points
- Null pointer validation before dereferencing
- set_last_error() for error propagation to Dart
- Box::into_raw() / Box::from_raw() memory management
- runtime.block_on() for async operations
- surreal_value_to_json() for clean response unwrapping (avoids type wrapper pollution)
- Integer return codes (0 = success, -1 = error)

**Dart Wrapper Patterns from lib/src/database.dart:**
- _ensureNotClosed() validation at method start
- Future(() {...}) async wrapping for all FFI calls
- try/finally with malloc.free() for pointer cleanup
- _processResponse() for response handling
- _getLastErrorString() for error context retrieval
- JSON encode/decode for FFI data bridge

**Test Patterns from existing test files:**
- Memory storage for fast test execution
- setUp() / tearDown() lifecycle management
- Descriptive test names explaining what is tested
- Focused tests (2-8 per feature, not exhaustive)
- Error case coverage with proper exception assertions

**Components That Exist:**
- RecordId type with serialization (for insertRelation)
- PatchOp type with JSON serialization (for upsertPatch)
- Existing CRUD operations (create, update, delete, select, get)
- Authentication methods (signin, signup, authenticate, invalidate)
- Parameter management infrastructure (set, unset)
- Function execution (run, version)
- Transaction infrastructure (needs rollback bug fix)
- Complete exception hierarchy (QueryException, TransactionException, etc.)

### New Components Required

None - This spec only fixes existing bugs and reimplements previously completed features.

## Reusable Implementation Reports

**Critical References for Reimplementation:**

1. **Insert Operations (Priority 2):**
   - Report: /Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-21-sdk-parity/implementation/2.1-insert-operations-implementation.md
   - Provides complete specification for:
     - Rust FFI function db_insert (lines 926-1026 in query.rs)
     - Dart methods insertContent() and insertRelation() (lines 768-930 in database.dart)
     - FFI binding dbInsert in bindings.dart
     - Test expectations (6/8 passing with 2 documented limitations)
     - RecordId serialization for graph relationships
     - Method variants approach rationale

2. **Upsert Operations (Priority 3):**
   - Report: /Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-21-sdk-parity/implementation/2.2-upsert-operations-implementation.md
   - Provides complete specification for:
     - Three Rust FFI functions (db_upsert_content, db_upsert_merge, db_upsert_patch)
     - Three Dart methods (upsertContent, upsertMerge, upsertPatch)
     - Three FFI bindings in bindings.dart
     - PatchOp integration for patch variant
     - Test expectations (8/8 passing)
     - Resource validation (table:id format required)

3. **Transaction Support (Priority 1 - Rollback Bug Reference):**
   - Report: /Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-21-sdk-parity/implementation/7.1-transaction-support-implementation.md
   - Documents known rollback issue:
     - CANCEL TRANSACTION executes without error
     - Changes are not actually discarded
     - Test expects 1 record after rollback, finds 3
     - Possible causes documented for investigation
     - Implementation details of db_begin, db_commit, db_rollback

## Technical Approach

### Investigation Plan for Transaction Rollback Bug

**Phase 1: Add Instrumentation (Day 1 Morning)**
- Add Rust-level logging to db_rollback function
- Add logging before and after CANCEL TRANSACTION execution
- Log transaction state at each lifecycle point
- Add SurrealDB query execution tracing if available

**Phase 2: Backend Testing (Day 1 Afternoon)**
- Test transaction rollback with mem:// backend (current failing test)
- Test transaction rollback with rocksdb:// backend
- Compare behavior between backends
- Document any differences in transaction support

**Phase 3: Root Cause Analysis (Day 2 Morning)**
- Review SurrealDB documentation for CANCEL TRANSACTION requirements
- Check if transaction state is properly maintained across FFI boundary
- Verify runtime.block_on() doesn't commit or interfere with transaction lifecycle
- Test if auto-commit is enabled and needs explicit disabling
- Compare with SurrealDB Rust SDK transaction examples

**Phase 4: Fix Implementation (Day 2 Afternoon)**
- Implement fix based on root cause findings
- Update db_rollback in rust/src/database.rs if needed
- Add any necessary transaction state management
- Test fix with all 8 transaction tests
- Document fix approach and rationale

### Reimplementation Approach for Insert Operations

**Based on Implementation Report 2.1:**
1. Implement db_insert in rust/src/query.rs following exact pattern from report
2. Use existing surreal_value_to_json helper for response unwrapping
3. Generate SQL: format!("INSERT INTO {} {}", resource_str, data_str)
4. Add FFI binding following @Native annotation pattern
5. Implement insertContent() and insertRelation() in database.dart
6. Follow try/finally cleanup pattern from existing methods
7. Run test/unit/insert_test.dart and verify 6/8 passing
8. Accept the 2 known limitations documented in original implementation

### Reimplementation Approach for Upsert Operations

**Based on Implementation Report 2.2:**
1. Implement three separate FFI functions in rust/src/query.rs
2. Each function validates resource is table:id format
3. Generate appropriate UPSERT statements (CONTENT, MERGE, PATCH)
4. Add three FFI bindings following existing patterns
5. Implement three Dart methods in database.dart
6. Serialize PatchOp list to JSON for patch variant
7. Run test/unit/upsert_operations_test.dart and verify 8/8 passing
8. Follow method variants approach (not builder pattern) per original design decision

### Type Casting Issues Investigation

**Parameter Tests (6/8 passing):**
- Analyze failing tests 4.1.4 and 4.1.7
- Check assertion type expectations vs actual response types
- Verify parameter value type preservation through FFI
- Fix type casting in test assertions or response handling

**Integration Tests (9/15 passing):**
- Identify the 6 failing tests and their type issues
- Review query result unwrapping in _processResponse()
- Ensure consistent type handling across all operations
- Document expected response structures

### Storage Backend Testing

- Transaction fix MUST be tested with both mem:// and rocksdb://
- Insert/upsert implementations tested with mem:// (per original specs)
- Integration tests use existing backend configurations
- Document any backend-specific behavior discovered

## Out of Scope

**Deferred Features (Explicitly Not Included):**
- Export/Import functionality - Status unclear, deferred for future investigation
- Live Queries - 30% complete (design done), needs dedicated 7-10 day spec in future
- New features beyond fixing existing issues
- Comprehensive edge case testing (focused testing only)
- Performance optimization
- Documentation updates beyond code comments
- Tests for deferred features

**Not Being Changed:**
- Existing passing functionality (119 of 139 tests currently passing)
- FFI patterns and infrastructure (already working well)
- Type system (RecordId, PatchOp, Jwt, etc. - all working)
- Authentication system (all 8 tests passing)
- Function execution (all 8 tests passing)
- Core CRUD operations that are working

## Success Criteria

**Critical Success Metrics:**
1. Transaction rollback bug fixed - all 8 transaction tests passing (currently 7/8)
2. Insert operations reimplemented - 6 of 8 tests passing (currently 0/8 due to missing code)
3. Upsert operations reimplemented - all 8 tests passing (currently 0/8 due to missing code)
4. Parameter management type issues fixed - all 8 tests passing (currently 6/8)
5. Integration test type issues fixed - all relevant tests passing (currently 9/15)
6. No regression in currently passing tests (119 tests must still pass)
7. No new memory leaks introduced
8. All implementations follow existing FFI patterns exactly

**Test Pass Rate Targets:**
- Transaction tests: 100% (8/8) - currently 7/8
- Insert tests: 75% (6/8) - currently cannot load due to missing methods
- Upsert tests: 100% (8/8) - currently cannot load due to missing methods
- Parameter tests: 100% (8/8) - currently 6/8
- Integration tests: 100% of in-scope tests - currently 9/15

**Overall Target:** Move from 86% test pass rate (119/139) to 100% for in-scope features

**Documentation Requirements:**
- Transaction rollback root cause documented
- Fix approach documented with rationale
- Any deviations from original implementations noted
- Known limitations preserved from original specs

**Timeline:** 6-10 days total
- Days 1-2: Transaction rollback bug investigation and fix
- Days 3-4: Insert operations reimplementation
- Days 5-6: Upsert operations reimplementation
- Days 7-8: Type casting issues resolution
- Days 9-10: Buffer for integration testing and documentation

## Implementation Sequence

**Sequential Approach (As Requested by User):**

### Phase 1: Transaction Rollback Bug Fix (Days 1-2)
1. Add tracing and logging infrastructure
2. Test with mem:// backend (current failing case)
3. Test with rocksdb:// backend (comparison)
4. Identify root cause through instrumentation
5. Implement fix in rust/src/database.rs
6. Verify all 8 transaction tests pass
7. Document root cause and fix approach

### Phase 2: Insert Operations Reimplementation (Days 3-4)
1. Review 2.1-insert-operations-implementation.md thoroughly
2. Implement db_insert in rust/src/query.rs (lines 926-1026)
3. Add FFI binding dbInsert in lib/src/ffi/bindings.dart
4. Implement insertContent() in lib/src/database.dart (lines 768-850)
5. Implement insertRelation() in lib/src/database.dart (lines 852-930)
6. Run test/unit/insert_test.dart - verify 6/8 passing
7. Document any deviations from original implementation

### Phase 3: Upsert Operations Reimplementation (Days 5-6)
1. Review 2.2-upsert-operations-implementation.md thoroughly
2. Implement db_upsert_content in rust/src/query.rs
3. Implement db_upsert_merge in rust/src/query.rs
4. Implement db_upsert_patch in rust/src/query.rs
5. Add three FFI bindings in lib/src/ffi/bindings.dart
6. Implement upsertContent() in lib/src/database.dart
7. Implement upsertMerge() in lib/src/database.dart
8. Implement upsertPatch() in lib/src/database.dart
9. Run test/unit/upsert_operations_test.dart - verify 8/8 passing
10. Document any deviations from original implementation

### Phase 4: Type Casting Issues Resolution (Days 7-8)
1. Analyze failing parameter tests (4.1.4 and 4.1.7)
2. Analyze failing integration tests (6 tests)
3. Identify common type handling issues
4. Fix response structure handling in _processResponse()
5. Fix type assertions in tests if needed
6. Verify all parameter tests pass (8/8)
7. Verify all relevant integration tests pass
8. Document type handling patterns

### Phase 5: Final Verification (Days 9-10)
1. Run complete test suite (all 139+ tests)
2. Verify test pass rate for in-scope features is 100%
3. Test with both mem:// and rocksdb:// backends
4. Verify no memory leaks introduced
5. Verify no regressions in passing tests
6. Confirm all requirements met
7. Finalize documentation

## Testing Strategy

**Test Execution Philosophy:**
- Run only tests specifically related to features being fixed
- Ignore tests for deferred features (export/import, live queries)
- Target 100% pass rate for in-scope tests
- Verify no regressions in currently passing tests

**Test Files In Scope:**
- test/transaction_test.dart (8 tests) - Fix 1 failing test
- test/unit/insert_test.dart (8 tests) - Currently cannot load, target 6/8
- test/unit/upsert_operations_test.dart (8 tests) - Currently cannot load, target 8/8
- test/parameter_management_test.dart (8 tests) - Fix 2 failing tests
- test/integration/sdk_parity_integration_test.dart (15 tests) - Fix 6 failing tests

**Test Files Out of Scope:**
- Export/import tests (feature deferred)
- Live query tests (feature deferred)
- Tests unrelated to bugs being fixed

**Storage Backend Testing:**
- Transaction fix: Test with BOTH mem:// and rocksdb:// backends
- Insert operations: Test with mem:// (per original spec)
- Upsert operations: Test with mem:// (per original spec)
- Integration tests: Use existing backend configurations

**Regression Testing:**
- All 119 currently passing tests must still pass
- Run full test suite after each phase
- Document any unexpected test behavior

## Known Issues and Constraints

**From Previous Implementation:**
1. Insert with specific record ID not supported (use create() instead)
2. Null data validation throws TypeError instead of ArgumentError
3. Upsert requires table:id format, not just table name
4. No batch operations for insert/upsert

**Current Critical Issue:**
1. Transaction rollback not discarding changes (CRITICAL - Priority 1)

**Implementation Constraints:**
- Must stick with existing FFI patterns (user preference: "they work well")
- Sequential approach required (fix transaction bug first, then proceed)
- Cannot defer transaction fix (data integrity risk)
- Must achieve 100% test pass rate for in-scope features

**Timeline Constraints:**
- 6-10 days total estimated
- Transaction fix is blocking (must complete first)
- Buffer time included for investigation and integration testing
