/// Schema introspection for detecting database schema state.
///
/// This library provides tools for querying and parsing SurrealDB schema
/// information using INFO FOR DB and INFO FOR TABLE queries, building
/// snapshot representations of the current database schema.
library;

import 'dart:convert';

import '../database.dart';
import '../exceptions.dart';

/// Represents a complete database schema snapshot.
///
/// This class captures the entire database schema state at a point in time,
/// including all tables, fields, indexes, and constraints. Used for schema
/// diffing and migration detection.
///
/// Example:
/// ```dart
/// final snapshot = await DatabaseSchema.introspect(db);
/// print('Database has ${snapshot.tables.length} tables');
/// for (final table in snapshot.tables.values) {
///   print('Table: ${table.name} with ${table.fields.length} fields');
/// }
/// ```
class DatabaseSchema {
  /// Creates a database schema snapshot.
  ///
  /// [tables] - Map of table names to their schema definitions
  DatabaseSchema(this.tables);

  /// Map of table names to their schema definitions.
  ///
  /// The key is the table name, and the value contains the complete
  /// table schema including fields, indexes, and constraints.
  final Map<String, TableSchema> tables;

  /// Introspects the current database schema using INFO FOR DB.
  ///
  /// Executes an INFO FOR DB query to retrieve the complete database schema,
  /// then parses the response to build a structured representation.
  ///
  /// [db] - The database connection to introspect
  ///
  /// Returns a DatabaseSchema snapshot of the current state.
  ///
  /// Throws [SchemaIntrospectionException] if introspection fails.
  ///
  /// Example:
  /// ```dart
  /// final snapshot = await DatabaseSchema.introspect(db);
  /// if (snapshot.tables.containsKey('users')) {
  ///   print('Users table exists');
  /// }
  /// ```
  static Future<DatabaseSchema> introspect(Database db) async {
    try {
      // Execute INFO FOR DB query
      final response = await db.query('INFO FOR DB');
      final results = response.getResults();

      if (results.isEmpty) {
        throw SchemaIntrospectionException(
          'INFO FOR DB returned no results',
        );
      }

      final dbInfo = results.first as Map<String, dynamic>;

      // Parse tables from response
      final tables = <String, TableSchema>{};

      if (dbInfo.containsKey('tables')) {
        final tablesInfo = dbInfo['tables'] as Map<String, dynamic>;

        // For each table, fetch detailed schema using INFO FOR TABLE
        for (final tableName in tablesInfo.keys) {
          // Skip system tables (those starting with underscore)
          if (tableName.startsWith('_')) {
            continue;
          }

          try {
            final tableSchema = await TableSchema.introspect(db, tableName);
            tables[tableName] = tableSchema;
          } catch (e) {
            throw SchemaIntrospectionException(
              'Failed to introspect table "$tableName": $e',
            );
          }
        }
      }

      return DatabaseSchema(tables);
    } catch (e) {
      if (e is SchemaIntrospectionException) {
        rethrow;
      }
      throw SchemaIntrospectionException(
        'Failed to introspect database schema: $e',
      );
    }
  }

