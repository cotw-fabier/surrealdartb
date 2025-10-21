# Tech Stack

## Language & Runtime

### Dart
- **Version:** Dart 3.9.2+ (as specified in pubspec.yaml)
- **Features Used:**
  - Null safety for compile-time safety guarantees
  - FFI support via `dart:ffi` for native interop
  - Pattern matching for exhaustive error handling
  - Records for multiple return values
  - Sealed classes for type-safe result types
  - Async/await with isolates for concurrent operations
- **Rationale:** Modern Dart provides excellent FFI support and cross-platform capabilities essential for wrapping native libraries

### Rust
- **Version:** Pinned via `rust-toolchain.toml` (exact version TBD during implementation)
- **Features Used:**
  - SurrealDB embedded database engine
  - FFI exports with `#[no_mangle]` and `extern "C"`
  - Panic safety with `std::panic::catch_unwind`
  - Memory management with `Box::into_raw()` / `Box::from_raw()`
  - Cross-platform compilation targeting all native platforms
- **Rationale:** SurrealDB is written in Rust; using Rust FFI provides direct access to the full database engine

## Core Dependencies

### Dart Side

**Production Dependencies:**
```yaml
ffi: ^2.1.0
```
- FFI helper utilities (malloc, calloc, Utf8)
- Native finalizer support
- Pointer manipulation helpers

**Development Dependencies:**
```yaml
test: ^1.25.6
lints: ^6.0.0
native_toolchain_rs:
  git:
    url: https://github.com/GregoryConrad/native_toolchain_rs
    ref: <commit-hash>  # Pin to specific commit during implementation
```

**Optional (Future):**
- `flutter: sdk: flutter` (if building Flutter plugin variant)
- `build_runner` (if code generation becomes necessary)

### Rust Side

**Cargo.toml Dependencies:**
```toml
[dependencies]
surrealdb = { version = "latest", default-features = false, features = ["kv-mem", "kv-rocksdb"] }
# Additional SurrealDB feature flags as needed for vector indexing, etc.
```

**Crate Configuration:**
```toml
[lib]
crate-type = ["staticlib", "cdylib"]

[profile.release]
opt-level = "z"     # Optimize for size (important for mobile)
lto = true          # Link-time optimization
codegen-units = 1   # Better optimization
strip = true        # Strip symbols for smaller binaries
```

## Build System & Tooling

### Native Assets
- **System:** Dart Native Assets via `hook/build.dart`
- **Builder:** `native_toolchain_rs` for Rust compilation
- **Asset Naming:** `package:surrealdartb/surrealdartb_bindings`
- **Process:** Automatic Rust compilation during `dart pub get` / `flutter pub get`

### Build Configuration Files

**hook/build.dart:**
```dart
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await RustBuilder(
      assetName: 'src/ffi/surrealdartb_bindings.g.dart',
      // Cargo features for SurrealDB configuration
    ).run(input: input, output: output);
  });
}
```

**rust-toolchain.toml:**
```toml
[toolchain]
channel = "1.90.0"  # Pin exact Rust version
targets = [
  "aarch64-apple-darwin",      # macOS ARM64
  "x86_64-apple-darwin",       # macOS Intel
  "aarch64-apple-ios",         # iOS ARM64
  "aarch64-linux-android",     # Android ARM64
  "armv7-linux-androideabi",   # Android ARMv7
  "x86_64-pc-windows-msvc",    # Windows x64
  "x86_64-unknown-linux-gnu",  # Linux x64
  "aarch64-unknown-linux-gnu"  # Linux ARM64
]
```

### Development Tools

**Required:**
- Dart SDK 3.9.2+
- Rust toolchain (rustup with version from rust-toolchain.toml)
- Platform-specific build tools:
  - **macOS:** Xcode Command Line Tools
  - **Windows:** MSVC (Visual Studio Build Tools)
  - **Linux:** GCC/Clang toolchain
  - **iOS:** Xcode with iOS SDK
  - **Android:** Android NDK

**Recommended:**
- VS Code with Dart and Rust extensions
- Android Studio (for Android builds)
- Xcode (for iOS/macOS builds)

## FFI Architecture

### Layer Structure

**Low-Level FFI Layer** (`lib/src/ffi/`):
- Native function bindings with `@Native` annotations
- Opaque handle definitions extending `Opaque`
- Struct definitions matching native memory layout
- Direct pointer manipulation
- Memory allocation/deallocation
- String conversion utilities (Dart ↔ C strings)

**High-Level Dart API Layer** (`lib/src/`):
- Type-safe wrappers around FFI calls
- Automatic memory management with `NativeFinalizer`
- Dart-idiomatic async APIs
- Error handling with exceptions (no error codes exposed)
- Stream-based APIs for live queries
- Documentation and examples

