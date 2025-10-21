/// FFI utility functions for string conversion and error handling.
///
/// This library provides helper functions for safely crossing the FFI boundary
/// between Dart and C, with a focus on string conversion and memory management.
library;

import 'dart:ffi';
import 'package:ffi/ffi.dart';

import '../exceptions.dart';

/// Converts a Dart string to a C string (UTF-8 encoded).
///
/// The returned pointer is allocated using malloc and must be freed
/// using [freeCString] when no longer needed.
///
/// Example:
/// ```dart
/// final ptr = stringToCString('Hello');
/// try {
///   nativeFunction(ptr);
/// } finally {
///   freeCString(ptr);
/// }
/// ```
///
/// Returns: Pointer to null-terminated UTF-8 string
/// Lifetime: Caller owns and must free
Pointer<Utf8> stringToCString(String str) {
  return str.toNativeUtf8(allocator: malloc);
}

/// Converts a C string (UTF-8 encoded) to a Dart string.
///
/// This function copies the string data from native memory into Dart.
/// The native pointer is NOT freed by this function - the caller is
/// responsible for freeing it if needed.
///
/// Throws [ArgumentError] if pointer is null.
///
/// Example:
/// ```dart
/// final nativePtr = someNativeFunction();
/// try {
///   final str = cStringToDartString(nativePtr);
///   print(str);
/// } finally {
///   malloc.free(nativePtr);
/// }
/// ```
///
/// Returns: Dart String copy of the C string
/// Lifetime: Returned string is owned by Dart
String cStringToDartString(Pointer<Utf8> ptr) {
  if (ptr == nullptr) {
    throw ArgumentError.notNull('ptr');
  }
  return ptr.toDartString();
}

/// Frees a C string allocated by [stringToCString] or native code.
///
/// This should be called in a finally block to ensure cleanup even
/// when exceptions occur.
///
/// It is safe to call this with a null pointer (no-op).
///
/// Example:
/// ```dart
/// final ptr = stringToCString('Hello');
/// try {
///   nativeFunction(ptr);
/// } finally {
///   freeCString(ptr);
/// }
/// ```
void freeCString(Pointer<Utf8> ptr) {
  if (ptr != nullptr) {
    malloc.free(ptr);
  }
}

/// Maps a native error code to a DatabaseException.
///
/// This function converts integer error codes returned from FFI functions
/// into meaningful Dart exceptions with descriptive error messages.
///
/// Error code conventions:
/// - 0: Success (no exception)
/// - -1: General error
/// - -2: Connection error
/// - -3: Query error
/// - -4: Authentication error
/// - Other negative values: Unknown error
///
/// The [nativeMessage] parameter should be obtained from the native
/// get_last_error() function to provide detailed error context.
///
/// Throws:
/// - [ConnectionException] for connection-related errors
/// - [QueryException] for query execution errors
/// - [AuthenticationException] for authentication failures
/// - [DatabaseException] for other errors
void throwIfError(int errorCode, [String? nativeMessage]) {
  if (errorCode == 0) {
    return; // Success
  }

  final message = nativeMessage ?? 'Native operation failed';

  switch (errorCode) {
    case -2:
      throw ConnectionException(message, errorCode: errorCode);
    case -3:
      throw QueryException(message, errorCode: errorCode);
    case -4:
      throw AuthenticationException(message, errorCode: errorCode);
    case -1:
    default:
      throw DatabaseException(message, errorCode: errorCode);
  }
}

/// Validates that a pointer is non-null and throws if it is null.
///
/// This should be used to validate pointers returned from native functions
/// before attempting to use them.
///
/// Example:
/// ```dart
/// final handle = nativeCreateDatabase(endpoint);
/// validateNonNull(handle, 'Failed to create database');
/// ```
///
/// Throws [DatabaseException] if pointer is null
void validateNonNull(Pointer ptr, String errorMessage) {
  if (ptr == nullptr) {
    throw DatabaseException(errorMessage);
  }
}

/// Validates that a native function returned success (0) or throws.
///
/// This is a convenience wrapper around [throwIfError] for functions
/// that return simple success/failure codes.
///
/// Example:
/// ```dart
/// final code = nativeConnect(handle);
/// validateSuccess(code, 'Connection failed');
/// ```
///
/// Throws [DatabaseException] (or subclass) if error code is non-zero
void validateSuccess(int errorCode, String operation) {
  if (errorCode != 0) {
    throwIfError(errorCode, operation);
  }
}