  /// Serializes the schema snapshot to JSON for storage.
  ///
  /// Returns a JSON-serializable map representation of the schema.
  ///
  /// Example:
  /// ```dart
  /// final snapshot = await DatabaseSchema.introspect(db);
  /// final json = snapshot.toJson();
  /// await storage.save('schema_snapshot.json', jsonEncode(json));
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'tables': tables.map((name, schema) => MapEntry(name, schema.toJson())),
    };
  }

  /// Deserializes a schema snapshot from JSON.
  ///
  /// [json] - The JSON map to deserialize
  ///
  /// Returns a DatabaseSchema instance.
  ///
  /// Example:
  /// ```dart
  /// final json = jsonDecode(await storage.load('schema_snapshot.json'));
  /// final snapshot = DatabaseSchema.fromJson(json);
  /// ```
  factory DatabaseSchema.fromJson(Map<String, dynamic> json) {
    final tables = <String, TableSchema>{};

    if (json.containsKey('tables')) {
      final tablesJson = json['tables'] as Map<String, dynamic>;
      for (final entry in tablesJson.entries) {
        tables[entry.key] = TableSchema.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return DatabaseSchema(tables);
  }

  /// Checks if a table exists in the schema.
  ///
  /// [tableName] - The name of the table to check
  ///
  /// Returns true if the table exists, false otherwise.
  bool hasTable(String tableName) => tables.containsKey(tableName);

  /// Gets a table schema by name.
  ///
  /// [tableName] - The name of the table to retrieve
  ///
  /// Returns the TableSchema if found, null otherwise.
  TableSchema? getTable(String tableName) => tables[tableName];

  /// Returns a list of all table names in the database.
  List<String> get tableNames => tables.keys.toList();
}

/// Represents a table schema with field and index definitions.
///
/// This class captures the complete schema for a single table, including
/// all field definitions, their types, constraints, and indexes.
///
/// Example:
/// ```dart
/// final tableSchema = await TableSchema.introspect(db, 'users');
/// print('Table: ${tableSchema.name}');
/// print('Fields: ${tableSchema.fields.keys.join(", ")}');
/// print('Indexes: ${tableSchema.indexes.keys.join(", ")}');
/// ```
class TableSchema {
  /// Creates a table schema.
  ///
  /// [name] - The table name
  /// [fields] - Map of field names to their definitions
  /// [indexes] - Map of index names to their definitions
  TableSchema({
    required this.name,
    required this.fields,
    required this.indexes,
  });

  /// The table name.
  final String name;

  /// Map of field names to their field schema definitions.
  ///
  /// The key is the field name, and the value contains the field's
  /// type, constraints, and other metadata.
  final Map<String, FieldSchema> fields;

  /// Map of index names to their index definitions.
  ///
  /// The key is the index name, and the value contains the fields
  /// that are indexed and index configuration.
  final Map<String, IndexSchema> indexes;

  /// Introspects a table schema using INFO FOR TABLE.
  ///
  /// Executes an INFO FOR TABLE query to retrieve the complete table schema,
  /// then parses the response to build a structured representation.
  ///
  /// [db] - The database connection to use
  /// [tableName] - The name of the table to introspect
  ///
  /// Returns a TableSchema snapshot of the table.
  ///
  /// Throws [SchemaIntrospectionException] if introspection fails.
  ///
  /// Example:
  /// ```dart
  /// final tableSchema = await TableSchema.introspect(db, 'users');
  /// print('Found ${tableSchema.fields.length} fields');
  /// ```
  static Future<TableSchema> introspect(Database db, String tableName) async {
    try {
      // Execute INFO FOR TABLE query
      final response = await db.query('INFO FOR TABLE $tableName');
      final results = response.getResults();

      if (results.isEmpty) {
        throw SchemaIntrospectionException(
          'INFO FOR TABLE $tableName returned no results',
        );
      }

      final tableInfo = results.first as Map<String, dynamic>;

      // Parse fields
      final fields = <String, FieldSchema>{};
      if (tableInfo.containsKey('fields')) {
        final fieldsInfo = tableInfo['fields'] as Map<String, dynamic>;
        for (final entry in fieldsInfo.entries) {
          final fieldName = entry.key;
          final fieldDef = entry.value as String;
          fields[fieldName] = FieldSchema.parse(fieldName, fieldDef);
        }
      }

      // Parse indexes
      final indexes = <String, IndexSchema>{};
      if (tableInfo.containsKey('indexes')) {
        final indexesInfo = tableInfo['indexes'] as Map<String, dynamic>;
        for (final entry in indexesInfo.entries) {
          final indexName = entry.key;
          final indexDef = entry.value as String;
          indexes[indexName] = IndexSchema.parse(indexName, indexDef);
        }
      }

      return TableSchema(
        name: tableName,
        fields: fields,
        indexes: indexes,
      );
    } catch (e) {
      if (e is SchemaIntrospectionException) {
        rethrow;
      }
      throw SchemaIntrospectionException(
        'Failed to introspect table "$tableName": $e',
      );
    }
  }

  /// Serializes the table schema to JSON.
  ///
  /// Returns a JSON-serializable map representation.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fields': fields.map((name, schema) => MapEntry(name, schema.toJson())),
      'indexes': indexes.map((name, schema) => MapEntry(name, schema.toJson())),
    };
  }

  /// Deserializes a table schema from JSON.
  ///
  /// [json] - The JSON map to deserialize
  ///
  /// Returns a TableSchema instance.
  factory TableSchema.fromJson(Map<String, dynamic> json) {
    final fields = <String, FieldSchema>{};
    if (json.containsKey('fields')) {
      final fieldsJson = json['fields'] as Map<String, dynamic>;
      for (final entry in fieldsJson.entries) {
        fields[entry.key] = FieldSchema.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    final indexes = <String, IndexSchema>{};
    if (json.containsKey('indexes')) {
      final indexesJson = json['indexes'] as Map<String, dynamic>;
      for (final entry in indexesJson.entries) {
        indexes[entry.key] = IndexSchema.fromJson(entry.value as Map<String, dynamic>);
      }
    }

    return TableSchema(
      name: json['name'] as String,
      fields: fields,
      indexes: indexes,
    );
  }

  /// Checks if a field exists in the table.
  bool hasField(String fieldName) => fields.containsKey(fieldName);

  /// Gets a field schema by name.
  FieldSchema? getField(String fieldName) => fields[fieldName];

  /// Checks if an index exists in the table.
  bool hasIndex(String indexName) => indexes.containsKey(indexName);

  /// Gets an index schema by name.
  IndexSchema? getIndex(String indexName) => indexes[indexName];

  /// Returns a list of all field names.
  List<String> get fieldNames => fields.keys.toList();

  /// Returns a list of all index names.
  List<String> get indexNames => indexes.keys.toList();
}

/// Represents a field schema with type and constraint information.
///
/// This class captures the schema for a single field, including its type,
/// whether it's optional, any ASSERT clauses, and default values.
///
/// Example:
/// ```dart
/// final fieldSchema = FieldSchema(
///   name: 'email',
///   type: 'string',
///   optional: false,
///   assertClause: 'string::is::email($value)',
/// );
/// ```
class FieldSchema {
  /// Creates a field schema.
  ///
  /// [name] - The field name
  /// [type] - The field type (e.g., 'string', 'int', 'float')
  /// [optional] - Whether the field is optional (defaults to false)
  /// [assertClause] - Optional ASSERT validation expression
  /// [defaultValue] - Optional default value
  FieldSchema({
    required this.name,
    required this.type,
    this.optional = false,
    this.assertClause,
    this.defaultValue,
  });

  /// The field name.
  final String name;

  /// The field type (e.g., 'string', 'int', 'float', 'bool').
  ///
  /// This is the raw type string from SurrealDB's INFO FOR TABLE response.
  final String type;

  /// Whether the field is optional (can be null/omitted).
  final bool optional;

  /// Optional ASSERT clause for field validation.
  ///
  /// This is the validation expression that SurrealDB evaluates when
  /// inserting or updating data.
  final String? assertClause;

  /// Optional default value for the field.
  ///
  /// This is used when a field value is not provided during insertion.
  final dynamic defaultValue;

  /// Parses a field definition from SurrealDB's INFO FOR TABLE response.
  ///
  /// [name] - The field name
  /// [definition] - The field definition string from INFO FOR TABLE
  ///
  /// Returns a FieldSchema instance.
  ///
  /// The definition string format from INFO FOR TABLE is typically:
  /// "DEFINE FIELD name ON table TYPE type [ASSERT ...] [DEFAULT ...]"
  ///
  /// Example:
  /// ```dart
  /// final field = FieldSchema.parse(
  ///   'age',
  ///   'DEFINE FIELD age ON users TYPE int ASSERT $value >= 0'
  /// );
  /// ```
  factory FieldSchema.parse(String name, String definition) {
    // Parse the field definition string
    // Format: "DEFINE FIELD name ON table TYPE type [ASSERT ...] [DEFAULT ...]"

    String type = 'any';
    bool optional = false;
    String? assertClause;
    dynamic defaultValue;

    // Extract TYPE
    final typeMatch = RegExp(r'TYPE\s+(\S+)').firstMatch(definition);
    if (typeMatch != null) {
      type = typeMatch.group(1)!;

      // Check if type is option<T> (optional field)
      if (type.startsWith('option<') && type.endsWith('>')) {
        optional = true;
        type = type.substring(7, type.length - 1); // Extract inner type
      }
    }

    // Extract ASSERT clause
    final assertMatch = RegExp(r'ASSERT\s+(.+?)(?:\s+DEFAULT|\s*$)').firstMatch(definition);
    if (assertMatch != null) {
      assertClause = assertMatch.group(1)!.trim();
    }

    // Extract DEFAULT value
    final defaultMatch = RegExp(r'DEFAULT\s+(.+?)\s*$').firstMatch(definition);
    if (defaultMatch != null) {
      final defaultStr = defaultMatch.group(1)!.trim();
      // Parse default value (simple parsing, can be enhanced)
      if (defaultStr == 'true') {
        defaultValue = true;
      } else if (defaultStr == 'false') {
        defaultValue = false;
      } else if (defaultStr == 'null' || defaultStr == 'NONE') {
        defaultValue = null;
      } else if (RegExp(r'^\d+$').hasMatch(defaultStr)) {
        defaultValue = int.parse(defaultStr);
      } else if (RegExp(r'^\d+\.\d+$').hasMatch(defaultStr)) {
        defaultValue = double.parse(defaultStr);
      } else {
        defaultValue = defaultStr;
      }
    }

    return FieldSchema(
      name: name,
      type: type,
      optional: optional,
      assertClause: assertClause,
      defaultValue: defaultValue,
    );
  }

  /// Serializes the field schema to JSON.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'optional': optional,
      if (assertClause != null) 'assertClause': assertClause,
      if (defaultValue != null) 'defaultValue': defaultValue,
    };
  }

  /// Deserializes a field schema from JSON.
  factory FieldSchema.fromJson(Map<String, dynamic> json) {
    return FieldSchema(
      name: json['name'] as String,
      type: json['type'] as String,
      optional: json['optional'] as bool? ?? false,
      assertClause: json['assertClause'] as String?,
      defaultValue: json['defaultValue'],
    );
  }

  /// Checks if this field has an ASSERT clause.
  bool get hasAssertion => assertClause != null;

  /// Checks if this field has a default value.
  bool get hasDefault => defaultValue != null;
}

