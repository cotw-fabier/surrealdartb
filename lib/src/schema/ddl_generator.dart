/// DDL generation for SurrealDB schema migrations.
///
/// This library provides tools for generating SurrealQL DDL statements from
/// schema diffs, including DEFINE TABLE, DEFINE FIELD, DEFINE INDEX, and
/// REMOVE statements for tables, fields, and indexes.
library;

import '../types/vector_value.dart';
import 'diff_engine.dart';
import 'surreal_types.dart';
import 'table_structure.dart';

/// Generates SurrealQL DDL statements for schema migrations.
///
/// This class converts schema diffs and table structures into executable
/// SurrealQL DDL statements, handling all schema elements including tables,
/// fields, indexes, constraints, and special types like vectors.
///
/// ## Basic Usage
///
/// ```dart
/// // Create diff between current and desired schemas
/// final diff = SchemaDiff.calculate(currentSchema, desiredTables);
///
/// // Generate DDL statements
/// final generator = DdlGenerator();
/// final ddl = generator.generateFromDiff(diff, desiredTables);
///
/// // Execute DDL statements
/// for (final statement in ddl) {
///   await db.query(statement);
/// }
/// ```
///
/// ## Statement Generation
///
/// The generator produces statements in dependency order:
/// 1. DEFINE TABLE statements (create tables first)
/// 2. DEFINE FIELD statements (add fields to tables)
/// 3. DEFINE INDEX statements (create indexes on fields)
/// 4. REMOVE INDEX statements (remove indexes before fields)
/// 5. REMOVE FIELD statements (remove fields before tables)
/// 6. REMOVE TABLE statements (remove tables last)
///
/// ## Special Type Handling
///
/// - **Vector types**: Generates `vector<FORMAT, DIMENSIONS>` syntax
/// - **ASSERT clauses**: Includes validation expressions with proper escaping
/// - **DEFAULT values**: Formats values based on type (strings quoted, bools/nums raw)
/// - **Optional fields**: Maps to `option<T>` type wrapper in SurrealDB
///
/// Example:
/// ```dart
/// // Vector field DDL
/// final vectorTable = TableStructure('documents', {
///   'embedding': FieldDefinition(VectorType.f32(1536)),
/// });
/// print(generator.generateDefineFields('documents', vectorTable.fields));
/// // Output: DEFINE FIELD embedding ON documents TYPE vector<F32, 1536>;
///
/// // Field with ASSERT and DEFAULT
/// final userTable = TableStructure('users', {
///   'age': FieldDefinition(
///     NumberType(format: NumberFormat.integer),
///     assertClause: r'$value >= 0 AND $value <= 150',
///     defaultValue: 0,
///   ),
/// });
/// // Output: DEFINE FIELD age ON users TYPE int ASSERT $value >= 0 AND $value <= 150 DEFAULT 0;
/// ```
class DdlGenerator {
  /// Creates a DDL generator.
  DdlGenerator();

