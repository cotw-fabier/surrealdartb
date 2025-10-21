# Task 3: Low-Level Dart FFI Bindings

## Overview
**Task Reference:** Task Group #3 from `/Users/fabier/Documents/code/surrealdartb/agent-os/specs/2025-10-21-initial-ffi-bindings-setup/tasks.md`
**Implemented By:** api-engineer
**Date:** 2025-10-21
**Status:** ✅ Complete

### Task Description
Implement the low-level Dart FFI bindings layer that provides direct access to the Rust FFI functions. This layer handles opaque types, string conversion between Dart and C, memory management with finalizers, and error code to exception mapping.

## Implementation Summary
The Dart FFI bindings layer was implemented to provide a clean abstraction over the native Rust functions while ensuring memory safety and proper error handling. The implementation follows the opaque handle pattern, where native resources are represented as opaque types in Dart and managed through NativeFinalizers for automatic cleanup.

The layer consists of type definitions for native function signatures, utility functions for safe string conversion and memory management, direct FFI function declarations using @Native annotations, and finalizers for automatic resource cleanup. All raw pointer operations are hidden from higher-level APIs, and comprehensive documentation ensures clear understanding of memory ownership and lifetime contracts.

## Files Changed/Created

### New Files
- `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/native_types.dart` - Defines opaque types and function signatures for FFI boundary
- `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/ffi_utils.dart` - Provides string conversion and error handling utilities
- `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/bindings.dart` - Declares all Rust FFI functions with @Native annotations
- `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/finalizers.dart` - Configures NativeFinalizers for automatic memory cleanup
- `/Users/fabier/Documents/code/surrealdartb/lib/src/exceptions.dart` - Defines exception hierarchy (created for FFI utils dependency)
- `/Users/fabier/Documents/code/surrealdartb/test/unit/ffi_bindings_test.dart` - Unit tests for FFI utilities (8 focused tests)

### Modified Files
None - all implementation was in new files.

### Deleted Files
None

## Key Implementation Details

### Opaque Types and Function Signatures
**Location:** `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/native_types.dart`

Implemented opaque handle types `NativeDatabase` and `NativeResponse` extending `Opaque` class to represent native resources without exposing internal structure. Defined comprehensive typedef declarations for all native function signatures including database lifecycle operations (create, connect, use_ns, use_db, close), query execution functions (query, get_results, has_errors, free), CRUD operations (select, create, update, delete), and error handling functions (get_last_error, free_string).

**Rationale:** Opaque types provide type safety at the FFI boundary while preventing direct manipulation of native pointers. Typedefs ensure consistent function signatures and improve code readability.

### String Conversion Utilities
**Location:** `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/ffi_utils.dart`

Implemented safe string conversion functions: `stringToCString()` allocates UTF-8 encoded C strings using malloc, `cStringToDartString()` copies C string data into Dart strings with null pointer validation, and `freeCString()` safely frees allocated C strings with null checks. All functions are designed to be used in try-finally blocks to ensure proper cleanup.

**Rationale:** String conversion is a critical point of failure in FFI. These utilities ensure proper memory management and prevent leaks by providing paired allocation/deallocation with clear ownership semantics.

### Error Code Mapping
**Location:** `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/ffi_utils.dart`

Implemented `throwIfError()` function that maps integer error codes to specific exception types: -2 maps to ConnectionException, -3 to QueryException, -4 to AuthenticationException, and other negative values to DatabaseException. Also provided helper functions `validateNonNull()` and `validateSuccess()` for common validation patterns.

**Rationale:** Converting native error codes to typed Dart exceptions provides better error handling semantics and allows callers to catch specific error types. The mapping follows the error code convention defined in the Rust FFI layer.

### FFI Function Declarations
**Location:** `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/bindings.dart`

Declared all Rust FFI functions using @Native annotations with proper symbol names. Implemented platform-aware native library loading that tries `DynamicLibrary.process()` first (for native assets) then falls back to platform-specific loading (.so for Android/Linux, .dll for Windows, executable for iOS/macOS). All functions are documented with parameter descriptions, return value semantics, and lifetime/ownership information.

**Rationale:** @Native annotations provide efficient direct FFI calls. Platform-aware loading ensures the library works across different deployment scenarios. Comprehensive documentation is critical for FFI boundary contracts.

### NativeFinalizers
**Location:** `/Users/fabier/Documents/code/surrealdartb/lib/src/ffi/finalizers.dart`

Created `databaseFinalizer` and `responseFinalizer` instances that automatically call respective destructor functions when Dart objects are garbage collected. Provided convenience functions `attachDatabaseFinalizer()` and `attachResponseFinalizer()` for easy attachment to wrapper objects.

**Rationale:** NativeFinalizers prevent memory leaks by ensuring native resources are freed even if explicit cleanup is forgotten. This is essential for preventing resource leaks in production applications.

## Database Changes
Not applicable - this task does not involve database schema changes.

## Dependencies

### New Dependencies Added
No new dependencies were added. The implementation uses existing dependencies:
- `ffi: ^2.1.0` (already in pubspec.yaml)

### Configuration Changes
None required for this task group.

## Testing

