/// Table structure definition for schema validation.
///
/// This library provides the TableStructure class which defines table schemas
/// with field validation, supporting all SurrealDB data types including vectors.
library;

import '../exceptions.dart';
import '../types/vector_value.dart';
import 'surreal_types.dart';

/// Represents a table schema with field definitions and validation logic.
///
/// TableStructure provides a way to define the structure of a SurrealDB table
/// in Dart, enabling compile-time type safety and runtime validation before
/// data is sent to the database.
///
/// ## Features
///
/// - **Field Validation**: Validate data conforms to field types
/// - **Required/Optional Fields**: Enforce required fields and handle optional ones
/// - **Vector Validation**: Validate vector dimensions and normalization
/// - **Nested Schemas**: Support complex nested object structures
/// - **Type Safety**: Leverage Dart's type system for schema definitions
///
/// ## Basic Usage
///
/// ```dart
/// // Define a simple table schema
/// final schema = TableStructure('users', {
///   'name': FieldDefinition(StringType()),
///   'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
///   'email': FieldDefinition(StringType(), optional: true),
/// });
///
/// // Validate data
/// final userData = {'name': 'Alice', 'age': 30};
/// schema.validate(userData); // Passes validation
///
/// final invalidData = {'name': 'Bob'}; // Missing required 'age'
/// schema.validate(invalidData); // Throws ValidationException
/// ```
///
/// ## Vector Field Example
///
/// ```dart
/// // Define table with vector embedding
/// final docSchema = TableStructure('documents', {
///   'title': FieldDefinition(StringType()),
///   'content': FieldDefinition(StringType()),
///   'embedding': FieldDefinition(
///     VectorType.f32(1536, normalized: true),
///     optional: false,
///   ),
/// });
///
/// // Create vector data
/// final embedding = VectorValue.fromList(List.filled(1536, 0.1));
/// final doc = {
///   'title': 'Test Document',
///   'content': 'Content here',
///   'embedding': embedding.toJson(),
/// };
///
/// // Validate before insert
/// docSchema.validate(doc); // Checks dimensions and normalization
/// ```
///
/// ## Nested Object Example
///
/// ```dart
/// // Define table with nested object schema
/// final schema = TableStructure('products', {
///   'name': FieldDefinition(StringType()),
///   'price': FieldDefinition(NumberType(format: NumberFormat.decimal)),
///   'metadata': FieldDefinition(
///     ObjectType(schema: {
///       'category': FieldDefinition(StringType()),
///       'tags': FieldDefinition(ArrayType(StringType()), optional: true),
///     }),
///     optional: true,
///   ),
/// });
/// ```
class TableStructure {
  /// Creates a table structure with field definitions.
  ///
  /// [tableName] - The name of the table (must be non-empty and valid identifier)
  /// [fields] - Map of field names to their definitions
  ///
  /// Throws [ArgumentError] if [tableName] is empty or contains invalid characters.
  ///
  /// Example:
  /// ```dart
  /// final schema = TableStructure('users', {
  ///   'id': FieldDefinition(RecordType(table: 'users')),
  ///   'name': FieldDefinition(StringType()),
  ///   'created_at': FieldDefinition(DatetimeType()),
  /// });
  /// ```
  TableStructure(this.tableName, this.fields) {
    if (tableName.trim().isEmpty) {
      throw ArgumentError('Table name cannot be empty');
    }

    // Validate table name is a valid identifier (alphanumeric and underscore)
    final validNamePattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
    if (!validNamePattern.hasMatch(tableName)) {
      throw ArgumentError(
        'Table name must be a valid identifier (alphanumeric and underscore only): $tableName',
      );
    }
  }

  /// The name of the table.
  ///
  /// Must be a valid SurrealDB table identifier (alphanumeric and underscore).
  final String tableName;

  /// Map of field names to their field definitions.
  ///
  /// Each entry defines the type and constraints for a field in the table.
  final Map<String, FieldDefinition> fields;

