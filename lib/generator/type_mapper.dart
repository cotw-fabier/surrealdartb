/// Type mapping utilities for converting Dart types to SurrealDB types.
///
/// This library provides functionality to map Dart primitive types to their
/// corresponding SurrealDB type expressions for code generation.
library;

/// Maps Dart types to SurrealDB type expressions.
///
/// This class provides the core type mapping logic for the build_runner
/// generator, converting Dart type names to constructor calls for SurrealType
/// objects.
///
/// ## Supported Mappings
///
/// - `String` → `StringType()`
/// - `int` → `NumberType(format: NumberFormat.integer)`
/// - `double` → `NumberType(format: NumberFormat.floating)`
/// - `bool` → `BoolType()`
/// - `DateTime` → `DatetimeType()`
/// - `Duration` → `DurationType()`
///
/// ## Example Usage
///
/// ```dart
/// final mapper = TypeMapper();
/// final surrealType = mapper.mapDartTypeToSurreal('String');
/// // Returns: 'StringType()'
/// ```
class TypeMapper {
  /// Maps for basic Dart types to SurrealDB type expressions.
  static const Map<String, String> _basicTypeMap = {
    'String': 'StringType()',
    'int': 'NumberType(format: NumberFormat.integer)',
    'double': 'NumberType(format: NumberFormat.floating)',
    'bool': 'BoolType()',
    'DateTime': 'DatetimeType()',
    'Duration': 'DurationType()',
  };

  /// Maps a Dart type name to a SurrealDB type expression.
  ///
  /// Takes a Dart type name as a string and returns the corresponding
  /// SurrealDB type constructor expression.
  ///
  /// Throws [UnsupportedTypeException] if the type is not supported.
  ///
  /// Example:
  /// ```dart
  /// mapper.mapDartTypeToSurreal('String');  // Returns: 'StringType()'
  /// mapper.mapDartTypeToSurreal('int');     // Returns: 'NumberType(format: NumberFormat.integer)'
  /// ```
  String mapDartTypeToSurreal(String dartType) {
    final surrealType = _basicTypeMap[dartType];

    if (surrealType == null) {
      throw UnsupportedTypeException(
        'Type "$dartType" is not currently supported for basic type mapping. '
        'Supported types: ${_basicTypeMap.keys.join(', ')}',
        dartType,
      );
    }

    return surrealType;
  }
}

/// Exception thrown when attempting to map an unsupported Dart type.
///
/// This exception is thrown by [TypeMapper] when a Dart type cannot be
/// mapped to a SurrealDB type.
class UnsupportedTypeException implements Exception {
  /// Creates an UnsupportedTypeException.
  ///
  /// [message] - Human-readable error message
  /// [dartType] - The Dart type name that was not supported
  UnsupportedTypeException(this.message, this.dartType);

  /// Human-readable error message explaining the issue.
  final String message;

  /// The Dart type name that caused the exception.
  final String dartType;

  @override
  String toString() => 'UnsupportedTypeException: $message';
}