  /// Generates complete DDL from a schema diff.
  ///
  /// Produces all necessary DDL statements to transform the current schema
  /// to match the desired schema, in the correct dependency order.
  ///
  /// [diff] - The schema diff containing all changes
  /// [desiredTables] - List of desired table structures for reference
  ///
  /// Returns a list of SurrealQL DDL statements ready for execution.
  ///
  /// Example:
  /// ```dart
  /// final diff = SchemaDiff.calculate(currentSchema, desiredTables);
  /// final generator = DdlGenerator();
  /// final statements = generator.generateFromDiff(diff, desiredTables);
  ///
  /// for (final stmt in statements) {
  ///   print(stmt);
  ///   await db.query(stmt);
  /// }
  /// ```
  List<String> generateFromDiff(
    SchemaDiff diff,
    List<TableStructure> desiredTables,
  ) {
    final statements = <String>[];

    // Build map of desired tables for quick lookup
    final desiredTableMap = <String, TableStructure>{};
    for (final table in desiredTables) {
      desiredTableMap[table.tableName] = table;
    }

    // Phase 1: Add new tables (DEFINE TABLE + all fields + indexes)
    for (final tableName in diff.tablesAdded) {
      final table = desiredTableMap[tableName];
      if (table != null) {
        // Define the table
        statements.add(generateDefineTable(table));

        // Define all fields for the new table
        for (final entry in table.fields.entries) {
          final fieldName = entry.key;
          final fieldDef = entry.value;
          statements.add(
            generateDefineField(tableName, fieldName, fieldDef),
          );
        }

        // Define all indexes for the new table
        for (final entry in table.fields.entries) {
          final fieldName = entry.key;
          final fieldDef = entry.value;
          if (fieldDef.indexed) {
            statements.add(generateDefineIndex(tableName, fieldName));
          }
        }
      }
    }

    // Phase 2: Add new fields to existing tables (DEFINE FIELD)
    // Skip newly added tables since their fields were already defined in Phase 1
    for (final entry in diff.fieldsAdded.entries) {
      final tableName = entry.key;
      final fieldNames = entry.value;
      final table = desiredTableMap[tableName];

      // Skip if this table was just added (already handled in Phase 1)
      if (diff.tablesAdded.contains(tableName)) {
        continue;
      }

      if (table != null) {
        for (final fieldName in fieldNames) {
          final fieldDef = table.fields[fieldName];
          if (fieldDef != null) {
            statements.add(
              generateDefineField(tableName, fieldName, fieldDef),
            );
          }
        }
      }
    }

    // Phase 3: Add modified fields (DEFINE FIELD with modifications)
    for (final entry in diff.fieldsModified.entries) {
      final tableName = entry.key;
      final modifications = entry.value;
      final table = desiredTableMap[tableName];

      if (table != null) {
        for (final mod in modifications) {
          final fieldDef = table.fields[mod.fieldName];
          if (fieldDef != null) {
            // Generate new DEFINE FIELD statement for modified field
            statements.add(
              generateDefineField(tableName, mod.fieldName, fieldDef),
            );
          }
        }
      }
    }

    // Phase 4: Add new indexes (DEFINE INDEX)
    // Skip newly added tables since their indexes were already defined in Phase 1
    for (final entry in diff.indexesAdded.entries) {
      final tableName = entry.key;
      final fieldNames = entry.value;

      // Skip if this table was just added (already handled in Phase 1)
      if (diff.tablesAdded.contains(tableName)) {
        continue;
      }

      for (final fieldName in fieldNames) {
        statements.add(generateDefineIndex(tableName, fieldName));
      }
    }

    // Phase 5: Remove indexes (REMOVE INDEX)
    // Skip tables that are being removed (they'll be removed entirely in Phase 7)
    for (final entry in diff.indexesRemoved.entries) {
      final tableName = entry.key;
      final fieldNames = entry.value;

      // Skip if this table will be removed (no need to remove indexes first)
      if (diff.tablesRemoved.contains(tableName)) {
        continue;
      }

      for (final fieldName in fieldNames) {
        statements.add(generateRemoveIndex(tableName, fieldName));
      }
    }

    // Phase 6: Remove fields (REMOVE FIELD)
    // Skip tables that are being removed (they'll be removed entirely in Phase 7)
    for (final entry in diff.fieldsRemoved.entries) {
      final tableName = entry.key;
      final fieldNames = entry.value;

      // Skip if this table will be removed (no need to remove fields first)
      if (diff.tablesRemoved.contains(tableName)) {
        continue;
      }

      for (final fieldName in fieldNames) {
        statements.add(generateRemoveField(tableName, fieldName));
      }
    }

    // Phase 7: Remove tables (REMOVE TABLE)
    for (final tableName in diff.tablesRemoved) {
      statements.add(generateRemoveTable(tableName));
    }

    return statements;
  }

  /// Generates a DEFINE TABLE statement.
  ///
  /// Creates a SurrealQL statement to define a new table with SCHEMAFULL mode,
  /// which enforces schema validation.
  ///
  /// [table] - The table structure to create
  ///
  /// Returns a DEFINE TABLE statement.
  ///
  /// Example:
  /// ```dart
  /// final table = TableStructure('users', {...});
  /// print(generator.generateDefineTable(table));
  /// // Output: DEFINE TABLE users SCHEMAFULL;
  /// ```
  String generateDefineTable(TableStructure table) {
    return 'DEFINE TABLE ${table.tableName} SCHEMAFULL';
  }

  /// Generates DEFINE FIELD statements for all fields in a table.
  ///
  /// Creates SurrealQL statements for all fields in the provided field map.
  ///
  /// [tableName] - The name of the table
  /// [fields] - Map of field names to their definitions
  ///
  /// Returns a list of DEFINE FIELD statements.
  ///
  /// Example:
  /// ```dart
  /// final fields = {
  ///   'name': FieldDefinition(StringType()),
  ///   'age': FieldDefinition(NumberType(format: NumberFormat.integer)),
  /// };
  /// final statements = generator.generateDefineFields('users', fields);
  /// ```
  List<String> generateDefineFields(
    String tableName,
    Map<String, FieldDefinition> fields,
  ) {
    final statements = <String>[];

    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final fieldDef = entry.value;
      statements.add(generateDefineField(tableName, fieldName, fieldDef));
    }