/// Represents an index schema.
///
/// This class captures the schema for a database index, including the
/// fields that are indexed and any index configuration.
///
/// Example:
/// ```dart
/// final indexSchema = IndexSchema(
///   name: 'idx_email',
///   fields: ['email'],
/// );
/// ```
class IndexSchema {
  /// Creates an index schema.
  ///
  /// [name] - The index name
  /// [fields] - List of field names that are indexed
  IndexSchema({
    required this.name,
    required this.fields,
  });

  /// The index name.
  final String name;

  /// List of field names that are indexed.
  ///
  /// For composite indexes, this list contains multiple field names.
  final List<String> fields;

  /// Parses an index definition from SurrealDB's INFO FOR TABLE response.
  ///
  /// [name] - The index name
  /// [definition] - The index definition string from INFO FOR TABLE
  ///
  /// Returns an IndexSchema instance.
  ///
  /// The definition string format from INFO FOR TABLE is typically:
  /// "DEFINE INDEX name ON table FIELDS field1, field2, ..."
  ///
  /// Example:
  /// ```dart
  /// final index = IndexSchema.parse(
  ///   'idx_email',
  ///   'DEFINE INDEX idx_email ON users FIELDS email'
  /// );
  /// ```
  factory IndexSchema.parse(String name, String definition) {
    // Parse the index definition string
    // Format: "DEFINE INDEX name ON table FIELDS field1, field2, ..."

    final fields = <String>[];

    // Extract FIELDS
    final fieldsMatch = RegExp(r'FIELDS\s+(.+?)\s*$').firstMatch(definition);
    if (fieldsMatch != null) {
      final fieldsStr = fieldsMatch.group(1)!.trim();
      // Split by comma and trim each field name
      fields.addAll(
        fieldsStr.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty),
      );
    }

    return IndexSchema(
      name: name,
      fields: fields,
    );
  }

  /// Serializes the index schema to JSON.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'fields': fields,
    };
  }

  /// Deserializes an index schema from JSON.
  factory IndexSchema.fromJson(Map<String, dynamic> json) {
    return IndexSchema(
      name: json['name'] as String,
      fields: (json['fields'] as List<dynamic>).cast<String>(),
    );
  }

  /// Checks if this is a composite index (indexes multiple fields).
  bool get isComposite => fields.length > 1;

  /// Checks if this index includes a specific field.
  bool includesField(String fieldName) => fields.contains(fieldName);
}
