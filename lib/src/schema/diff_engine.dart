/// Schema diff calculation engine for migration detection.
///
/// This library provides tools for comparing database schemas and generating
/// detailed change reports, including table-level, field-level, and constraint-level
/// diffs with classification of safe vs destructive changes.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../types/vector_value.dart';
import 'introspection.dart';
import 'surreal_types.dart';
import 'table_structure.dart';

/// Represents a complete schema diff between current and desired state.
///
/// This class contains all detected changes including tables added/removed,
/// fields added/removed/modified, indexes changed, and provides a classification
/// of whether the changes are destructive.
///
/// Example:
/// ```dart
/// final currentSchema = await DatabaseSchema.introspect(db);
/// final desiredTables = [userTableDef, productTableDef];
/// final diff = SchemaDiff.calculate(currentSchema, desiredTables);
///
/// if (diff.hasDestructiveChanges) {
///   print('Warning: Destructive changes detected');
///   for (final table in diff.tablesRemoved) {
///     print('  - Table "$table" will be removed');
///   }
/// }
/// ```
class SchemaDiff {
  /// Creates a schema diff result.
  ///
  /// [tablesAdded] - List of table names added in desired schema
  /// [tablesRemoved] - List of table names removed from current schema
  /// [fieldsAdded] - Map of table names to lists of added field names
  /// [fieldsRemoved] - Map of table names to lists of removed field names
  /// [fieldsModified] - Map of table names to lists of modified fields
  /// [indexesAdded] - Map of table names to lists of added index field names
  /// [indexesRemoved] - Map of table names to lists of removed index field names
  /// [migrationHash] - Deterministic hash identifying this set of changes
  SchemaDiff({
    required this.tablesAdded,
    required this.tablesRemoved,
    required this.fieldsAdded,
    required this.fieldsRemoved,
    required this.fieldsModified,
    required this.indexesAdded,
    required this.indexesRemoved,
    required this.migrationHash,
  });

  /// List of table names that exist in desired schema but not in current schema.
  ///
  /// These are safe additions (non-destructive).
  final List<String> tablesAdded;

  /// List of table names that exist in current schema but not in desired schema.
  ///
  /// These are destructive removals.
  final List<String> tablesRemoved;

  /// Map of table names to lists of field names added in desired schema.
  ///
  /// These are typically safe additions, especially if fields are optional.
  final Map<String, List<String>> fieldsAdded;

  /// Map of table names to lists of field names removed from current schema.
  ///
  /// These are destructive removals.
  final Map<String, List<String>> fieldsRemoved;

  /// Map of table names to lists of field modifications.
  ///
  /// Modifications may be safe (adding constraints) or destructive (type changes).
  final Map<String, List<FieldModification>> fieldsModified;

  /// Map of table names to lists of field names that have indexes added.
  ///
  /// These are safe additions (performance optimization).
  final Map<String, List<String>> indexesAdded;

  /// Map of table names to lists of field names that have indexes removed.
  ///
  /// These are typically safe removals (though may impact performance).
  final Map<String, List<String>> indexesRemoved;

  /// Deterministic hash uniquely identifying this set of schema changes.
  ///
  /// Used for tracking migrations in the _migrations table.
  /// Same changes will always produce the same hash.
  final String migrationHash;

  /// Checks if there are any changes in this diff.
  ///
  /// Returns true if any tables, fields, indexes, or constraints have changed.
  bool get hasChanges {
    return tablesAdded.isNotEmpty ||
        tablesRemoved.isNotEmpty ||
        fieldsAdded.values.any((fields) => fields.isNotEmpty) ||
        fieldsRemoved.values.any((fields) => fields.isNotEmpty) ||
        fieldsModified.values.any((mods) => mods.isNotEmpty) ||
        indexesAdded.values.any((indexes) => indexes.isNotEmpty) ||
        indexesRemoved.values.any((indexes) => indexes.isNotEmpty);
  }

