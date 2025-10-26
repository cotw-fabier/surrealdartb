/// Migration history tracking for schema migrations.
///
/// This library provides tools for recording and querying migration history
/// using the _migrations table, including schema snapshots for rollback support.
library;

import 'dart:convert';

import '../database.dart';
import '../exceptions.dart';
import 'introspection.dart';

/// Manages migration history tracking in the _migrations table.
///
/// This class handles creation of the _migrations table, recording of
/// successful and failed migrations, and querying of migration history
/// for rollback support.
///
/// ## Migration History Schema
///
/// The _migrations table uses the following schema:
/// ```sql
/// DEFINE TABLE _migrations SCHEMAFULL;
/// DEFINE FIELD migration_id ON _migrations TYPE string;
/// DEFINE FIELD applied_at ON _migrations TYPE datetime;
/// DEFINE FIELD status ON _migrations TYPE string;
/// DEFINE FIELD schema_snapshot ON _migrations TYPE object;
/// DEFINE FIELD changes_applied ON _migrations TYPE array;
/// DEFINE FIELD error_message ON _migrations TYPE option<string>;
/// DEFINE FIELD ddl_statements ON _migrations TYPE array;
/// ```
///
/// Example:
/// ```dart
/// final history = MigrationHistory();
///
/// // Ensure _migrations table exists
/// await history.ensureMigrationsTable(db);
///
/// // Record successful migration
/// await history.recordSuccess(
///   db,
///   migrationId: 'abc123',
///   schemaSnapshot: snapshot,
///   changesApplied: changes,
///   ddlStatements: ddl,
/// );
/// ```
class MigrationHistory {
  /// Creates a migration history manager.
  MigrationHistory();

  /// Ensures the _migrations table exists in the database.
  ///
  /// Creates the _migrations table with the proper schema if it doesn't
  /// already exist. This method is idempotent - it's safe to call multiple times.
  ///
  /// [db] - The database connection
  ///
  /// Throws [DatabaseException] if table creation fails.
  ///
  /// Example:
  /// ```dart
  /// final history = MigrationHistory();
  /// await history.ensureMigrationsTable(db);
  /// ```
  Future<void> ensureMigrationsTable(Database db) async {
    try {
      // Check if table exists
      try {
        await db.query('INFO FOR TABLE _migrations');
        // Table exists, no need to create
        return;
      } catch (e) {
        // Table doesn't exist, create it
      }

      // Create the _migrations table
      await db.query('DEFINE TABLE _migrations SCHEMAFULL');

      // Define fields
      await db.query(
        'DEFINE FIELD migration_id ON _migrations TYPE string',
      );
      await db.query(
        'DEFINE FIELD applied_at ON _migrations TYPE datetime',
      );
      await db.query(
        'DEFINE FIELD status ON _migrations TYPE string',
      );
      await db.query(
        'DEFINE FIELD schema_snapshot ON _migrations TYPE object',
      );
      await db.query(
        'DEFINE FIELD changes_applied ON _migrations TYPE array',
      );
      await db.query(
        'DEFINE FIELD error_message ON _migrations TYPE option<string>',
      );
      await db.query(
        'DEFINE FIELD ddl_statements ON _migrations TYPE array',
      );

      // Create index on migration_id for faster lookups
      await db.query(
        'DEFINE INDEX idx_migration_id ON _migrations FIELDS migration_id',
      );
    } catch (e) {
      throw DatabaseException(
        'Failed to create _migrations table: $e',
      );
    }
  }

