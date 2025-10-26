/// Migration execution engine with transaction support.
///
/// This library provides the core migration orchestration logic, integrating
/// introspection, diff calculation, DDL generation, and transaction-based
/// execution with automatic rollback support.
library;

import '../database.dart';
import '../exceptions.dart';
import 'ddl_generator.dart';
import 'destructive_change_analyzer.dart';
import 'diff_engine.dart';
import 'introspection.dart';
import 'migration_history.dart';
import 'table_structure.dart';
import 'surreal_types.dart';
import '../types/vector_value.dart' show VectorFormat;

/// Orchestrates schema migrations with transaction safety.
///
/// This class integrates all migration components to provide a complete
/// migration workflow:
/// 1. Introspect current database schema
/// 2. Calculate diff against desired schema
/// 3. Generate DDL statements
/// 4. Execute in transaction with automatic rollback on failure
/// 5. Record migration history
///
/// ## Usage
///
/// ```dart
/// final engine = MigrationEngine();
///
/// // Define desired schema
/// final tables = [
///   TableStructure('users', {
///     'name': FieldDefinition(StringType()),
///     'email': FieldDefinition(StringType(), indexed: true),
///   }),
/// ];
///
/// // Execute migration
/// final report = await engine.executeMigration(
///   db,
///   tables,
///   allowDestructiveMigrations: false,
///   dryRun: false,
/// );
///
/// if (report.success) {
///   print('Migration completed successfully');
/// }
/// ```
///
/// ## Transaction Safety
///
/// All migrations execute within a SurrealDB transaction:
/// - BEGIN TRANSACTION before executing DDL
/// - COMMIT TRANSACTION on success
/// - CANCEL TRANSACTION on any failure
///
/// This ensures atomic all-or-nothing migration execution.
///
/// ## Dry Run Mode
///
/// Dry run mode executes the migration in a transaction, validates
/// all DDL statements, then cancels the transaction instead of committing.
/// This allows safe preview of migration changes.
class MigrationEngine {
  /// Creates a migration engine.
  MigrationEngine();

  final _ddlGenerator = DdlGenerator();
  final _migrationHistory = MigrationHistory();
  final _destructiveAnalyzer = DestructiveChangeAnalyzer();

