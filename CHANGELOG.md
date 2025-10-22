## 1.1.0

### Fixed
- **Critical Deserialization Fix**: Resolved issue where SurrealDB query results returned field values as null due to type wrapper serialization
  - Implemented manual unwrapper using unsafe transmute to access `surrealdb_core::sql::Value` enum variants
  - Pattern matches on all SurrealDB type variants (Strand, Number, Thing, Bool, Object, Array, etc.)
  - Extracts actual values from enum wrappers, producing clean JSON output
  - Thing IDs now properly formatted as "table:id" strings instead of complex objects
  - Nested structures (arrays within objects, objects within arrays) correctly deserialized
  - Decimal numbers preserved as strings to maintain arbitrary precision

### Improved
- **FFI Stack Audit**: Comprehensive safety audit of entire Rust-to-Dart FFI stack
  - Verified all FFI functions use `panic::catch_unwind` for panic safety
  - Confirmed null pointer validation before dereferencing
  - Validated error propagation mechanism across all three layers (Rust → Dart FFI → High-level API)
  - Ensured CString/CStr conversions handle UTF-8 errors properly
  - Verified Box::into_raw/from_raw pairs are balanced for memory safety
  - Confirmed Tokio runtime initialization and async operation blocking
  - Validated NativeFinalizer attachment for automatic resource cleanup
  - Verified background isolate communication reliability

- **Code Quality**: Removed all diagnostic logging for production-ready codebase
  - Eliminated all `eprintln!` debug statements from Rust code
  - Removed `print('[ISOLATE]` debug statements from Dart isolate code
  - Clean console output with only essential error messages

### Enhanced
- **Documentation**: Updated inline code comments with comprehensive explanations
  - Documented why manual unwrapping is necessary (type wrapper pollution problem)
  - Explained unsafe transmute operations and why they are safe
  - Added examples of unwrapping for all major SurrealDB types
  - Clarified safety guarantees of transparent wrapper pattern
  - Updated all CRUD operation comments to reflect manual unwrapper usage

### Technical Details
- Manual unwrapper uses `std::mem::transmute` to safely access CoreValue enum
  - Safe because `surrealdb::Value` has `#[repr(transparent)]` attribute
  - Memory layout identical to wrapped `CoreValue`
  - Only borrows through references, never moves or mutates
- Handles 25+ SurrealDB type variants comprehensively
- Recursive processing for nested Object and Array structures
- Base64 encoding for Bytes type for safe JSON transport
- ISO 8601 formatting for DateTime values
- Proper handling of special cases (NaN/Inf floats → null)

### Testing
- Comprehensive test suite added with 13 feature-specific tests
  - Deserialization validation (4 tests)
  - CRUD operations across both backends (9 tests)
  - Error propagation testing
  - Memory stability testing (100+ record stress test)
  - RocksDB persistence validation
- All tests passing with clean JSON output
- No type wrappers detected in any test results

### Performance
- No performance regression from manual unwrapping approach
- Memory usage remains stable during extended operations
- Background isolate prevents UI thread blocking
- Zero memory leaks detected in stress testing

## 1.0.0

- Initial version.
