/// Code generation utilities for relationship metadata.
///
/// This library provides helper functions for generating Dart code
/// that represents relationship metadata in generated files.
library;

import 'package:surrealdartb/src/orm/relationship_metadata.dart';
import 'package:surrealdartb/src/schema/orm_annotations.dart';

/// Generates Dart code for relationship metadata.
class RelationshipCodeGenerator {
  /// Generates a relationship registry as Dart code.
  ///
  /// Returns Dart code defining a static const Map of relationship metadata.
  /// If there are no relationships, returns an empty string.
  static String generateRelationshipRegistry(
    String className,
    Map<String, RelationshipMetadata> relationships,
  ) {
    if (relationships.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('  /// Relationship metadata for $className');
    buffer.writeln('  static const relationshipMetadata = <String, Map<String, dynamic>>{');

    for (final entry in relationships.entries) {
      final fieldName = entry.key;
      final meta = entry.value;

      buffer.writeln("    '$fieldName': {");
      buffer.writeln("      'fieldName': '$fieldName',");
      buffer.writeln("      'targetType': '${meta.targetType}',");
      buffer.writeln("      'isList': ${meta.isList},");
      buffer.writeln("      'isOptional': ${meta.isOptional},");

      // Type-specific metadata
      switch (meta) {
        case RecordLinkMetadata():
          buffer.writeln("      'type': 'RecordLink',");
          final tableName = meta.tableName;
          if (tableName != null) {
            buffer.writeln("      'tableName': '$tableName',");
          }
          buffer.writeln("      'effectiveTableName': '${meta.effectiveTableName}',");

        case GraphRelationMetadata():
          buffer.writeln("      'type': 'GraphRelation',");
          buffer.writeln("      'relationName': '${meta.relationName}',");
          buffer.writeln("      'direction': '${_directionToString(meta.direction)}',");
          final targetTable = meta.targetTable;
          if (targetTable != null) {
            buffer.writeln("      'targetTable': '$targetTable',");
          }
          buffer.writeln("      'effectiveTargetTable': '${meta.effectiveTargetTable}',");

        case EdgeTableMetadata():
          buffer.writeln("      'type': 'EdgeTable',");
          buffer.writeln("      'edgeTableName': '${meta.edgeTableName}',");
          buffer.writeln("      'sourceField': '${meta.sourceField}',");
          buffer.writeln("      'targetField': '${meta.targetField}',");
          buffer.writeln("      'metadataFields': ${_listToString(meta.metadataFields)},");
      }

      buffer.writeln('    },');
    }

    buffer.writeln('  };');

    return buffer.toString();
  }

  /// Generates an auto-include set as Dart code.
  ///
  /// Returns Dart code defining a static const Set of field names
  /// that should be auto-included in queries.
  static String generateAutoIncludes(
    Map<String, RelationshipMetadata> relationships,
  ) {
    final autoIncludes = <String>[];

    for (final entry in relationships.entries) {
      if (!entry.value.isOptional) {
        autoIncludes.add(entry.key);
      }
    }

    if (autoIncludes.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln();
    buffer.writeln('  /// Auto-include fields for non-optional relationships');
    buffer.writeln('  static const autoIncludeRelations = <String>{');
    for (final fieldName in autoIncludes) {
      buffer.writeln("    '$fieldName',");
    }
    buffer.writeln('  };');

    return buffer.toString();
  }

  /// Converts a RelationDirection to a string.
  static String _directionToString(RelationDirection direction) {
    return switch (direction) {
      RelationDirection.out => 'out',
      RelationDirection.inbound => 'inbound',
      RelationDirection.both => 'both',
    };
  }

  /// Converts a list to a Dart list literal string.
  static String _listToString(List<String> list) {
    if (list.isEmpty) {
      return '<String>[]';
    }
    final items = list.map((item) => "'$item'").join(', ');
    return '<String>[$items]';
  }
}