  /// Executes a schema migration.
  ///
  /// This is the main entry point for running migrations. It orchestrates
  /// the complete migration workflow with transaction safety.
  ///
  /// [db] - The database connection
  /// [desiredTables] - List of desired table structures
  /// [allowDestructiveMigrations] - Whether to allow destructive changes (default: false)
  /// [dryRun] - Whether to preview changes without applying (default: false)
  ///
  /// Returns a MigrationReport with details of the migration.
  ///
  /// Throws [MigrationException] if:
  /// - Destructive changes detected and allowDestructiveMigrations is false
  /// - Migration execution fails
  /// - Transaction fails to commit or rollback
  ///
  /// Example:
  /// ```dart
  /// final report = await engine.executeMigration(
  ///   db,
  ///   [userTable, productTable],
  ///   allowDestructiveMigrations: false,
  ///   dryRun: false,
  /// );
  /// ```
  Future<MigrationReportImpl> executeMigration(
    Database db,
    List<TableStructure> desiredTables, {
    bool allowDestructiveMigrations = false,
    bool dryRun = false,
  }) async {
    // Ensure _migrations table exists
    await _migrationHistory.ensureMigrationsTable(db);

    // Step 1: Introspect current schema
    final currentSchema = await DatabaseSchema.introspect(db);

    // Step 2: Calculate diff
    final diff = SchemaDiff.calculate(currentSchema, desiredTables);

    // Check if there are any changes
    if (!diff.hasChanges) {
      return MigrationReportImpl(
        success: true,
        dryRun: dryRun,
        migrationId: diff.migrationHash,
        tablesAdded: [],
        tablesRemoved: [],
        fieldsAdded: {},
        fieldsRemoved: {},
        fieldsModified: {},
        indexesAdded: {},
        indexesRemoved: {},
        generatedDDL: [],
        hasDestructiveChanges: false,
        errorMessage: null,
      );
    }

    // Step 3: Check for destructive changes with detailed analysis
    if (diff.hasDestructiveChanges && !allowDestructiveMigrations) {
      // Perform detailed analysis with data loss estimation
      final analysis = await _destructiveAnalyzer.analyze(db, diff);

      // Generate detailed error message
      final detailedMessage =
          _destructiveAnalyzer.generateDetailedErrorMessage(analysis);

      final report = MigrationReportImpl.fromDiff(
        diff,
        [],
        success: false,
        dryRun: dryRun,
        errorMessage: detailedMessage,
      );

      throw MigrationException(
        detailedMessage,
        report: report,
        isDestructive: true,
      );
    }

    // Step 4: Generate DDL statements
    final ddlStatements = _ddlGenerator.generateFromDiff(diff, desiredTables);

    // Step 5: Execute migration in transaction
    try {
      await _executeMigrationInTransaction(
        db,
        diff,
        ddlStatements,
        dryRun,
      );

      // Step 6: Record success in migration history (if not dry run)
      if (!dryRun) {
        final newSchema = await DatabaseSchema.introspect(db);
        final changes = _generateChangeDescriptions(diff);

        await _migrationHistory.recordSuccess(
          db,
          migrationId: diff.migrationHash,
          schemaSnapshot: newSchema,
          changesApplied: changes,
          ddlStatements: ddlStatements,
        );
      }

      // Return success report
      return MigrationReportImpl.fromDiff(
        diff,
        ddlStatements,
        success: true,
        dryRun: dryRun,
      );
    } catch (e) {
      // If it's a dry run signal, return success report
      if (e is _DryRunRollbackSignal) {
        return MigrationReportImpl.fromDiff(
          diff,
          ddlStatements,
          success: true,
          dryRun: true,
        );
      }

      // Record failure in migration history (if not dry run)
      if (!dryRun) {
        final changes = _generateChangeDescriptions(diff);

        await _migrationHistory.recordFailure(
          db,
          migrationId: diff.migrationHash,
          errorMessage: e.toString(),
          attemptedChanges: changes,
          ddlStatements: ddlStatements,
        );
      }

      // Create failure report
      final report = MigrationReportImpl.fromDiff(
        diff,
        ddlStatements,
        success: false,
        dryRun: dryRun,
        errorMessage: e.toString(),
      );

      // Wrap in MigrationException
      if (e is MigrationException) {
        rethrow;
      } else {
        throw MigrationException(
          'Migration failed during execution: ${e.toString()}',
          report: report,
          isDestructive: false,
        );
      }
    }
  }

