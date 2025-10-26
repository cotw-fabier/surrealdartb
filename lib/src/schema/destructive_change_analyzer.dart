/// Analyzes destructive schema changes and generates detailed reports.
///
/// This library provides tools for analyzing destructive migrations, estimating
/// potential data loss, and generating actionable error messages for developers.
library;

import '../database.dart';
import 'diff_engine.dart';

/// Analyzes destructive changes and generates detailed information.
///
/// This class provides methods to estimate data loss and generate
/// comprehensive error messages that help developers understand the
/// impact of destructive migrations.
///
/// Example:
/// ```dart
/// final analyzer = DestructiveChangeAnalyzer();
/// final analysis = await analyzer.analyze(db, diff);
///
/// print('Tables to be removed: ${analysis.tableRemovalInfo}');
/// for (final info in analysis.tableRemovalInfo) {
///   print('  ${info.tableName}: ${info.estimatedRecords} records will be lost');
/// }
/// ```
class DestructiveChangeAnalyzer {
  /// Creates a destructive change analyzer.
  DestructiveChangeAnalyzer();

  /// Analyzes a schema diff for destructive changes.
  ///
  /// Examines the diff and queries the database to estimate data loss,
  /// providing detailed information for error messages.
  ///
  /// [db] - The database connection for querying record counts
  /// [diff] - The schema diff to analyze
  ///
  /// Returns a DestructiveChangeAnalysis with detailed information.
  Future<DestructiveChangeAnalysis> analyze(
    Database db,
    SchemaDiff diff,
  ) async {
    final tableRemovals = <TableRemovalInfo>[];
    final fieldRemovals = <FieldRemovalInfo>[];
    final typeChanges = <TypeChangeInfo>[];
    final constraintTightenings = <ConstraintTighteningInfo>[];

    // Analyze table removals
    for (final tableName in diff.tablesRemoved) {
      final recordCount = await _estimateTableRecordCount(db, tableName);
      tableRemovals.add(
        TableRemovalInfo(
          tableName: tableName,
          estimatedRecords: recordCount,
        ),
      );
    }

    // Analyze field removals
    for (final entry in diff.fieldsRemoved.entries) {
      final tableName = entry.key;
      for (final fieldName in entry.value) {
        // For field removals, we can't easily count non-null values
        // without complex queries, so we estimate based on table size
        final recordCount = await _estimateTableRecordCount(db, tableName);
        fieldRemovals.add(
          FieldRemovalInfo(
            tableName: tableName,
            fieldName: fieldName,
            estimatedAffectedRecords: recordCount,
          ),
        );
      }
    }

    // Analyze field modifications for destructive changes
    for (final entry in diff.fieldsModified.entries) {
      final tableName = entry.key;
      final recordCount = await _estimateTableRecordCount(db, tableName);

      for (final modification in entry.value) {
        if (modification.isDestructive) {
          // Type changes
          if (modification.typeChanged) {
            typeChanges.add(
              TypeChangeInfo(
                tableName: tableName,
                fieldName: modification.fieldName,
                oldType: modification.oldType,
                newType: modification.newType,
                estimatedAffectedRecords: recordCount,
              ),
            );
          }

          // Optional to required (constraint tightening)
          if (modification.optionalityChanged &&
              modification.wasOptional &&
              !modification.isOptional) {
            constraintTightenings.add(
              ConstraintTighteningInfo(
                tableName: tableName,
                fieldName: modification.fieldName,
                changeType: 'Making field required (was optional)',
                estimatedAffectedRecords: recordCount,
              ),
            );
          }

          // ASSERT clause tightening
          if (modification.assertClauseChanged) {
            final hadAssertion = modification.oldAssertClause != null &&
                modification.oldAssertClause!.isNotEmpty;
            final hasAssertion = modification.newAssertClause != null &&
                modification.newAssertClause!.isNotEmpty;

            if (hadAssertion && hasAssertion) {
              constraintTightenings.add(
                ConstraintTighteningInfo(
                  tableName: tableName,
                  fieldName: modification.fieldName,
                  changeType: 'Modifying ASSERT constraint',
                  estimatedAffectedRecords: recordCount,
                ),
              );
            }
          }
        }
      }
    }

    return DestructiveChangeAnalysis(
      tableRemovals: tableRemovals,
      fieldRemovals: fieldRemovals,
      typeChanges: typeChanges,
      constraintTightenings: constraintTightenings,
    );
  }