  /// Records a successful migration in the history.
  ///
  /// Stores the migration ID, schema snapshot, applied changes, and DDL statements
  /// for future reference and rollback support.
  ///
  /// [db] - The database connection
  /// [migrationId] - Unique hash identifying this migration
  /// [schemaSnapshot] - Complete database schema snapshot after migration
  /// [changesApplied] - List of change descriptions
  /// [ddlStatements] - List of DDL statements executed
  ///
  /// Throws [DatabaseException] if recording fails.
  ///
  /// Example:
  /// ```dart
  /// await history.recordSuccess(
  ///   db,
  ///   migrationId: 'abc123',
  ///   schemaSnapshot: currentSchema,
  ///   changesApplied: ['Added table users', 'Added field users.email'],
  ///   ddlStatements: ddl,
  /// );
  /// ```
  Future<void> recordSuccess(
    Database db, {
    required String migrationId,
    required DatabaseSchema schemaSnapshot,
    required List<String> changesApplied,
    required List<String> ddlStatements,
  }) async {
    try {
      await db.create('_migrations', {
        'migration_id': migrationId,
        'applied_at': DateTime.now().toIso8601String(),
        'status': 'success',
        'schema_snapshot': schemaSnapshot.toJson(),
        'changes_applied': changesApplied,
        'ddl_statements': ddlStatements,
      });
    } catch (e) {
      throw DatabaseException(
        'Failed to record successful migration: $e',
      );
    }
  }

  /// Records a failed migration in the history.
  ///
  /// Stores the migration ID, error message, and attempted changes for
  /// debugging and audit purposes.
  ///
  /// [db] - The database connection
  /// [migrationId] - Unique hash identifying this migration
  /// [errorMessage] - Description of the failure
  /// [attemptedChanges] - List of changes that were attempted
  /// [ddlStatements] - List of DDL statements that were attempted
  ///
  /// Throws [DatabaseException] if recording fails.
  ///
  /// Example:
  /// ```dart
  /// await history.recordFailure(
  ///   db,
  ///   migrationId: 'abc123',
  ///   errorMessage: 'Syntax error in DDL',
  ///   attemptedChanges: ['Add table users'],
  ///   ddlStatements: badDdl,
  /// );
  /// ```
  Future<void> recordFailure(
    Database db, {
    required String migrationId,
    required String errorMessage,
    required List<String> attemptedChanges,
    required List<String> ddlStatements,
  }) async {
    try {
      await db.create('_migrations', {
        'migration_id': migrationId,
        'applied_at': DateTime.now().toIso8601String(),
        'status': 'failed',
        'error_message': errorMessage,
        'changes_applied': attemptedChanges,
        'ddl_statements': ddlStatements,
        'schema_snapshot': {}, // Empty snapshot for failed migrations
      });
    } catch (e) {
      // Log but don't throw - we don't want to hide the original error
      print('Warning: Failed to record migration failure: $e');
    }
  }

  /// Retrieves the last successful migration from history.
  ///
  /// Returns the most recent migration record with status 'success',
  /// or null if no successful migrations exist.
  ///
  /// [db] - The database connection
  ///
  /// Returns a MigrationRecord or null if none found.
  ///
  /// Throws [DatabaseException] if query fails.
  ///
  /// Example:
  /// ```dart
  /// final lastMigration = await history.getLastSuccessfulMigration(db);
  /// if (lastMigration != null) {
  ///   print('Last migration: ${lastMigration.migrationId}');
  ///   final snapshot = lastMigration.schemaSnapshot;
  /// }
  /// ```
  Future<MigrationRecord?> getLastSuccessfulMigration(Database db) async {
    try {
      final response = await db.query('''
        SELECT * FROM _migrations
        WHERE status = 'success'
        ORDER BY applied_at DESC
        LIMIT 1
      ''');

      final results = response.getResults();
      if (results.isEmpty) {
        return null;
      }

      // getResults() already unwraps nested structures
      final record = results.first;
      return MigrationRecord.fromJson(record);
    } catch (e) {
      throw DatabaseException(
        'Failed to retrieve last successful migration: $e',
      );
    }
  }