  /// Checks if this diff contains destructive changes.
  ///
  /// Destructive changes include:
  /// - Removing tables
  /// - Removing fields
  /// - Changing field types
  /// - Making optional fields required
  ///
  /// Returns true if any destructive changes are present.
  bool get hasDestructiveChanges {
    // Table removals are destructive
    if (tablesRemoved.isNotEmpty) {
      return true;
    }

    // Field removals are destructive
    if (fieldsRemoved.values.any((fields) => fields.isNotEmpty)) {
      return true;
    }

    // Check for destructive field modifications
    for (final modifications in fieldsModified.values) {
      for (final mod in modifications) {
        if (mod.isDestructive) {
          return true;
        }
      }
    }

    return false;
  }

  /// Calculates the schema diff between current and desired schemas.
  ///
  /// Performs table-level, field-level, and constraint-level diffing to
  /// identify all changes needed to transform current schema to desired schema.
  ///
  /// [currentSchema] - The current database schema from introspection
  /// [desiredTables] - List of desired table structures from code
  ///
  /// Returns a SchemaDiff containing all detected changes.
  ///
  /// Example:
  /// ```dart
  /// final currentSchema = await DatabaseSchema.introspect(db);
  /// final desiredTables = [userTableDef, productTableDef];
  /// final diff = SchemaDiff.calculate(currentSchema, desiredTables);
  ///
  /// print('Tables to add: ${diff.tablesAdded}');
  /// print('Tables to remove: ${diff.tablesRemoved}');
  /// ```
  static SchemaDiff calculate(
    DatabaseSchema currentSchema,
    List<TableStructure> desiredTables,
  ) {
    // Build map of desired table names for quick lookup
    final desiredTableMap = <String, TableStructure>{};
    for (final table in desiredTables) {
      desiredTableMap[table.tableName] = table;
    }

    // Calculate table-level diff
    final tablesAdded = <String>[];
    final tablesRemoved = <String>[];

    // Find added tables (in desired but not in current)
    for (final tableName in desiredTableMap.keys) {
      if (!currentSchema.hasTable(tableName)) {
        tablesAdded.add(tableName);
      }
    }

    // Find removed tables (in current but not in desired)
    for (final tableName in currentSchema.tableNames) {
      if (!desiredTableMap.containsKey(tableName)) {
        tablesRemoved.add(tableName);
      }
    }

    // Calculate field-level and constraint-level diffs
    final fieldsAdded = <String, List<String>>{};
    final fieldsRemoved = <String, List<String>>{};
    final fieldsModified = <String, List<FieldModification>>{};
    final indexesAdded = <String, List<String>>{};
    final indexesRemoved = <String, List<String>>{};

    // For newly added tables, all their fields are "added"
    for (final tableName in tablesAdded) {
      final desiredTable = desiredTableMap[tableName]!;
      final fieldNames = desiredTable.fields.keys.toList();
      if (fieldNames.isNotEmpty) {
        fieldsAdded[tableName] = fieldNames;
      }

      // Also track indexes for added tables
      final indexedFields = <String>[];
      for (final entry in desiredTable.fields.entries) {
        if (entry.value.indexed) {
          indexedFields.add(entry.key);
        }
      }
      if (indexedFields.isNotEmpty) {
        indexesAdded[tableName] = indexedFields;
      }
    }

    // For tables that exist in both schemas, check field changes
    for (final tableName in desiredTableMap.keys) {
      if (currentSchema.hasTable(tableName)) {
        final currentTable = currentSchema.getTable(tableName)!;
        final desiredTable = desiredTableMap[tableName]!;

        // Calculate field diffs
        final fieldDiff = _calculateFieldDiff(currentTable, desiredTable);

        if (fieldDiff.added.isNotEmpty) {
          fieldsAdded[tableName] = fieldDiff.added;
        }
        if (fieldDiff.removed.isNotEmpty) {
          fieldsRemoved[tableName] = fieldDiff.removed;
        }
        if (fieldDiff.modified.isNotEmpty) {
          fieldsModified[tableName] = fieldDiff.modified;
        }

        // Calculate index diffs
        final indexDiff = _calculateIndexDiff(currentTable, desiredTable);

        if (indexDiff.added.isNotEmpty) {
          indexesAdded[tableName] = indexDiff.added;
        }
        if (indexDiff.removed.isNotEmpty) {
          indexesRemoved[tableName] = indexDiff.removed;
        }
      }
    }

    // For removed tables, all their fields are "removed"
    for (final tableName in tablesRemoved) {
      final currentTable = currentSchema.getTable(tableName)!;
      final fieldNames = currentTable.fieldNames;
      if (fieldNames.isNotEmpty) {
        fieldsRemoved[tableName] = fieldNames;
      }

      // Also track indexes for removed tables
      final indexedFields = <String>[];
      for (final index in currentTable.indexes.values) {
        indexedFields.addAll(index.fields);
      }
      if (indexedFields.isNotEmpty) {
        indexesRemoved[tableName] = indexedFields.toSet().toList();
      }
    }

    // Generate deterministic migration hash
    final hash = _generateMigrationHash(
      tablesAdded,
      tablesRemoved,
      fieldsAdded,
      fieldsRemoved,
      fieldsModified,
      indexesAdded,
      indexesRemoved,
    );

    return SchemaDiff(
      tablesAdded: tablesAdded,
      tablesRemoved: tablesRemoved,
      fieldsAdded: fieldsAdded,
      fieldsRemoved: fieldsRemoved,
      fieldsModified: fieldsModified,
      indexesAdded: indexesAdded,
      indexesRemoved: indexesRemoved,
      migrationHash: hash,
    );
  }