  /// Generates a detailed error message for destructive changes.
  ///
  /// Creates a comprehensive, actionable error message that lists all
  /// destructive operations, estimates data loss, and provides resolution
  /// options.
  ///
  /// [analysis] - The destructive change analysis
  ///
  /// Returns a formatted error message string.
  String generateDetailedErrorMessage(DestructiveChangeAnalysis analysis) {
    final buffer = StringBuffer();

    buffer.writeln(
      'Destructive schema changes detected and allowDestructiveMigrations=false',
    );
    buffer.writeln();
    buffer.writeln('DESTRUCTIVE CHANGES:');
    buffer.writeln('=' * 80);

    var operationCount = 0;

    // Table removals
    if (analysis.tableRemovals.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Tables to be REMOVED:');
      for (final info in analysis.tableRemovals) {
        operationCount++;
        buffer.writeln(
          '  $operationCount. Table "${info.tableName}" - ${info.estimatedRecords} records will be PERMANENTLY DELETED',
        );
      }
    }

    // Field removals
    if (analysis.fieldRemovals.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Fields to be REMOVED:');
      for (final info in analysis.fieldRemovals) {
        operationCount++;
        final recordText = info.estimatedAffectedRecords == 1
            ? '1 record'
            : '${info.estimatedAffectedRecords} records';
        buffer.writeln(
          '  $operationCount. Field "${info.tableName}.${info.fieldName}" - Data in $recordText will be PERMANENTLY DELETED',
        );
      }
    }

    // Type changes
    if (analysis.typeChanges.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Field TYPE CHANGES (potential data loss):');
      for (final info in analysis.typeChanges) {
        operationCount++;
        final recordText = info.estimatedAffectedRecords == 1
            ? '1 record'
            : '${info.estimatedAffectedRecords} records';
        buffer.writeln(
          '  $operationCount. Field "${info.tableName}.${info.fieldName}"',
        );
        buffer.writeln('      Old type: ${info.oldType}');
        buffer.writeln('      New type: ${info.newType}');
        buffer.writeln(
          '      Impact: Data conversion required for $recordText - may fail or lose precision',
        );
      }
    }

    // Constraint tightenings
    if (analysis.constraintTightenings.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('CONSTRAINT TIGHTENING (may cause validation failures):');
      for (final info in analysis.constraintTightenings) {
        operationCount++;
        final recordText = info.estimatedAffectedRecords == 1
            ? '1 record'
            : '${info.estimatedAffectedRecords} records';
        buffer.writeln(
          '  $operationCount. Field "${info.tableName}.${info.fieldName}"',
        );
        buffer.writeln('      Change: ${info.changeType}');
        buffer.writeln(
          '      Impact: Existing data in $recordText may fail new constraints',
        );
      }
    }

    // Resolution options
    buffer.writeln();
    buffer.writeln('=' * 80);
    buffer.writeln('RESOLUTION OPTIONS:');
    buffer.writeln();
    buffer.writeln('1. ENABLE DESTRUCTIVE MIGRATIONS (if you accept the data loss):');
    buffer.writeln('   Set allowDestructiveMigrations: true when calling migrate()');
    buffer.writeln('   Example:');
    buffer.writeln(
      '     await engine.executeMigration(db, tables, allowDestructiveMigrations: true)',
    );
    buffer.writeln();
    buffer.writeln('2. FIX YOUR SCHEMA (to match the database):');
    buffer.writeln(
      '   Update your Dart code to include the removed tables/fields',
    );
    buffer.writeln('   This prevents data loss by keeping existing schema');
    buffer.writeln();
    buffer.writeln('3. MANUALLY MIGRATE DATA (before applying schema changes):');
    buffer.writeln('   a. Export affected data: await db.export("backup.surql")');
    buffer.writeln('   b. Transform data to match new schema');
    buffer.writeln('   c. Apply migration with allowDestructiveMigrations: true');
    buffer.writeln('   d. Import transformed data');
    buffer.writeln();
    buffer.writeln('=' * 80);

    // Add warning about dry run
    buffer.writeln();
    buffer.writeln('TIP: Use dryRun: true to preview changes without applying:');
    buffer.writeln(
      '  final report = await engine.executeMigration(db, tables, dryRun: true)',
    );

    return buffer.toString();
  }