  /// Rolls back to the previous migration snapshot.
  ///
  /// This method retrieves the last two successful migrations from history,
  /// calculates the diff between current state and the previous snapshot,
  /// generates reverse DDL, and executes the rollback.
  ///
  /// [db] - The database connection
  /// [allowDestructiveMigrations] - Whether to allow destructive changes during rollback (default: false)
  /// [dryRun] - Whether to preview rollback without applying (default: false)
  ///
  /// Returns a MigrationReport with details of the rollback.
  ///
  /// Throws [MigrationException] if:
  /// - No previous migration exists (less than 2 migrations)
  /// - Rollback would be destructive and allowDestructiveMigrations is false
  /// - Rollback execution fails
  ///
  /// Example:
  /// ```dart
  /// // Preview rollback
  /// final preview = await engine.rollbackMigration(db, dryRun: true);
  /// print('Rollback would: ${preview.summary}');
  ///
  /// // Execute rollback
  /// final result = await engine.rollbackMigration(
  ///   db,
  ///   allowDestructiveMigrations: true,
  /// );
  /// ```
  Future<MigrationReportImpl> rollbackMigration(
    Database db, {
    bool allowDestructiveMigrations = false,
    bool dryRun = false,
  }) async {
    // Ensure _migrations table exists
    await _migrationHistory.ensureMigrationsTable(db);

    // Get last two successful migrations
    final migrations = await _migrationHistory.getAllMigrations(db, limit: 10);
    final successfulMigrations =
        migrations.where((m) => m.wasSuccessful).toList();

    // Need at least 2 migrations to rollback
    if (successfulMigrations.length < 2) {
      throw MigrationException(
        'Cannot rollback: Need at least 2 successful migrations, found ${successfulMigrations.length}.\n\n'
        'Rollback requires a previous schema state to restore. Current state:\n'
        '- Total migrations: ${migrations.length}\n'
        '- Successful migrations: ${successfulMigrations.length}\n\n'
        'To rollback, you must have applied at least two migrations.',
        isDestructive: false,
      );
    }

    // Get the second-to-last migration (the target state)
    final targetMigration = successfulMigrations[1];
    final targetSchema = targetMigration.schemaSnapshot;

    // Get current schema
    final currentSchema = await DatabaseSchema.introspect(db);

    // Convert target schema to list of TableStructure objects for diff calculation
    final targetTables = _convertSchemaToTableStructures(targetSchema);

    // Calculate diff from current to target (this is the "reverse" diff)
    final diff = SchemaDiff.calculate(currentSchema, targetTables);

    // Check if there are any changes
    if (!diff.hasChanges) {
      return MigrationReportImpl(
        success: true,
        dryRun: dryRun,
        migrationId: 'rollback_${diff.migrationHash}',
        tablesAdded: [],
        tablesRemoved: [],
        fieldsAdded: {},
        fieldsRemoved: {},
        fieldsModified: {},
        indexesAdded: {},
        indexesRemoved: {},
        generatedDDL: [],
        hasDestructiveChanges: false,
        errorMessage: null,
      );
    }

    // Check for destructive changes in rollback
    if (diff.hasDestructiveChanges && !allowDestructiveMigrations) {
      // Perform detailed analysis
      final analysis = await _destructiveAnalyzer.analyze(db, diff);

      // Generate detailed error message
      final detailedMessage =
          _destructiveAnalyzer.generateDetailedErrorMessage(analysis);

      final report = MigrationReportImpl.fromDiff(
        diff,
        [],
        success: false,
        dryRun: dryRun,
        errorMessage: 'Rollback would be destructive:\n$detailedMessage',
      );

      throw MigrationException(
        'Rollback aborted: Rollback would cause destructive changes.\n\n'
        '$detailedMessage\n\n'
        'To proceed with rollback despite data loss risk:\n'
        '  await db.rollbackMigration(allowDestructiveMigrations: true);',
        report: report,
        isDestructive: true,
      );
    }

    // Generate rollback DDL
    final ddlStatements = _ddlGenerator.generateFromDiff(diff, targetTables);

    // Execute rollback in transaction
    try {
      await _executeMigrationInTransaction(
        db,
        diff,
        ddlStatements,
        dryRun,
      );

      // Record rollback in migration history (if not dry run)
      if (!dryRun) {
        final newSchema = await DatabaseSchema.introspect(db);
        final changes = _generateRollbackChangeDescriptions(diff);

        await _migrationHistory.recordSuccess(
          db,
          migrationId: 'rollback_${diff.migrationHash}',
          schemaSnapshot: newSchema,
          changesApplied: changes,
          ddlStatements: ddlStatements,
        );
      }

      // Return success report
      return MigrationReportImpl.fromDiff(
        diff,
        ddlStatements,
        success: true,
        dryRun: dryRun,
      );
    } catch (e) {
      // If it's a dry run signal, return success report
      if (e is _DryRunRollbackSignal) {
        return MigrationReportImpl.fromDiff(
          diff,
          ddlStatements,
          success: true,
          dryRun: true,
        );
      }

      // Record failure in migration history (if not dry run)
      if (!dryRun) {
        final changes = _generateRollbackChangeDescriptions(diff);

        await _migrationHistory.recordFailure(
          db,
          migrationId: 'rollback_${diff.migrationHash}',
          errorMessage: e.toString(),
          attemptedChanges: changes,
          ddlStatements: ddlStatements,
        );
      }

      // Create failure report
      final report = MigrationReportImpl.fromDiff(
        diff,
        ddlStatements,
        success: false,
        dryRun: dryRun,
        errorMessage: e.toString(),
      );

      // Wrap in MigrationException
      if (e is MigrationException) {
        rethrow;
      } else {
        throw MigrationException(
          'Rollback failed during execution: ${e.toString()}',
          report: report,
          isDestructive: false,
        );
      }
    }
  }