  /// Calculates field-level diff for a specific table.
  static _FieldDiff _calculateFieldDiff(
    TableSchema currentTable,
    TableStructure desiredTable,
  ) {
    final added = <String>[];
    final removed = <String>[];
    final modified = <FieldModification>[];

    // Find added fields (in desired but not in current)
    for (final fieldName in desiredTable.fields.keys) {
      if (!currentTable.hasField(fieldName)) {
        added.add(fieldName);
      }
    }

    // Find removed fields (in current but not in desired)
    for (final fieldName in currentTable.fieldNames) {
      if (!desiredTable.hasField(fieldName)) {
        removed.add(fieldName);
      }
    }

    // Find modified fields (exists in both but different)
    for (final fieldName in desiredTable.fields.keys) {
      if (currentTable.hasField(fieldName)) {
        final currentField = currentTable.getField(fieldName)!;
        final desiredField = desiredTable.getField(fieldName)!;

        final modification = _compareFields(
          fieldName,
          currentField,
          desiredField,
        );

        if (modification != null) {
          modified.add(modification);
        }
      }
    }

    return _FieldDiff(added: added, removed: removed, modified: modified);
  }

  /// Compares two fields to detect modifications.
  ///
  /// Returns a FieldModification if changes are detected, null if identical.
  static FieldModification? _compareFields(
    String fieldName,
    FieldSchema currentField,
    FieldDefinition desiredField,
  ) {
    bool typeChanged = false;
    bool optionalityChanged = false;
    bool assertClauseChanged = false;
    bool defaultValueChanged = false;

    // Convert desired type to SurrealDB type string for comparison
    final desiredType = _surrealTypeToString(desiredField.type);
    final currentType = currentField.type;

    // Check if type changed
    if (currentType != desiredType) {
      typeChanged = true;
    }

    // Check if optionality changed
    if (currentField.optional != desiredField.optional) {
      optionalityChanged = true;
    }

    // Check if ASSERT clause changed
    final currentAssert = currentField.assertClause ?? '';
    final desiredAssert = desiredField.assertClause ?? '';
    if (currentAssert != desiredAssert) {
      assertClauseChanged = true;
    }

    // Check if default value changed
    if (currentField.defaultValue != desiredField.defaultValue) {
      defaultValueChanged = true;
    }

    // If nothing changed, return null
    if (!typeChanged &&
        !optionalityChanged &&
        !assertClauseChanged &&
        !defaultValueChanged) {
      return null;
    }

    return FieldModification(
      fieldName: fieldName,
      oldType: currentType,
      newType: desiredType,
      typeChanged: typeChanged,
      optionalityChanged: optionalityChanged,
      wasOptional: currentField.optional,
      isOptional: desiredField.optional,
      assertClauseChanged: assertClauseChanged,
      oldAssertClause: currentField.assertClause,
      newAssertClause: desiredField.assertClause,
      defaultValueChanged: defaultValueChanged,
      oldDefaultValue: currentField.defaultValue,
      newDefaultValue: desiredField.defaultValue,
    );
  }