  /// Validates data against the table schema.
  ///
  /// Checks that:
  /// - All required fields are present (unless [partial] is true)
  /// - Optional fields (if present) conform to their types
  /// - Vector fields have correct dimensions and normalization
  /// - Nested objects conform to their schemas
  ///
  /// Parameters:
  /// - [data] - The data to validate
  /// - [partial] - If true, only validates fields present in the data
  ///   (default: true). Set to false to require all required fields.
  ///   Use partial: true for UPDATE operations, partial: false for CREATE.
  ///
  /// Throws [ValidationException] if validation fails, with field-level details.
  ///
  /// Example:
  /// ```dart
  /// final schema = TableStructure('users', {
  ///   'name': FieldDefinition(StringType()),
  ///   'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  /// });
  ///
  /// // Partial validation (default) - OK for updates
  /// schema.validate({'age': 31}); // OK - only validates present fields
  ///
  /// // Full validation - for creates
  /// try {
  ///   schema.validate({'name': 'Bob'}, partial: false); // Missing required 'age'
  /// } catch (e) {
  ///   print(e); // ValidationException: Required field 'age' is missing
  /// }
  /// ```
  void validate(Map<String, dynamic> data, {bool partial = true}) {
    // Check all fields
    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final fieldDef = entry.value;
      final value = data[fieldName];

      // Check required fields (only if not partial validation)
      if (!partial && !fieldDef.optional && value == null) {
        throw ValidationException(
          "Required field '$fieldName' is missing",
          fieldName: fieldName,
          constraint: 'required',
        );
      }

      // Validate field if present (or if required)
      if (value != null) {
        _validateField(fieldName, fieldDef, value);
      }
    }
  }

  /// Validates a specific field against its definition.
  ///
  /// Uses pattern matching on the SurrealType to apply type-specific validation.
  void _validateField(String fieldName, FieldDefinition fieldDef, dynamic value) {
    final type = fieldDef.type;

    switch (type) {
      case VectorType():
        _validateVectorField(fieldName, type, value);
      case ArrayType():
        _validateArrayField(fieldName, type, value);
      case ObjectType():
        _validateObjectField(fieldName, type, value);
      case RecordType():
        _validateRecordField(fieldName, type, value);
      case StringType():
        _validateStringField(fieldName, value);
      case NumberType():
        _validateNumberField(fieldName, type, value);
      case BoolType():
        _validateBoolField(fieldName, value);
      case DatetimeType():
        _validateDatetimeField(fieldName, value);
      case DurationType():
        _validateDurationField(fieldName, value);
      case GeometryType():
        _validateGeometryField(fieldName, value);
      case AnyType():
        // AnyType accepts any value, no validation needed
        break;
    }
  }

  /// Validates a vector field.
  void _validateVectorField(String fieldName, VectorType vectorType, dynamic value) {
    // Try to convert value to VectorValue
    VectorValue vector;
    try {
      if (value is VectorValue) {
        vector = value;
      } else if (value is List) {
        vector = VectorValue.fromJson(value, format: vectorType.format);
      } else {
        throw ValidationException(
          "Field '$fieldName' must be a vector (List or VectorValue), got ${value.runtimeType}",
          fieldName: fieldName,
          constraint: 'type_mismatch',
        );
      }
    } catch (e) {
      throw ValidationException(
        "Field '$fieldName' failed to convert to VectorValue: $e",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }

    // Validate dimensions
    if (!vector.validateDimensions(vectorType.dimensions)) {
      throw ValidationException(
        "Field '$fieldName' has ${vector.dimensions} dimensions, expected ${vectorType.dimensions}",
        fieldName: fieldName,
        constraint: 'dimension_mismatch',
      );
    }

    // Validate normalization if required
    if (vectorType.normalized && !vector.isNormalized()) {
      throw ValidationException(
        "Field '$fieldName' must be normalized (magnitude 1.0)",
        fieldName: fieldName,
        constraint: 'not_normalized',
      );
    }

    // Validate format matches
    if (vector.format != vectorType.format) {
      throw ValidationException(
        "Field '$fieldName' has format ${vector.format}, expected ${vectorType.format}",
        fieldName: fieldName,
        constraint: 'format_mismatch',
      );
    }
  }

  /// Validates an array field.
  void _validateArrayField(String fieldName, ArrayType arrayType, dynamic value) {
    if (value is! List) {
      throw ValidationException(
        "Field '$fieldName' must be a List, got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }

    // Validate fixed length if specified
    if (arrayType.length != null && value.length != arrayType.length) {
      throw ValidationException(
        "Field '$fieldName' must have exactly ${arrayType.length} elements, got ${value.length}",
        fieldName: fieldName,
        constraint: 'length_mismatch',
      );
    }

    // Validate each element matches the element type
    for (var i = 0; i < value.length; i++) {
      final element = value[i];
      final elementFieldDef = FieldDefinition(arrayType.elementType);
      try {
        _validateField('$fieldName[$i]', elementFieldDef, element);
      } catch (e) {
        if (e is ValidationException) {
          rethrow;
        }
        throw ValidationException(
          "Field '$fieldName[$i]' validation failed: $e",
          fieldName: '$fieldName[$i]',
          constraint: 'element_validation_failed',
        );
      }
    }
  }

  /// Validates an object field.
  void _validateObjectField(String fieldName, ObjectType objectType, dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw ValidationException(
        "Field '$fieldName' must be a Map, got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }

    // If schema is defined, validate nested fields
    if (objectType.schema != null) {
      for (final entry in objectType.schema!.entries) {
        final nestedFieldName = entry.key;
        final nestedFieldDef = entry.value;
        final nestedValue = value[nestedFieldName];

        // Check required nested fields
        if (!nestedFieldDef.optional && nestedValue == null) {
          throw ValidationException(
            "Required nested field '$fieldName.$nestedFieldName' is missing",
            fieldName: '$fieldName.$nestedFieldName',
            constraint: 'required',
          );
        }

        // Validate nested field if present
        if (nestedValue != null) {
          _validateField('$fieldName.$nestedFieldName', nestedFieldDef, nestedValue);
        }
      }
    }
  }

  /// Validates a record field.
  void _validateRecordField(String fieldName, RecordType recordType, dynamic value) {
    if (value is! String) {
      throw ValidationException(
        "Field '$fieldName' must be a String (record ID), got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }

    // Validate record format: "table:id"
    final parts = value.split(':');
    if (parts.length != 2) {
      throw ValidationException(
        "Field '$fieldName' must be in format 'table:id', got '$value'",
        fieldName: fieldName,
        constraint: 'invalid_record_format',
      );
    }

    // Validate table constraint if specified
    if (recordType.table != null && parts[0] != recordType.table) {
      throw ValidationException(
        "Field '$fieldName' must be from table '${recordType.table}', got '${parts[0]}'",
        fieldName: fieldName,
        constraint: 'table_mismatch',
      );
    }
  }

  /// Validates a string field.
  void _validateStringField(String fieldName, dynamic value) {
    if (value is! String) {
      throw ValidationException(
        "Field '$fieldName' must be a String, got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }
  }

  /// Validates a number field.
  void _validateNumberField(String fieldName, NumberType numberType, dynamic value) {
    if (value is! num) {
      throw ValidationException(
        "Field '$fieldName' must be a number, got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }

    // Validate format if specified
    if (numberType.format != null) {
      switch (numberType.format!) {
        case NumberFormat.integer:
          if (value is! int) {
            throw ValidationException(
              "Field '$fieldName' must be an integer, got ${value.runtimeType}",
              fieldName: fieldName,
              constraint: 'format_mismatch',
            );
          }
        case NumberFormat.floating:
          if (value is! double) {
            throw ValidationException(
              "Field '$fieldName' must be a floating-point number, got ${value.runtimeType}",
              fieldName: fieldName,
              constraint: 'format_mismatch',
            );
          }
        case NumberFormat.decimal:
          // Decimal validation - accept any num for now
          // In practice, this would require a Decimal type
          break;
      }
    }
  }

  /// Validates a boolean field.
  void _validateBoolField(String fieldName, dynamic value) {
    if (value is! bool) {
      throw ValidationException(
        "Field '$fieldName' must be a bool, got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }
  }

  /// Validates a datetime field.
  void _validateDatetimeField(String fieldName, dynamic value) {
    if (value is! DateTime && value is! String) {
      throw ValidationException(
        "Field '$fieldName' must be a DateTime or ISO 8601 string, got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }

    // If string, try to parse as DateTime
    if (value is String) {
      try {
        DateTime.parse(value);
      } catch (e) {
        throw ValidationException(
          "Field '$fieldName' is not a valid ISO 8601 datetime string: $value",
          fieldName: fieldName,
          constraint: 'invalid_datetime_format',
        );
      }
    }
  }

  /// Validates a duration field.
  void _validateDurationField(String fieldName, dynamic value) {
    if (value is! Duration && value is! String) {
      throw ValidationException(
        "Field '$fieldName' must be a Duration or duration string, got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }
  }

  /// Validates a geometry field.
  void _validateGeometryField(String fieldName, dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw ValidationException(
        "Field '$fieldName' must be a Map (GeoJSON), got ${value.runtimeType}",
        fieldName: fieldName,
        constraint: 'type_mismatch',
      );
    }

    // Basic GeoJSON validation
    if (!value.containsKey('type') || !value.containsKey('coordinates')) {
      throw ValidationException(
        "Field '$fieldName' must have 'type' and 'coordinates' properties (GeoJSON)",
        fieldName: fieldName,
        constraint: 'invalid_geometry_format',
      );
    }
  }

  /// Checks if a field is defined in the schema.
  ///
  /// Returns `true` if the field exists, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final schema = TableStructure('users', {
  ///   'name': FieldDefinition(StringType()),
  /// });
  ///
  /// print(schema.hasField('name'));  // true
  /// print(schema.hasField('age'));   // false
  /// ```
  bool hasField(String fieldName) => fields.containsKey(fieldName);

  /// Gets the field definition for a specific field.
  ///
  /// Returns the [FieldDefinition] if found, `null` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final schema = TableStructure('users', {
  ///   'name': FieldDefinition(StringType()),
  /// });
  ///
  /// final nameDef = schema.getField('name');
  /// print(nameDef?.type); // StringType
  /// ```
  FieldDefinition? getField(String fieldName) => fields[fieldName];

  /// Returns a list of all required field names.
  ///
  /// Example:
  /// ```dart
  /// final schema = TableStructure('users', {
  ///   'name': FieldDefinition(StringType()),
  ///   'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  ///   'email': FieldDefinition(StringType(), optional: true),
  /// });
  ///
  /// print(schema.getRequiredFields()); // ['name', 'age']
  /// ```
  List<String> getRequiredFields() {
    return fields.entries
        .where((entry) => !entry.value.optional)
        .map((entry) => entry.key)
        .toList();
  }

  /// Returns a list of all optional field names.
  ///
  /// Example:
  /// ```dart
  /// final schema = TableStructure('users', {
  ///   'name': FieldDefinition(StringType()),
  ///   'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  ///   'email': FieldDefinition(StringType(), optional: true),
  /// });
  ///
  /// print(schema.getOptionalFields()); // ['email']
  /// ```
  List<String> getOptionalFields() {
    return fields.entries
        .where((entry) => entry.value.optional)
        .map((entry) => entry.key)
        .toList();
  }

  /// Generates a SurrealQL DEFINE TABLE statement for this schema.
  ///
  /// This is an experimental feature that converts the Dart schema definition
  /// into SurrealDB DDL syntax.
  ///
  /// Note: This is marked as experimental and may not cover all edge cases.
  /// Use with caution for production schemas.
  ///
  /// Example:
  /// ```dart
  /// final schema = TableStructure('users', {
  ///   'name': FieldDefinition(StringType()),
  ///   'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  /// });
  ///
  /// print(schema.toSurrealQL());
  /// // Output:
  /// // DEFINE TABLE users SCHEMAFULL;
  /// // DEFINE FIELD name ON TABLE users TYPE string;
  /// // DEFINE FIELD age ON TABLE users TYPE int;
  /// ```
  String toSurrealQL() {
    final buffer = StringBuffer();

    // Table definition
    buffer.writeln('DEFINE TABLE $tableName SCHEMAFULL;');

    // Field definitions
    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final fieldDef = entry.value;

      buffer.write('DEFINE FIELD $fieldName ON TABLE $tableName TYPE ');
      buffer.write(_typeToSurrealQL(fieldDef.type));

      // Add optional constraint
      if (!fieldDef.optional) {
        buffer.write(' ASSERT \$value != NONE');
      }

      buffer.writeln(';');
    }

    return buffer.toString();
  }

  /// Converts a SurrealType to SurrealQL type syntax.
  String _typeToSurrealQL(SurrealType type) {
    return switch (type) {
      StringType() => 'string',
      NumberType(format: final fmt) => _numberFormatToSurrealQL(fmt),
      BoolType() => 'bool',
      DatetimeType() => 'datetime',
      DurationType() => 'duration',
      ArrayType(elementType: final elemType, length: final len) =>
        len != null
            ? 'array<${_typeToSurrealQL(elemType)}, $len>'
            : 'array<${_typeToSurrealQL(elemType)}>',
      ObjectType() => 'object',
      RecordType(table: final tbl) =>
        tbl != null ? 'record<$tbl>' : 'record',
      GeometryType() => 'geometry',
      VectorType(format: final fmt, dimensions: final dims, normalized: final norm) =>
        _vectorTypeToSurrealQL(fmt, dims, norm),
      AnyType() => 'any',
    };
  }

  /// Converts NumberFormat to SurrealQL number type.
  String _numberFormatToSurrealQL(NumberFormat? format) {
    if (format == null) return 'number';
    return switch (format) {
      NumberFormat.integer => 'int',
      NumberFormat.floating => 'float',
      NumberFormat.decimal => 'decimal',
    };
  }

  /// Converts VectorType to SurrealQL vector type syntax.
  String _vectorTypeToSurrealQL(VectorFormat format, int dimensions, bool normalized) {
    final formatStr = switch (format) {
      VectorFormat.f32 => 'F32',
      VectorFormat.f64 => 'F64',
      VectorFormat.i8 => 'I8',
      VectorFormat.i16 => 'I16',
      VectorFormat.i32 => 'I32',
      VectorFormat.i64 => 'I64',
    };

    // SurrealDB vector syntax: vector<F32, 1536>
    // Normalization is a runtime constraint, not part of type definition
    return 'vector<$formatStr, $dimensions>';
  }
}