  /// Converts a DatabaseSchema to a list of TableStructure objects.
  ///
  /// This is used to convert the schema snapshot from migration history
  /// into the format needed for diff calculation.
  List<TableStructure> _convertSchemaToTableStructures(
    DatabaseSchema schema,
  ) {
    final tables = <TableStructure>[];

    for (final tableName in schema.tableNames) {
      final tableSchema = schema.getTable(tableName);
      if (tableSchema == null) continue;

      // Build field definitions
      final fields = <String, FieldDefinition>{};
      for (final fieldName in tableSchema.fieldNames) {
        final fieldSchema = tableSchema.getField(fieldName);
        if (fieldSchema == null) continue;

        // Convert field schema to field definition
        fields[fieldName] = _convertFieldSchemaToDefinition(fieldSchema);
      }

      // Create table structure
      tables.add(TableStructure(tableName, fields));
    }

    return tables;
  }

  /// Converts a FieldSchema to a FieldDefinition.
  ///
  /// This reconstructs the field definition from the schema snapshot.
  FieldDefinition _convertFieldSchemaToDefinition(FieldSchema fieldSchema) {
    // Parse the type string back to SurrealType
    final type = _parseTypeString(fieldSchema.type);

    // Check if field was indexed
    final indexed =
        false; // We'll determine this from index information if available

    return FieldDefinition(
      type,
      optional: fieldSchema.optional,
      defaultValue: fieldSchema.defaultValue,
      assertClause: fieldSchema.assertClause,
      indexed: indexed,
    );
  }

  /// Parses a type string back into a SurrealType.
  ///
  /// This is the reverse of the type-to-string conversion used in diff calculation.
  SurrealType _parseTypeString(String typeStr) {
    // Handle option<T> wrapper
    if (typeStr.startsWith('option<') && typeStr.endsWith('>')) {
      final innerType = typeStr.substring(7, typeStr.length - 1);
      return _parseTypeString(innerType);
    }

    // Handle basic types
    switch (typeStr) {
      case 'string':
        return StringType();
      case 'bool':
        return BoolType();
      case 'int':
        return NumberType(format: NumberFormat.integer);
      case 'float':
        return NumberType(format: NumberFormat.floating);
      case 'decimal':
        return NumberType(format: NumberFormat.decimal);
      case 'number':
        return NumberType();
      case 'datetime':
        return DatetimeType();
      case 'duration':
        return DurationType();
      case 'geometry':
        return GeometryType();
      case 'object':
        return ObjectType();
      case 'record':
        return RecordType();
      case 'any':
        return AnyType();
    }

    // Handle array<T> or array<T, length>
    if (typeStr.startsWith('array<') && typeStr.endsWith('>')) {
      final content = typeStr.substring(6, typeStr.length - 1);
      final parts = content.split(',');

      if (parts.length == 1) {
        // array<T>
        final elementType = _parseTypeString(parts[0].trim());
        return ArrayType(elementType);
      } else if (parts.length == 2) {
        // array<T, length>
        final elementType = _parseTypeString(parts[0].trim());
        final length = int.tryParse(parts[1].trim());
        return ArrayType(elementType, length: length);
      }
    }

    // Handle vector<FORMAT, dimensions>
    if (typeStr.startsWith('vector<') && typeStr.endsWith('>')) {
      final content = typeStr.substring(7, typeStr.length - 1);
      final parts = content.split(',');

      if (parts.length == 2) {
        final formatStr = parts[0].trim();
        final dimensions = int.parse(parts[1].trim());

        final format = switch (formatStr) {
          'F32' => VectorFormat.f32,
          'F64' => VectorFormat.f64,
          'I8' => VectorFormat.i8,
          'I16' => VectorFormat.i16,
          'I32' => VectorFormat.i32,
          'I64' => VectorFormat.i64,
          _ => VectorFormat.f32, // Default fallback
        };

        return VectorType(format: format, dimensions: dimensions);
      }
    }

    // Handle record<table>
    if (typeStr.startsWith('record<') && typeStr.endsWith('>')) {
      final table = typeStr.substring(7, typeStr.length - 1);
      return RecordType(table: table);
    }

    // Fallback to any type if we can't parse
    return AnyType();
  }