### Memory Management Strategy

**Principles:**
- Rust allocates, Dart frees (via `NativeFinalizer`)
- All native resources tied to Dart object lifecycle
- No manual memory management in public API
- Automatic cleanup when Dart objects are garbage collected

**Patterns:**
```dart
final class NativeHandle extends Opaque {}

class Database {
  final Pointer<NativeHandle> _handle;

  static final _finalizer = NativeFinalizer(
    Native.addressOf<NativeVoid Function(Pointer<NativeHandle>)>(
      _destroyHandle
    )
  );

  Database._(this._handle) {
    _finalizer.attach(this, _handle.cast());
  }
}
```

## Platform Support

### Target Platforms
- **iOS:** arm64 (iOS 12.0+)
- **Android:** arm64-v8a, armeabi-v7a (API 21+)
- **macOS:** x86_64, arm64 (macOS 10.13+)
- **Windows:** x86_64 (Windows 10+)
- **Linux:** x86_64, arm64 (glibc 2.27+)

### Platform-Specific Notes
- **Mobile (iOS/Android):** Size optimization critical, minimal features
- **Desktop (macOS/Windows/Linux):** Can include all features, less size-constrained
- **No Web Support:** SurrealDB embedded engine requires native code, incompatible with web compilation

## Testing Infrastructure

### Test Tools
- `package:test` for unit and integration tests
- Platform-specific test runners for each target
- FFI-specific tests for memory safety
- Performance benchmarks for database operations

### CI/CD Strategy
- GitHub Actions for automated testing
- Matrix builds covering all platforms
- Memory leak detection (Valgrind on Linux, Instruments on macOS)
- Performance regression testing
- Cross-platform consistency validation

### Test Categories
1. **Unit Tests:** Pure Dart logic, FFI binding correctness
2. **Integration Tests:** Database operations, query execution
3. **Platform Tests:** Platform-specific behavior validation
4. **Performance Tests:** Benchmark critical paths (CRUD, queries, vector search)
5. **Memory Tests:** Leak detection, finalizer validation

## Code Quality & Standards

### Linting & Formatting
- **Linter:** `package:lints` (strict Dart analysis)
- **Formatter:** `dart format` with 80 character line limit
- **Analysis Options:** Strict mode with all recommended lints enabled

### Documentation
- **API Docs:** Generated with `dartdoc`
- **Examples:** Comprehensive example applications in `example/`
- **Guides:** Usage guides for common patterns
- **README:** Quick start and feature overview

### Code Style
- Follow Effective Dart guidelines
- PascalCase for classes/enums
- camelCase for variables/functions
- snake_case for file names
- Prefix FFI types with `Native` (e.g., `NativeDatabase`)
- Arrow syntax for simple one-line functions
- Explicit type annotations for public APIs
- `final` by default for all variables
- Exhaustive switch statements with sealed classes

## Version Control & Release

### Versioning Strategy
- Semantic versioning (MAJOR.MINOR.PATCH)
- Git tags for releases
- Detailed CHANGELOG.md
- Breaking changes clearly documented

### Release Process
1. Update version in `pubspec.yaml`
2. Update CHANGELOG.md with release notes
3. Tag release in Git
4. Publish to pub.dev (when ready)
5. Create GitHub release with binaries for each platform

## Security Considerations

### Memory Safety
- All FFI boundaries validated for null pointers
- No buffer overflows (Rust memory safety + Dart checks)
- Panic catching at FFI boundary prevents crashes

### Data Safety
- Database ACID guarantees from SurrealDB
- Transaction support for atomic operations
- No data corruption on unexpected termination

### Privacy
- Fully local/embedded by default
- No telemetry or external network calls
- User data never leaves device (unless explicitly synced)

## Performance Optimization

### Strategies
- Minimize FFI boundary crossings (batch operations)
- Use `NativeCallable.isolateLocal()` for callbacks
- Leverage Rust's zero-cost abstractions
- Optimize for mobile constraints (battery, memory)
- Lazy initialization where possible

### Benchmarking
- Measure FFI overhead
- Database operation performance
- Memory usage across platforms
- Query execution time
- Vector search performance with various dataset sizes

## Future Technical Enhancements

- **Code Generation:** Consider `ffigen` for automatic binding generation if API grows
- **Custom Allocators:** Optimize memory allocation patterns for specific workloads
- **Streaming Results:** Stream large query results to reduce memory pressure
- **Background Isolates:** Offload heavy operations to background isolates
- **Platform Channels:** Combine FFI with platform channels for platform-specific features
- **Hot Reload Support:** Investigate Flutter hot reload compatibility with native state