  /// Converts a SurrealType to its SurrealDB string representation.
  static String _surrealTypeToString(SurrealType type) {
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

  /// Converts NumberFormat to SurrealDB type string.
  static String _numberFormatToString(NumberFormat? format) {
    if (format == null) return 'number';
    return switch (format) {
      NumberFormat.integer => 'int',
      NumberFormat.floating => 'float',
      NumberFormat.decimal => 'decimal',
    };
  }

  /// Converts VectorType to SurrealDB type string.
  static String _vectorTypeToString(VectorFormat format, int dimensions) {
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

  /// Calculates index-level diff for a specific table.
  static _IndexDiff _calculateIndexDiff(
    TableSchema currentTable,
    TableStructure desiredTable,
  ) {
    final added = <String>[];
    final removed = <String>[];

    // Build set of current indexed fields
    final currentIndexedFields = <String>{};
    for (final index in currentTable.indexes.values) {
      currentIndexedFields.addAll(index.fields);
    }

    // Build set of desired indexed fields
    final desiredIndexedFields = <String>{};
    for (final entry in desiredTable.fields.entries) {
      if (entry.value.indexed) {
        desiredIndexedFields.add(entry.key);
      }
    }

    // Find added indexes
    for (final fieldName in desiredIndexedFields) {
      if (!currentIndexedFields.contains(fieldName)) {
        added.add(fieldName);
      }
    }

    // Find removed indexes
    for (final fieldName in currentIndexedFields) {
      if (!desiredIndexedFields.contains(fieldName)) {
        removed.add(fieldName);
      }
    }

    return _IndexDiff(added: added, removed: removed);
  }

  /// Generates a deterministic hash for migration tracking.
  ///
  /// The hash is based on all schema changes and will be identical for
  /// the same set of changes, allowing migration deduplication.
  static String _generateMigrationHash(
    List<String> tablesAdded,
    List<String> tablesRemoved,
    Map<String, List<String>> fieldsAdded,
    Map<String, List<String>> fieldsRemoved,
    Map<String, List<FieldModification>> fieldsModified,
    Map<String, List<String>> indexesAdded,
    Map<String, List<String>> indexesRemoved,
  ) {
    // Build deterministic representation of changes
    final changesSorted = <String, dynamic>{
      'tablesAdded': List<String>.from(tablesAdded)..sort(),
      'tablesRemoved': List<String>.from(tablesRemoved)..sort(),
      'fieldsAdded': _sortMapOfLists(fieldsAdded),
      'fieldsRemoved': _sortMapOfLists(fieldsRemoved),
      'fieldsModified': _sortMapOfModifications(fieldsModified),
      'indexesAdded': _sortMapOfLists(indexesAdded),
      'indexesRemoved': _sortMapOfLists(indexesRemoved),
    };

    // Convert to JSON and hash
    final jsonString = jsonEncode(changesSorted);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Helper to sort a map of string lists for deterministic hashing.
  static Map<String, List<String>> _sortMapOfLists(
    Map<String, List<String>> map,
  ) {
    final sorted = <String, List<String>>{};
    final keys = map.keys.toList()..sort();
    for (final key in keys) {
      sorted[key] = List<String>.from(map[key]!)..sort();
    }
    return sorted;
  }

  /// Helper to sort a map of field modifications for deterministic hashing.
  static Map<String, List<Map<String, dynamic>>> _sortMapOfModifications(
    Map<String, List<FieldModification>> map,
  ) {
    final sorted = <String, List<Map<String, dynamic>>>{};
    final keys = map.keys.toList()..sort();
    for (final key in keys) {
      final mods = map[key]!.map((m) => m.toJson()).toList();
      mods.sort((a, b) => a['fieldName'].compareTo(b['fieldName']));
      sorted[key] = mods;
    }
    return sorted;
  }
}

/// Represents a modification to a field's definition.
///
/// Tracks what aspects of the field changed (type, optionality, constraints)
/// and whether the change is destructive.
class FieldModification {
  /// Creates a field modification record.
  FieldModification({
    required this.fieldName,
    required this.oldType,
    required this.newType,
    required this.typeChanged,
    required this.optionalityChanged,
    required this.wasOptional,
    required this.isOptional,
    required this.assertClauseChanged,
    required this.oldAssertClause,
    required this.newAssertClause,
    required this.defaultValueChanged,
    required this.oldDefaultValue,
    required this.newDefaultValue,
  });

  /// The name of the field that was modified.
  final String fieldName;

  /// The old field type.
  final String oldType;

  /// The new field type.
  final String newType;

  /// Whether the field type changed.
  final bool typeChanged;

  /// Whether the field optionality changed.
  final bool optionalityChanged;

  /// Whether the field was optional in the old schema.
  final bool wasOptional;

  /// Whether the field is optional in the new schema.
  final bool isOptional;

  /// Whether the ASSERT clause changed.
  final bool assertClauseChanged;

  /// The old ASSERT clause (null if none).
  final String? oldAssertClause;

  /// The new ASSERT clause (null if none).
  final String? newAssertClause;

  /// Whether the default value changed.
  final bool defaultValueChanged;

  /// The old default value (null if none).
  final dynamic oldDefaultValue;

  /// The new default value (null if none).
  final dynamic newDefaultValue;

  /// Checks if this modification is destructive.
  ///
  /// A modification is destructive if:
  /// - The type changed (data may be lost in conversion)
  /// - The field became required (existing null values would fail)
  /// - The ASSERT clause became stricter (existing data may fail validation)
  ///
  /// Safe modifications include:
  /// - Adding an ASSERT where there was none (new constraint on future inserts)
  /// - Removing an ASSERT (making constraint less strict)
  /// - Making a required field optional (less restrictive)
  /// - Changing default values (only affects new records)
  bool get isDestructive {
    // Type changes are always destructive
    if (typeChanged) {
      return true;
    }

    // Making a field required (was optional, now not) is destructive
    if (optionalityChanged && wasOptional && !isOptional) {
      return true;
    }

    // Adding an ASSERT where there was none is safe (only affects future inserts)
    // Removing an ASSERT is safe (making constraint less strict)
    // Modifying an existing ASSERT is potentially destructive (tightening constraint)
    if (assertClauseChanged) {
      final hadAssertion =
          oldAssertClause != null && oldAssertClause!.isNotEmpty;
      final hasAssertion =
          newAssertClause != null && newAssertClause!.isNotEmpty;

      // If we had an assertion and still have one (modified): treat as destructive
      // This is conservative - in practice some changes might be safe
      if (hadAssertion && hasAssertion) {
        return true;
      }
      // Adding new assertion (no old, has new): safe
      // Removing assertion (had old, no new): safe
    }

    return false;
  }

  /// Converts this modification to JSON for hashing.
  Map<String, dynamic> toJson() {
    return {
      'fieldName': fieldName,
      'oldType': oldType,
      'newType': newType,
      'typeChanged': typeChanged,
      'optionalityChanged': optionalityChanged,
      'wasOptional': wasOptional,
      'isOptional': isOptional,
      'assertClauseChanged': assertClauseChanged,
      'oldAssertClause': oldAssertClause,
      'newAssertClause': newAssertClause,
      'defaultValueChanged': defaultValueChanged,
      'oldDefaultValue': oldDefaultValue?.toString(),
      'newDefaultValue': newDefaultValue?.toString(),
    };
  }
}

/// Internal class for field diff results.
class _FieldDiff {
  _FieldDiff({
    required this.added,
    required this.removed,
    required this.modified,
  });

  final List<String> added;
  final List<String> removed;
  final List<FieldModification> modified;
}

/// Internal class for index diff results.
class _IndexDiff {
  _IndexDiff({
    required this.added,
    required this.removed,
  });

  final List<String> added;
  final List<String> removed;
}