  /// Retrieves all migration records, ordered by applied_at descending.
  ///
  /// [db] - The database connection
  /// [limit] - Maximum number of records to return (defaults to 100)
  ///
  /// Returns a list of MigrationRecord objects.
  ///
  /// Throws [DatabaseException] if query fails.
  ///
  /// Example:
  /// ```dart
  /// final migrations = await history.getAllMigrations(db, limit: 10);
  /// for (final migration in migrations) {
  ///   print('${migration.migrationId}: ${migration.status}');
  /// }
  /// ```
  Future<List<MigrationRecord>> getAllMigrations(
    Database db, {
    int limit = 100,
  }) async {
    try {
      final response = await db.query('''
        SELECT * FROM _migrations
        ORDER BY applied_at DESC
        LIMIT $limit
      ''');

      final results = response.getResults();
      final records = <MigrationRecord>[];

      // getResults() already unwraps and returns List<Map<String, dynamic>>
      for (final record in results) {
        records.add(MigrationRecord.fromJson(record));
      }

      return records;
    } catch (e) {
      throw DatabaseException(
        'Failed to retrieve migration history: $e',
      );
    }
  }

  /// Checks if a migration with the given ID has already been applied.
  ///
  /// [db] - The database connection
  /// [migrationId] - The migration ID to check
  ///
  /// Returns true if the migration has been successfully applied, false otherwise.
  ///
  /// Throws [DatabaseException] if query fails.
  ///
  /// Example:
  /// ```dart
  /// if (await history.hasMigrationBeenApplied(db, 'abc123')) {
  ///   print('Migration already applied, skipping');
  ///   return;
  /// }
  /// ```
  Future<bool> hasMigrationBeenApplied(
    Database db,
    String migrationId,
  ) async {
    try {
      await db.set('migration_id', migrationId);

      final response = await db.query('''
        SELECT * FROM _migrations
        WHERE migration_id = \$migration_id AND status = 'success'
        LIMIT 1
      ''');

      final results = response.getResults();
      return results.isNotEmpty;
    } catch (e) {
      throw DatabaseException(
        'Failed to check migration status: $e',
      );
    }
  }
}

/// Represents a single migration record from the history.
///
/// Contains all information about a migration execution, including
/// the schema snapshot and changes applied.
class MigrationRecord {
  /// Creates a migration record.
  MigrationRecord({
    required this.id,
    required this.migrationId,
    required this.appliedAt,
    required this.status,
    required this.schemaSnapshot,
    required this.changesApplied,
    required this.ddlStatements,
    this.errorMessage,
  });

  /// The record ID (SurrealDB record ID).
  final String id;

  /// The migration hash identifier.
  final String migrationId;

  /// When the migration was applied.
  final DateTime appliedAt;

  /// Migration status ('success' or 'failed').
  final String status;

  /// Schema snapshot after migration (empty for failed migrations).
  final DatabaseSchema schemaSnapshot;

  /// List of changes that were applied (or attempted for failed migrations).
  final List<String> changesApplied;

  /// List of DDL statements executed (or attempted).
  final List<String> ddlStatements;

  /// Error message for failed migrations.
  final String? errorMessage;

  /// Deserializes a migration record from JSON.
  ///
  /// [json] - The JSON map from the database
  ///
  /// Returns a MigrationRecord instance.
  factory MigrationRecord.fromJson(Map<String, dynamic> json) {
    return MigrationRecord(
      id: json['id'] as String,
      migrationId: json['migration_id'] as String,
      appliedAt: DateTime.parse(json['applied_at'] as String),
      status: json['status'] as String,
      schemaSnapshot: json['schema_snapshot'] != null
          ? DatabaseSchema.fromJson(
              json['schema_snapshot'] as Map<String, dynamic>,
            )
          : DatabaseSchema({}),
      changesApplied: (json['changes_applied'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      ddlStatements: (json['ddl_statements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      errorMessage: json['error_message'] as String?,
    );
  }

  /// Serializes the migration record to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'migration_id': migrationId,
      'applied_at': appliedAt.toIso8601String(),
      'status': status,
      'schema_snapshot': schemaSnapshot.toJson(),
      'changes_applied': changesApplied,
      'ddl_statements': ddlStatements,
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }

  /// Whether this migration was successful.
  bool get wasSuccessful => status == 'success';

  /// Whether this migration failed.
  bool get failed => status == 'failed';
}