  /// Executes migration DDL within a transaction.
  ///
  /// Uses Database.transaction() for atomic execution with automatic
  /// rollback on failure.
  Future<void> _executeMigrationInTransaction(
    Database db,
    SchemaDiff diff,
    List<String> ddlStatements,
    bool dryRun,
  ) async {
    try {
      await db.transaction((txn) async {
        // Execute each DDL statement sequentially
        for (final statement in ddlStatements) {
          try {
            await txn.queryQL(statement);
          } catch (e) {
            throw MigrationException(
              'Failed to execute DDL statement: $statement\nError: $e',
              isDestructive: false,
            );
          }
        }

        // If dry run, throw to trigger rollback
        if (dryRun) {
          throw _DryRunRollbackSignal();
        }

        // Transaction will be committed by Database.transaction()
      });
    } catch (e) {
      // Rethrow the error (including dry run signal)
      rethrow;
    }
  }

  /// Generates human-readable change descriptions from a diff.
  List<String> _generateChangeDescriptions(SchemaDiff diff) {
    final changes = <String>[];

    for (final table in diff.tablesAdded) {
      changes.add('Added table: $table');
    }

    for (final table in diff.tablesRemoved) {
      changes.add('Removed table: $table');
    }

    for (final entry in diff.fieldsAdded.entries) {
      for (final field in entry.value) {
        changes.add('Added field: ${entry.key}.$field');
      }
    }

    for (final entry in diff.fieldsRemoved.entries) {
      for (final field in entry.value) {
        changes.add('Removed field: ${entry.key}.$field');
      }
    }

    for (final entry in diff.fieldsModified.entries) {
      for (final mod in entry.value) {
        if (mod.typeChanged) {
          changes.add(
            'Modified field: ${entry.key}.${mod.fieldName} '
            '(${mod.oldType} -> ${mod.newType})',
          );
        } else {
          changes.add('Modified field: ${entry.key}.${mod.fieldName}');
        }
      }
    }

    for (final entry in diff.indexesAdded.entries) {
      for (final field in entry.value) {
        changes.add('Added index: ${entry.key}.$field');
      }
    }

    for (final entry in diff.indexesRemoved.entries) {
      for (final field in entry.value) {
        changes.add('Removed index: ${entry.key}.$field');
      }
    }

    return changes;
  }

  /// Generates human-readable rollback change descriptions.
  List<String> _generateRollbackChangeDescriptions(SchemaDiff diff) {
    final changes = <String>['ROLLBACK: Reverting to previous migration'];

    for (final table in diff.tablesAdded) {
      changes.add('Rollback: Re-added table: $table');
    }

    for (final table in diff.tablesRemoved) {
      changes.add('Rollback: Removed table: $table');
    }

    for (final entry in diff.fieldsAdded.entries) {
      for (final field in entry.value) {
        changes.add('Rollback: Re-added field: ${entry.key}.$field');
      }
    }

    for (final entry in diff.fieldsRemoved.entries) {
      for (final field in entry.value) {
        changes.add('Rollback: Removed field: ${entry.key}.$field');
      }
    }

    for (final entry in diff.fieldsModified.entries) {
      for (final mod in entry.value) {
        if (mod.typeChanged) {
          changes.add(
            'Rollback: Reverted field: ${entry.key}.${mod.fieldName} '
            '(${mod.oldType} -> ${mod.newType})',
          );
        } else {
          changes
              .add('Rollback: Reverted field: ${entry.key}.${mod.fieldName}');
        }
      }
    }

    return changes;
  }
}

/// Concrete implementation of MigrationReport.
///
/// This class provides the complete migration report structure with
/// all change details, generated DDL, and execution status.
class MigrationReportImpl implements MigrationReport {
  /// Creates a migration report.
  MigrationReportImpl({
    required this.success,
    required this.dryRun,
    required this.migrationId,
    required this.tablesAdded,
    required this.tablesRemoved,
    required this.fieldsAdded,
    required this.fieldsRemoved,
    required this.fieldsModified,
    required this.indexesAdded,
    required this.indexesRemoved,
    required this.generatedDDL,
    required this.hasDestructiveChanges,
    this.errorMessage,
  });

  /// Creates a migration report from a schema diff.
  factory MigrationReportImpl.fromDiff(
    SchemaDiff diff,
    List<String> ddlStatements, {
    required bool success,
    required bool dryRun,
    String? errorMessage,
  }) {
    return MigrationReportImpl(
      success: success,
      dryRun: dryRun,
      migrationId: diff.migrationHash,
      tablesAdded: diff.tablesAdded,
      tablesRemoved: diff.tablesRemoved,
      fieldsAdded: diff.fieldsAdded,
      fieldsRemoved: diff.fieldsRemoved,
      fieldsModified: diff.fieldsModified.map(
        (table, mods) => MapEntry(
          table,
          mods.map((m) => m.fieldName).toList(),
        ),
      ),
      indexesAdded: diff.indexesAdded,
      indexesRemoved: diff.indexesRemoved,
      generatedDDL: ddlStatements,
      hasDestructiveChanges: diff.hasDestructiveChanges,
      errorMessage: errorMessage,
    );
  }