    return statements;
  }

  /// Generates a single DEFINE FIELD statement.
  ///
  /// Creates a SurrealQL statement to define a field with its type,
  /// constraints (ASSERT), default value, and optionality.
  ///
  /// [tableName] - The name of the table
  /// [fieldName] - The name of the field
  /// [fieldDef] - The field definition
  ///
  /// Returns a DEFINE FIELD statement.
  ///
  /// Example:
  /// ```dart
  /// final fieldDef = FieldDefinition(
  ///   NumberType(format: NumberFormat.integer),
  ///   assertClause: r'$value >= 0',
  ///   defaultValue: 0,
  /// );
  /// print(generator.generateDefineField('users', 'age', fieldDef));
  /// // Output: DEFINE FIELD age ON users TYPE int ASSERT $value >= 0 DEFAULT 0;
  /// ```
  String generateDefineField(
    String tableName,
    String fieldName,
    FieldDefinition fieldDef,
  ) {
    final buffer = StringBuffer();

    buffer.write('DEFINE FIELD $fieldName ON $tableName TYPE ');

    // Generate type string
    final typeStr = _generateTypeString(fieldDef.type, fieldDef.optional);
    buffer.write(typeStr);

    // Add ASSERT clause if present
    if (fieldDef.assertClause != null && fieldDef.assertClause!.isNotEmpty) {
      buffer.write(' ASSERT ${fieldDef.assertClause}');
    }

    // Add DEFAULT value if present
    if (fieldDef.defaultValue != null) {
      buffer.write(' DEFAULT ${_formatDefaultValue(fieldDef.defaultValue)}');
    }

    return buffer.toString();
  }

  /// Generates DEFINE INDEX statements for all indexed fields.
  ///
  /// Creates SurrealQL statements for all fields marked as indexed.
  ///
  /// [tableName] - The name of the table
  /// [fields] - Map of field names to their definitions
  ///
  /// Returns a list of DEFINE INDEX statements.
  ///
  /// Example:
  /// ```dart
  /// final fields = {
  ///   'email': FieldDefinition(StringType(), indexed: true),
  ///   'name': FieldDefinition(StringType()),
  /// };
  /// final statements = generator.generateDefineIndexes('users', fields);
  /// // Returns: ['DEFINE INDEX idx_users_email ON users FIELDS email;']
  /// ```
  List<String> generateDefineIndexes(
    String tableName,
    Map<String, FieldDefinition> fields,
  ) {
    final statements = <String>[];

    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final fieldDef = entry.value;

      if (fieldDef.indexed) {
        statements.add(generateDefineIndex(tableName, fieldName));
      }
    }

    return statements;
  }

  /// Generates a single DEFINE INDEX statement.
  ///
  /// Creates a SurrealQL statement to define an index on a field.
  /// The index name follows the convention: `idx_{tableName}_{fieldName}`.
  ///
  /// [tableName] - The name of the table
  /// [fieldName] - The name of the field to index
  ///
  /// Returns a DEFINE INDEX statement.
  ///
  /// Example:
  /// ```dart
  /// print(generator.generateDefineIndex('users', 'email'));
  /// // Output: DEFINE INDEX idx_users_email ON users FIELDS email;
  /// ```
  String generateDefineIndex(String tableName, String fieldName) {
    final indexName = 'idx_${tableName}_$fieldName';
    return 'DEFINE INDEX $indexName ON $tableName FIELDS $fieldName';
  }

  /// Generates a REMOVE TABLE statement.
  ///
  /// Creates a SurrealQL statement to remove a table and all its data.
  ///
  /// [tableName] - The name of the table to remove
  ///
  /// Returns a REMOVE TABLE statement.
  ///
  /// Example:
  /// ```dart
  /// print(generator.generateRemoveTable('old_users'));
  /// // Output: REMOVE TABLE old_users;
  /// ```
  String generateRemoveTable(String tableName) {
    return 'REMOVE TABLE $tableName';
  }

  /// Generates a REMOVE FIELD statement.
  ///
  /// Creates a SurrealQL statement to remove a field from a table.
  ///
  /// [tableName] - The name of the table
  /// [fieldName] - The name of the field to remove
  ///
  /// Returns a REMOVE FIELD statement.
  ///
  /// Example:
  /// ```dart
  /// print(generator.generateRemoveField('users', 'deprecated_field'));
  /// // Output: REMOVE FIELD deprecated_field ON users;
  /// ```
  String generateRemoveField(String tableName, String fieldName) {
    return 'REMOVE FIELD $fieldName ON $tableName';
  }

  /// Generates a REMOVE INDEX statement.
  ///
  /// Creates a SurrealQL statement to remove an index from a table.
  /// Uses the same index naming convention as [generateDefineIndex].
  ///
  /// [tableName] - The name of the table
  /// [fieldName] - The name of the field that was indexed
  ///
  /// Returns a REMOVE INDEX statement.
  ///
  /// Example:
  /// ```dart
  /// print(generator.generateRemoveIndex('users', 'email'));
  /// // Output: REMOVE INDEX idx_users_email ON users;
  /// ```
  String generateRemoveIndex(String tableName, String fieldName) {
    final indexName = 'idx_${tableName}_$fieldName';
    return 'REMOVE INDEX $indexName ON $tableName';
  }

  /// Generates a SurrealDB type string from a SurrealType.
  ///
  /// Handles optionality by wrapping the type in `option<T>` if needed.
  ///
  /// [type] - The SurrealType to convert
  /// [optional] - Whether the field is optional
  ///
  /// Returns the SurrealQL type string.
  String _generateTypeString(SurrealType type, bool optional) {
    final baseType = _surrealTypeToString(type);

    // Wrap in option<T> if optional
    if (optional) {
      return 'option<$baseType>';
    }

    return baseType;
  }

  /// Converts a SurrealType to its SurrealQL string representation.
  ///
  /// Uses pattern matching to handle all type variants.
  String _surrealTypeToString(SurrealType type) {
    return switch (type) {
      StringType() => 'string',
      NumberType(format: final fmt) => _numberFormatToString(fmt),
      BoolType() => 'bool',
      DatetimeType() => 'datetime',
      DurationType() => 'duration',
      ArrayType(elementType: final elemType, length: final len) => len != null
          ? 'array<${_surrealTypeToString(elemType)}, $len>'
          : 'array<${_surrealTypeToString(elemType)}>',
      ObjectType() => 'object',
      RecordType(table: final tbl) => tbl != null ? 'record<$tbl>' : 'record',
      GeometryType() => 'geometry',
      VectorType(format: final fmt, dimensions: final dims) =>
        _vectorTypeToString(fmt, dims),
      AnyType() => 'any',
    };
  }

  /// Converts NumberFormat to SurrealQL type string.
  String _numberFormatToString(NumberFormat? format) {
    if (format == null) return 'number';
    return switch (format) {
      NumberFormat.integer => 'int',
      NumberFormat.floating => 'float',
      NumberFormat.decimal => 'decimal',
    };
  }

  /// Converts VectorType to SurrealQL vector type string.
  ///
  /// Generates the format: `vector<FORMAT, DIMENSIONS>`
  String _vectorTypeToString(VectorFormat format, int dimensions) {
    final formatStr = switch (format) {
      VectorFormat.f32 => 'F32',
      VectorFormat.f64 => 'F64',
      VectorFormat.i8 => 'I8',
      VectorFormat.i16 => 'I16',
      VectorFormat.i32 => 'I32',
      VectorFormat.i64 => 'I64',
    };
    return 'vector<$formatStr, $dimensions>';
  }

  /// Formats a default value for inclusion in DDL.
  ///
  /// Handles different value types:
  /// - Strings: Wrapped in single quotes with escaping
  /// - Booleans: Lowercase true/false
  /// - Numbers: Raw value
  /// - null: NONE keyword
  ///
  /// [value] - The default value to format
  ///
  /// Returns the formatted value string.
  String _formatDefaultValue(dynamic value) {
    if (value == null) {
      return 'NONE';
    } else if (value is String) {
      // Escape single quotes and wrap in quotes
      final escaped = value.replaceAll("'", "\\'");
      return "'$escaped'";
    } else if (value is bool) {
      return value.toString();
    } else if (value is num) {
      return value.toString();
    } else {
      // For complex values, convert to string and quote
      final str = value.toString();
      final escaped = str.replaceAll("'", "\\'");
      return "'$escaped'";
    }
  }
}