  /// Estimates the number of records in a table.
  ///
  /// Executes a COUNT query to determine how many records would be affected.
  /// Returns 0 if the query fails or the table doesn't exist.
  Future<int> _estimateTableRecordCount(Database db, String tableName) async {
    try {
      final response = await db.query('SELECT count() FROM $tableName GROUP ALL');
      final results = response.getResults();

      if (results.isEmpty) {
        return 0;
      }

      final result = results.first;
      if (result is Map<String, dynamic> && result.containsKey('count')) {
        final count = result['count'];
        if (count is int) {
          return count;
        } else if (count is num) {
          return count.toInt();
        }
      }

      return 0;
    } catch (e) {
      // If we can't count records, assume 0 (table may not exist yet)
      return 0;
    }
  }
}

/// Complete analysis of destructive changes with estimated impact.
class DestructiveChangeAnalysis {
  /// Creates a destructive change analysis.
  DestructiveChangeAnalysis({
    required this.tableRemovals,
    required this.fieldRemovals,
    required this.typeChanges,
    required this.constraintTightenings,
  });

  /// Information about tables being removed.
  final List<TableRemovalInfo> tableRemovals;

  /// Information about fields being removed.
  final List<FieldRemovalInfo> fieldRemovals;

  /// Information about field type changes.
  final List<TypeChangeInfo> typeChanges;

  /// Information about constraint tightening.
  final List<ConstraintTighteningInfo> constraintTightenings;

  /// Checks if any destructive changes exist.
  bool get hasDestructiveChanges {
    return tableRemovals.isNotEmpty ||
        fieldRemovals.isNotEmpty ||
        typeChanges.isNotEmpty ||
        constraintTightenings.isNotEmpty;
  }

  /// Gets total number of destructive operations.
  int get totalOperations {
    return tableRemovals.length +
        fieldRemovals.length +
        typeChanges.length +
        constraintTightenings.length;
  }
}

/// Information about a table being removed.
class TableRemovalInfo {
  /// Creates table removal information.
  TableRemovalInfo({
    required this.tableName,
    required this.estimatedRecords,
  });

  /// Name of the table being removed.
  final String tableName;

  /// Estimated number of records that will be deleted.
  final int estimatedRecords;
}

/// Information about a field being removed.
class FieldRemovalInfo {
  /// Creates field removal information.
  FieldRemovalInfo({
    required this.tableName,
    required this.fieldName,
    required this.estimatedAffectedRecords,
  });

  /// Name of the table containing the field.
  final String tableName;

  /// Name of the field being removed.
  final String fieldName;

  /// Estimated number of records affected.
  final int estimatedAffectedRecords;
}

/// Information about a field type change.
class TypeChangeInfo {
  /// Creates type change information.
  TypeChangeInfo({
    required this.tableName,
    required this.fieldName,
    required this.oldType,
    required this.newType,
    required this.estimatedAffectedRecords,
  });

  /// Name of the table containing the field.
  final String tableName;

  /// Name of the field with type change.
  final String fieldName;

  /// Original field type.
  final String oldType;

  /// New field type.
  final String newType;

  /// Estimated number of records affected by the type change.
  final int estimatedAffectedRecords;
}

/// Information about constraint tightening.
class ConstraintTighteningInfo {
  /// Creates constraint tightening information.
  ConstraintTighteningInfo({
    required this.tableName,
    required this.fieldName,
    required this.changeType,
    required this.estimatedAffectedRecords,
  });

  /// Name of the table containing the field.
  final String tableName;

  /// Name of the field with tightened constraint.
  final String fieldName;

  /// Description of the constraint change.
  final String changeType;

  /// Estimated number of records affected.
  final int estimatedAffectedRecords;
}
