# SurrealDB Dart Tests

This directory contains tests for the SurrealDB Dart FFI bindings.

## Architecture Update: Direct FFI (No Isolates)

**Important:** The test suite has been updated for the new direct FFI architecture.

### What Changed

**OLD Architecture (Removed):**
- Database operations used isolate message passing
- Background isolate handled all FFI calls
- Higher overhead but isolated FFI from main thread

**NEW Architecture (Current):**
- Database operations call FFI directly
- Operations wrapped in `Future` for async behavior
- Lower overhead, simpler architecture
- Rust layer uses `runtime.block_on()` for thread safety

### Key Differences for Testing

1. **No Isolate Startup Delay:** Connection is faster without isolate initialization
2. **Same Public API:** Test code doesn't change (still async/await)
3. **Direct Error Messages:** Errors come straight from Rust FFI layer
4. **Better Performance:** Lower latency for all operations

## Test Structure

### Unit Tests (`test/unit/`)

Low-level tests that verify individual components work correctly:

- `database_api_test.dart` - Tests public Database API behavior
- `ffi_bindings_test.dart` - Tests FFI utilities and error mapping

**Note:** `isolate_communication_test.dart` was removed as part of the architecture update.

### Integration Tests (root `test/` directory)

End-to-end tests that verify complete workflows:

- `deserialization_validation_test.dart` - Validates clean JSON deserialization
- `comprehensive_crud_error_test.dart` - Complete CRUD and error handling tests
- `async_behavior_test.dart` - Tests async behavior with direct FFI
- `example_scenarios_test.dart` - Tests CLI example scenarios

## Running Tests

### Run All Tests

```bash
dart test
```

### Run Specific Test File

```bash
dart test test/deserialization_validation_test.dart
```

### Run Specific Test Group

```bash
dart test --name "Database Connection"
```

### Run with Verbose Output

```bash
dart test --reporter=expanded
```

## Test Coverage

The test suite focuses on critical workflows rather than exhaustive coverage:

- **Deserialization Tests:** 4 tests verifying clean JSON output
- **CRUD Tests:** 8 tests covering complex data types, all operations, and errors
- **Async Behavior Tests:** 9 tests verifying non-blocking direct FFI
- **Unit Tests:** Multiple tests for API components and FFI utilities

**Total:** ~25+ strategic tests covering core functionality

## Test Requirements

Tests require:
- Rust FFI library compiled (`cargo build` in `rust/` directory)
- Dart SDK installed
- Test package dependencies (`dart pub get`)

## Writing New Tests

When adding new tests:

1. **Follow the async/await pattern** - All database operations return Futures
2. **Use setUp/tearDown** - Create/close database connections properly
3. **Test error handling** - Verify exceptions are thrown correctly
4. **Clean up resources** - Always call `db.close()` in tearDown or finally blocks
5. **Be specific** - Test one behavior per test case
6. **Document architecture** - Add comments explaining direct FFI behavior if relevant

### Example Test Template

```dart
import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Feature Tests', () {
    late Database db;

    setUp(() async {
      // Create database connection
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      // Clean up
      if (!db.isClosed) {
        await db.close();
      }
    });

    test('should do something specific', () async {
      // Test implementation
      final result = await db.create('table', {'field': 'value'});
      expect(result['field'], equals('value'));
    });
  });
}
```

## Test Philosophy

These tests follow the "strategic testing" approach:

- **2-8 tests per feature group** - Focused, not exhaustive
- **Critical workflows only** - Test what matters most
- **Fast execution** - Quick feedback loop
- **Clear failure messages** - Easy to diagnose issues

## Continuous Integration

These tests are designed to run in CI environments:

- Fast execution (most tests complete in seconds)
- No external dependencies required
- Clean setup/teardown prevents test pollution
- Deterministic results (no flaky tests)

## Troubleshooting

### Tests Won't Compile

- Check that Rust library is compiled: `cd rust && cargo build`
- Verify dependencies are installed: `dart pub get`
- Ensure Database class implementation is complete

### Tests Fail with "Type not found" Errors

- The Database implementation may be incomplete
- Check that all FFI types are properly defined in `lib/src/ffi/`
- Verify bindings match Rust FFI functions

### Tests Hang or Timeout

- Ensure Rust layer properly handles async operations with `runtime.block_on()`
- Check for resource leaks (unclosed database connections)
- Verify FFI functions don't deadlock

### Memory Errors

- Check NativeFinalizer is attached to all native resources
- Verify all pointers are freed in Rust layer
- Look for use-after-free issues in FFI boundary

## Architecture Notes

### Why Direct FFI Instead of Isolates?

1. **Simplicity:** Fewer moving parts, easier to debug
2. **Performance:** Lower latency without message passing overhead
3. **Safety:** Rust layer handles thread safety with `runtime.block_on()`
4. **Maintainability:** Less code to maintain, clearer error paths

### Thread Safety

Even though we call FFI directly (no isolate), operations are thread-safe because:

- Rust layer uses `runtime.block_on()` to execute async SurrealDB operations synchronously
- Each Database instance has its own native handle
- Dart's async/await ensures operations don't interfere with UI thread

### Async Behavior

Operations return `Future` objects even though FFI calls are synchronous because:

- Maintains consistent async API
- Allows for future optimization (true async FFI)
- Doesn't block Dart event loop
- Compatible with existing async Dart code

## Contributing

When contributing tests:

1. Follow existing test patterns
2. Update this README if adding new test categories
3. Ensure all tests pass before submitting
4. Document any new testing utilities or helpers

## References

- Main spec: `agent-os/specs/2025-10-21-comprehensive-ffi-stack-review-and-deserialization-engine/spec.md`
- Task breakdown: `agent-os/specs/2025-10-21-comprehensive-ffi-stack-review-and-deserialization-engine/tasks.md`
- Architecture decision: Direct FFI approach (no isolates)
