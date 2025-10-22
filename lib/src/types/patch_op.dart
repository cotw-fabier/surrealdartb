/// PatchOp type for JSON Patch operations in SurrealDB.
///
/// This library provides the PatchOp class for creating JSON Patch operations
/// used with upsert().patch() methods.
library;

/// Enum representing JSON Patch operation types.
///
/// Based on RFC 6902 JSON Patch standard.
enum PatchOperation {
  /// Add a new value at the specified path.
  add,

  /// Remove the value at the specified path.
  remove,

  /// Replace the value at the specified path.
  replace,

  /// Change the value at the specified path (SurrealDB extension).
  change,
}

/// Represents a JSON Patch operation for use with SurrealDB upsert().patch().
///
/// Based on RFC 6902 JSON Patch format with SurrealDB extensions.
/// Each operation specifies a path in the document and an operation type.
///
/// Example:
/// ```dart
/// // Add a new field
/// final op1 = PatchOp.add('/email', 'alice@example.com');
///
/// // Replace an existing field
/// final op2 = PatchOp.replace('/age', 26);
///
/// // Remove a field
/// final op3 = PatchOp.remove('/temporary_field');
///
/// // Change a field (SurrealDB-specific)
/// final op4 = PatchOp.change('/status', 'active');
///
/// // Use in upsert
/// await db.upsert('person:alice').patch([op1, op2, op3]);
/// ```
class PatchOp {
  /// Creates a PatchOp with the given operation, path, and optional value.
  ///
  /// The [path] must be a JSON Pointer (RFC 6901) string starting with '/'.
  /// The [value] is required for add, replace, and change operations,
  /// but should be null for remove operations.
  ///
  /// Throws [ArgumentError] if path is invalid or if value requirements
  /// are not met for the operation type.
  PatchOp._(this.operation, this.path, [this.value]) {
    // Validate path format
    if (path.isEmpty) {
      throw ArgumentError('Path cannot be empty');
    }

    if (!path.startsWith('/')) {
      throw ArgumentError(
        'Path must start with "/" (JSON Pointer format): $path',
      );
    }

    // Validate value requirements
    if (operation != PatchOperation.remove && value == null) {
      throw ArgumentError(
        'Value is required for ${operation.name} operation',
      );
    }
  }

  /// Creates an "add" operation to add a value at the specified path.
  ///
  /// If the path points to an existing value, the behavior depends on the
  /// location:
  /// - For object members: the value is added or replaced
  /// - For arrays: the value is inserted at the index
  ///
  /// Example:
  /// ```dart
  /// final op = PatchOp.add('/email', 'user@example.com');
  /// final arrayOp = PatchOp.add('/tags/0', 'new-tag');
  /// ```
  factory PatchOp.add(String path, dynamic value) {
    return PatchOp._(PatchOperation.add, path, value);
  }

  /// Creates a "remove" operation to remove the value at the specified path.
  ///
  /// The path must exist in the document, otherwise the operation will fail.
  ///
  /// Example:
  /// ```dart
  /// final op = PatchOp.remove('/temporary_field');
  /// final arrayOp = PatchOp.remove('/tags/0');
  /// ```
  factory PatchOp.remove(String path) {
    return PatchOp._(PatchOperation.remove, path);
  }

  /// Creates a "replace" operation to replace the value at the specified path.
  ///
  /// The path must exist in the document, otherwise the operation will fail.
  ///
  /// Example:
  /// ```dart
  /// final op = PatchOp.replace('/age', 26);
  /// final nestedOp = PatchOp.replace('/address/city', 'New York');
  /// ```
  factory PatchOp.replace(String path, dynamic value) {
    return PatchOp._(PatchOperation.replace, path, value);
  }

  /// Creates a "change" operation (SurrealDB extension).
  ///
  /// Similar to replace, but may have different semantics in SurrealDB.
  /// Consult SurrealDB documentation for the exact behavior.
  ///
  /// Example:
  /// ```dart
  /// final op = PatchOp.change('/status', 'active');
  /// ```
  factory PatchOp.change(String path, dynamic value) {
    return PatchOp._(PatchOperation.change, path, value);
  }

  /// The patch operation type.
  final PatchOperation operation;

  /// The JSON Pointer path to the target location.
  ///
  /// Must start with '/' and follow JSON Pointer (RFC 6901) syntax.
  final String path;

  /// The value for the operation (null for remove operations).
  final dynamic value;

  /// Converts to JSON Patch format (RFC 6902).
  ///
  /// Returns a Map with "op", "path", and optionally "value" fields.
  ///
  /// Example:
  /// ```dart
  /// final op = PatchOp.add('/email', 'user@example.com');
  /// final json = op.toJson();
  /// // {
  /// //   "op": "add",
  /// //   "path": "/email",
  /// //   "value": "user@example.com"
  /// // }
  /// ```
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'op': operation.name,
      'path': path,
    };

    if (operation != PatchOperation.remove) {
      json['value'] = value;
    }

    return json;
  }

  @override
  String toString() {
    if (operation == PatchOperation.remove) {
      return 'PatchOp.${operation.name}($path)';
    }
    return 'PatchOp.${operation.name}($path, $value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PatchOp &&
        other.operation == operation &&
        other.path == path &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(operation, path, value);
}