  /// Whether the migration was successful.
  final bool success;

  /// Whether this was a dry run (preview only).
  final bool dryRun;

  /// The unique migration hash identifier.
  final String migrationId;

  /// List of tables that were added.
  @override
  final List<String> tablesAdded;

  /// List of tables that were removed.
  @override
  final List<String> tablesRemoved;

  /// Map of table names to lists of fields added.
  final Map<String, List<String>> fieldsAdded;

  /// Map of table names to lists of fields removed.
  @override
  final Map<String, List<String>> fieldsRemoved;

  /// Map of table names to lists of fields modified.
  final Map<String, List<String>> fieldsModified;

  /// Map of table names to lists of indexes added.
  final Map<String, List<String>> indexesAdded;

  /// Map of table names to lists of indexes removed.
  final Map<String, List<String>> indexesRemoved;

  /// List of generated DDL statements.
  final List<String> generatedDDL;

  /// Whether the migration involves destructive changes.
  final bool hasDestructiveChanges;

  /// Error message if migration failed.
  final String? errorMessage;

  /// Checks if there are any changes in this report.
  bool get hasChanges {
    return tablesAdded.isNotEmpty ||
        tablesRemoved.isNotEmpty ||
        fieldsAdded.values.any((fields) => fields.isNotEmpty) ||
        fieldsRemoved.values.any((fields) => fields.isNotEmpty) ||
        fieldsModified.values.any((fields) => fields.isNotEmpty) ||
        indexesAdded.values.any((indexes) => indexes.isNotEmpty) ||
        indexesRemoved.values.any((indexes) => indexes.isNotEmpty);
  }

  /// Generates a summary string of the migration.
  String get summary {
    final buffer = StringBuffer();

    buffer.writeln('Migration Report:');
    buffer.writeln('  ID: $migrationId');
    buffer.writeln('  Status: ${success ? "SUCCESS" : "FAILED"}');
    buffer.writeln('  Dry Run: $dryRun');
    buffer.writeln('  Destructive: $hasDestructiveChanges');

    if (!hasChanges) {
      buffer.writeln('  No changes detected');
      return buffer.toString();
    }

    buffer.writeln('\nChanges:');

    if (tablesAdded.isNotEmpty) {
      buffer.writeln('  Tables Added: ${tablesAdded.length}');
      for (final table in tablesAdded) {
        buffer.writeln('    - $table');
      }
    }

    if (tablesRemoved.isNotEmpty) {
      buffer.writeln('  Tables Removed: ${tablesRemoved.length}');
      for (final table in tablesRemoved) {
        buffer.writeln('    - $table');
      }
    }

    if (fieldsAdded.isNotEmpty) {
      final totalFields =
          fieldsAdded.values.fold<int>(0, (sum, fields) => sum + fields.length);
      buffer.writeln('  Fields Added: $totalFields');
      for (final entry in fieldsAdded.entries) {
        for (final field in entry.value) {
          buffer.writeln('    - ${entry.key}.$field');
        }
      }
    }

    if (fieldsRemoved.isNotEmpty) {
      final totalFields = fieldsRemoved.values
          .fold<int>(0, (sum, fields) => sum + fields.length);
      buffer.writeln('  Fields Removed: $totalFields');
      for (final entry in fieldsRemoved.entries) {
        for (final field in entry.value) {
          buffer.writeln('    - ${entry.key}.$field');
        }
      }
    }

    if (errorMessage != null) {
      buffer.writeln('\nError: $errorMessage');
    }

    return buffer.toString();
  }

  @override
  String toString() => summary;
}

/// Internal exception used to signal dry run rollback.
///
/// This is thrown internally to trigger transaction rollback in dry run mode.
/// It's caught and handled by the migration engine.
class _DryRunRollbackSignal implements Exception {
  @override
  String toString() => 'Dry run complete - transaction cancelled';
}
