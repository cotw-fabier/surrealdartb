/// Type mapping utilities for converting Dart types to SurrealDB types.
///
/// This library provides functionality to map Dart primitive types and
/// collection types to their corresponding SurrealDB type expressions
/// for code generation.
library;

/// Maps Dart types to SurrealDB type expressions.
///
/// This class provides the core type mapping logic for the build_runner
/// generator, converting Dart type names to constructor calls for SurrealType
/// objects.
///
/// ## Supported Mappings
///
/// ### Basic Types
/// - `String` → `StringType()`
/// - `int` → `NumberType(format: NumberFormat.integer)`
/// - `double` → `NumberType(format: NumberFormat.floating)`
/// - `bool` → `BoolType()`
/// - `DateTime` → `DatetimeType()`
/// - `Duration` → `DurationType()`
///
/// ### Collection Types
/// - `List<T>` → `ArrayType(T)`
/// - `Set<T>` → `ArrayType(T)` (sets map to arrays in SurrealDB)
/// - `Map<String, dynamic>` → `ObjectType()`
/// - `Map` → `ObjectType()`
///
/// ## Example Usage
///
/// ```dart
/// final mapper = TypeMapper();
/// final surrealType = mapper.mapDartTypeToSurreal('String');
/// // Returns: 'StringType()'
///
/// final listType = mapper.mapDartTypeToSurreal('List<String>');
/// // Returns: 'ArrayType(StringType())'
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
  /// Supports:
  /// - Basic types (String, int, double, bool, DateTime, Duration)
  /// - Collections (List<T>, Set<T>, Map<String, dynamic>)
  /// - Nested collections (List<List<int>>)
  ///
  /// Throws [UnsupportedTypeException] if the type is not supported.
  ///
  /// Example:
  /// ```dart
  /// mapper.mapDartTypeToSurreal('String');  // Returns: 'StringType()'
  /// mapper.mapDartTypeToSurreal('int');     // Returns: 'NumberType(format: NumberFormat.integer)'
  /// mapper.mapDartTypeToSurreal('List<String>');  // Returns: 'ArrayType(StringType())'
  /// ```
  String mapDartTypeToSurreal(String dartType) {
    // Remove whitespace for consistent parsing
    final cleanType = dartType.replaceAll(' ', '');

    // Check for basic types first
    final basicType = _basicTypeMap[cleanType];
    if (basicType != null) {
      return basicType;
    }

    // Check for List<T>
    if (cleanType.startsWith('List<') && cleanType.endsWith('>')) {
      final elementType = _extractGenericType(cleanType, 'List');
      final elementTypeExpr = mapDartTypeToSurreal(elementType);
      return 'ArrayType($elementTypeExpr)';
    }

    // Check for Set<T>
    if (cleanType.startsWith('Set<') && cleanType.endsWith('>')) {
      final elementType = _extractGenericType(cleanType, 'Set');
      final elementTypeExpr = mapDartTypeToSurreal(elementType);
      return 'ArrayType($elementTypeExpr)';
    }

    // Check for List without type parameter (List -> List<dynamic>)
    if (cleanType == 'List') {
      return 'ArrayType(AnyType())';
    }

    // Check for Set without type parameter (Set -> Set<dynamic>)
    if (cleanType == 'Set') {
      return 'ArrayType(AnyType())';
    }

    // Check for Map<String, dynamic> or Map
    if (cleanType.startsWith('Map<') || cleanType == 'Map') {
      return 'ObjectType()';
    }

    // Type not found in mappings - likely a custom class
    throw UnsupportedTypeException(
      'Type "$dartType" is not a built-in type. '
      'For custom classes, use ObjectType() with @SurrealField annotation. '
      'Supported basic types: ${_basicTypeMap.keys.join(', ')}. '
      'Supported collections: List<T>, Set<T>, Map',
      dartType,
    );
  }

  /// Extracts the generic type parameter from a generic type string.
  ///
  /// Example:
  /// ```dart
  /// _extractGenericType('List<String>', 'List')  // Returns: 'String'
  /// _extractGenericType('List<List<int>>', 'List')  // Returns: 'List<int>'
  /// ```
  String _extractGenericType(String genericType, String containerType) {
    // Find the opening bracket
    final startIndex = genericType.indexOf('<');
    if (startIndex == -1) {
      throw ArgumentError('Invalid generic type: $genericType');
    }

    // Find the matching closing bracket (handle nested generics)
    var depth = 0;
    var endIndex = startIndex;

    for (var i = startIndex; i < genericType.length; i++) {
      if (genericType[i] == '<') {
        depth++;
      } else if (genericType[i] == '>') {
        depth--;
        if (depth == 0) {
          endIndex = i;
          break;
        }
      }
    }

    if (depth != 0) {
      throw ArgumentError('Unbalanced brackets in generic type: $genericType');
    }

    // Extract the content between brackets
    final typeParam = genericType.substring(startIndex + 1, endIndex);

    // Handle empty type parameter (e.g., List<>)
    if (typeParam.isEmpty) {
      return 'dynamic';
    }

    return typeParam;
  }
}

/// Exception thrown when attempting to map an unsupported Dart type.
///
/// This exception is thrown by [TypeMapper] when a Dart type cannot be
/// mapped to a SurrealDB type. This typically means:
/// - The type is a custom class (should use ObjectType with schema)
/// - The type is not yet supported (future enhancement needed)
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