### Test Files Created/Updated
- `/Users/fabier/Documents/code/surrealdartb/test/unit/ffi_bindings_test.dart` - 8 focused unit tests

### Test Coverage
- Unit tests: ✅ Complete
- Integration tests: ⚠️ Deferred to Task Group 7
- Edge cases covered:
  - String conversion with various UTF-8 strings
  - Null pointer handling in string conversion
  - Error code mapping for all error types
  - Null-safe pointer validation
  - Memory allocation and deallocation

### Manual Testing Performed
Tests requiring the Rust FFI layer to be built were noted but not executed, as they depend on Task Groups 1 and 2 being fully operational. The unit tests focus on pure Dart functionality (string conversion, error mapping) that can be tested without native code.

## User Standards & Preferences Compliance

### agent-os/standards/backend/ffi-types.md
**File Reference:** `/Users/fabier/Documents/code/surrealdartb/agent-os/standards/backend/ffi-types.md`

**How Your Implementation Complies:**
All opaque types use `final class` extending `Opaque` as specified. String types are converted using `Utf8` codec with proper allocation via malloc. NativeFinalizers are attached to wrapper objects to prevent memory leaks. All pointer operations include null checks before dereferencing. Type definitions match C function signatures exactly.

**Deviations (if any):**
None. Full compliance with FFI type mapping standards.

### agent-os/standards/backend/async-patterns.md
**File Reference:** `/Users/fabier/Documents/code/surrealdartb/agent-os/standards/backend/async-patterns.md`

**How Your Implementation Complies:**
While this task group focuses on low-level FFI bindings (synchronous), the design anticipates async patterns by documenting that these functions will be called from background isolates. All native calls are documented as blocking operations that should not be called from the UI thread.

**Deviations (if any):**
None. The FFI layer is correctly designed to be wrapped by async isolate layer (Task Group 4).

### agent-os/standards/global/error-handling.md
**File Reference:** `/Users/fabier/Documents/code/surrealdartb/agent-os/standards/global/error-handling.md`

**How Your Implementation Complies:**
Created custom exception hierarchy (`DatabaseException`, `ConnectionException`, `QueryException`, `AuthenticationException`) that preserves native error context including error codes and messages. All error codes are checked and converted to appropriate exception types. Null pointer checks throw `ArgumentError` as specified. All FFI calls are wrapped in guard functions that validate preconditions.

**Deviations (if any):**
None. Full compliance with error handling standards.

### agent-os/standards/global/conventions.md
**File Reference:** `/Users/fabier/Documents/code/surrealdartb/agent-os/standards/global/conventions.md`

**How Your Implementation Complies:**
FFI implementation is placed in `lib/src/ffi/` subdirectory, keeping internal details hidden from public API. All code is soundly null-safe. Comprehensive dartdoc comments document all public APIs, including FFI boundary contracts and memory ownership. Raw pointer types are never exposed in public API.

**Deviations (if any):**
None. Follows package structure and documentation conventions.

## Integration Points

### APIs/Endpoints
Not applicable - this is an internal FFI layer, not a public API endpoint.

### External Services
- **Native Library:** Loads `libsurrealdartb_bindings` dynamically based on platform

### Internal Dependencies
- Depends on Rust FFI layer (Task Group 2) for native function implementations
- Used by isolate communication layer (Task Group 4) for actual FFI calls

## Known Issues & Limitations

### Issues
None identified during implementation.

### Limitations
1. **Platform Loading**
   - Description: Library loading uses fallback logic that may not cover all edge cases
   - Reason: Native assets system is preferred but platform-specific fallbacks provided for compatibility
   - Future Consideration: Monitor native assets system evolution and simplify loading logic when stable

2. **Test Execution**
   - Description: Full FFI tests cannot run until Rust layer is built
   - Reason: Tests require native library to be compiled and linked
   - Future Consideration: Execute full test suite after Task Groups 1-2 are verified complete

## Performance Considerations
FFI calls are inherently fast but blocking. All operations are designed to be called from background isolates (Task Group 4) to prevent UI blocking. String conversion involves memory allocation/copying but is optimized by using malloc allocator. No performance bottlenecks identified at this layer.

## Security Considerations
Null pointer validation prevents crashes from invalid pointers. All string conversions validate input before dereferencing. Native library loading uses platform-specific secure paths. No user input is directly passed to native code without validation at higher layers.

## Dependencies for Other Tasks
- **Task Group 4 (Isolate Architecture):** Depends on this FFI layer to make actual native calls
- **Task Group 5 (Public API):** Indirectly depends through isolate layer
- **Task Group 7 (Testing):** Will verify FFI integration in end-to-end tests

## Notes
The FFI bindings layer successfully provides a clean, safe abstraction over native Rust functions. The implementation follows all standards for memory management, error handling, and type safety. The layer is ready to be consumed by the isolate communication layer (Task Group 4).

A critical design decision was to keep this layer focused on pure FFI concerns (types, string conversion, memory management) while deferring async patterns to Task Group 4. This separation of concerns makes the code easier to understand and maintain.

The test suite focuses on testable utilities (string conversion, error mapping) while noting that full integration tests require the native library. This pragmatic approach allows verification of Dart-side logic without blocking on Rust compilation.
