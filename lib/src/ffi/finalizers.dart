/// Native resource finalizers for automatic memory cleanup.
///
/// This library provides NativeFinalizer instances that automatically
/// clean up native resources when Dart objects are garbage collected.
/// This prevents memory leaks even if close() methods are not called.
library;

import 'dart:ffi';

import 'bindings.dart' as bindings;
import 'native_types.dart';

/// Finalizer for NativeDatabase handles.
///
/// This finalizer automatically calls db_close() when a Dart object
/// wrapping a NativeDatabase handle is garbage collected. It should
/// be attached to wrapper objects using:
///
/// ```dart
/// class DatabaseHandle {
///   final Pointer<NativeDatabase> _handle;
///
///   DatabaseHandle(this._handle) {
///     databaseFinalizer.attach(this, _handle.cast());
///   }
/// }
/// ```
///
/// Note: While finalizers provide automatic cleanup, it's still
/// recommended to call close() explicitly for critical resources
/// to ensure timely cleanup rather than waiting for GC.
final databaseFinalizer = NativeFinalizer(
  Native.addressOf<NativeDbDestructor>(bindings.dbClose),
);

/// Finalizer for NativeResponse handles.
///
/// This finalizer automatically calls response_free() when a Dart object
/// wrapping a NativeResponse handle is garbage collected.
///
/// ```dart
/// class ResponseHandle {
///   final Pointer<NativeResponse> _handle;
///
///   ResponseHandle(this._handle) {
///     responseFinalizer.attach(this, _handle.cast());
///   }
/// }
/// ```
///
/// Response handles are typically short-lived and consumed immediately
/// after query execution, but the finalizer ensures cleanup even if
/// exceptions occur during result processing.
final responseFinalizer = NativeFinalizer(
  Native.addressOf<NativeResponseDestructor>(bindings.responseFree),
);

/// Attaches the database finalizer to a wrapper object.
///
/// This is a convenience function that attaches the database finalizer
/// to an object that owns a native database handle.
///
/// Parameters:
/// - [owner] - The Dart object that owns the handle
/// - [handle] - The native database handle to clean up
///
/// Example:
/// ```dart
/// final handle = bindings.dbNew(endpoint);
/// attachDatabaseFinalizer(this, handle);
/// ```
void attachDatabaseFinalizer(Object owner, Pointer<NativeDatabase> handle) {
  databaseFinalizer.attach(owner, handle.cast());
}

/// Attaches the response finalizer to a wrapper object.
///
/// This is a convenience function that attaches the response finalizer
/// to an object that owns a native response handle.
///
/// Parameters:
/// - [owner] - The Dart object that owns the handle
/// - [handle] - The native response handle to clean up
///
/// Example:
/// ```dart
/// final response = bindings.dbQuery(dbHandle, sql);
/// attachResponseFinalizer(this, response);
/// ```
void attachResponseFinalizer(Object owner, Pointer<NativeResponse> handle) {
  responseFinalizer.attach(owner, handle.cast());
}
