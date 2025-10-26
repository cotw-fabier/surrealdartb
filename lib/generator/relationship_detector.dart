/// Relationship detection utilities for ORM code generation.
///
/// This library provides helper functions for detecting and extracting
/// relationship metadata from annotated class fields during code generation.
library;

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';
import 'package:surrealdartb/src/orm/relationship_metadata.dart';
import 'package:surrealdartb/src/schema/orm_annotations.dart';

/// Relationship detector for code generation.
///
/// This class provides methods for extracting relationship metadata
/// from class fields annotated with relationship annotations.
class RelationshipDetector {
  /// Extracts all relationship metadata from a class element.
  ///
  /// Scans fields for:
  /// - @SurrealRecord annotations (record links)
  /// - @SurrealRelation annotations (graph traversal)
  ///
  /// Returns a map of field names to their relationship metadata.
  static Map<String, RelationshipMetadata> extractRelationships(
    ClassElement classElement,
  ) {
    final relationships = <String, RelationshipMetadata>{};

    final recordChecker = const TypeChecker.fromRuntime(SurrealRecord);
    final relationChecker = const TypeChecker.fromRuntime(SurrealRelation);

    for (final field in classElement.fields) {
      // Skip static fields
      if (field.isStatic) continue;

      // Check for @SurrealRecord
      final recordAnnotation = recordChecker.firstAnnotationOf(field);
      if (recordAnnotation != null) {
        relationships[field.name] =
            extractRecordLinkMetadata(field, recordAnnotation);
        continue;
      }

      // Check for @SurrealRelation
      final relationAnnotation = relationChecker.firstAnnotationOf(field);
      if (relationAnnotation != null) {
        relationships[field.name] =
            extractGraphRelationMetadata(field, relationAnnotation);
        continue;
      }
    }

    return relationships;
  }

  /// Extracts record link metadata from a field.
  ///
  /// Reads the @SurrealRecord annotation and field type information
  /// to create RecordLinkMetadata.
  static RecordLinkMetadata extractRecordLinkMetadata(
    FieldElement field,
    DartObject annotation,
  ) {
    final reader = ConstantReader(annotation);
    final tableName = reader.read('tableName');

    // Determine if this is a list relationship
    final fieldType = field.type;
    final isList = isListType(fieldType);
    final isOptional =
        fieldType.nullabilitySuffix == NullabilitySuffix.question;

    // Extract target type
    final targetType = extractTargetType(fieldType);

    return RecordLinkMetadata(
      fieldName: field.name,
      targetType: targetType,
      isList: isList,
      isOptional: isOptional,
      tableName: tableName.isNull ? null : tableName.stringValue,
    );
  }

  /// Extracts graph relation metadata from a field.
  ///
  /// Reads the @SurrealRelation annotation and field type information
  /// to create GraphRelationMetadata.
  static GraphRelationMetadata extractGraphRelationMetadata(
    FieldElement field,
    DartObject annotation,
  ) {
    final reader = ConstantReader(annotation);
    final relationName = reader.read('name').stringValue;
    final directionField = reader.read('direction');
    final targetTable = reader.read('targetTable');

    // Extract direction enum value
    final directionName =
        directionField.objectValue.getField('_name')?.toStringValue() ?? 'out';

    // Convert string to enum
    final direction = switch (directionName) {
      'out' => RelationDirection.out,
      'inbound' => RelationDirection.inbound,
      'both' => RelationDirection.both,
      _ => RelationDirection.out,
    };

    // Determine if this is a list relationship
    final fieldType = field.type;
    final isList = isListType(fieldType);
    final isOptional =
        fieldType.nullabilitySuffix == NullabilitySuffix.question;

    // Extract target type
    final targetType = extractTargetType(fieldType);

    return GraphRelationMetadata(
      fieldName: field.name,
      targetType: targetType,
      isList: isList,
      isOptional: isOptional,
      relationName: relationName,
      direction: direction,
      targetTable: targetTable.isNull ? null : targetTable.stringValue,
    );
  }

  /// Checks if a type is a List type.
  static bool isListType(DartType type) {
    if (type is InterfaceType) {
      return type.element.name == 'List';
    }
    return false;
  }

  /// Extracts the target type name from a field type.
  ///
  /// For List<T>, returns T's name.
  /// For T, returns T's name.
  static String extractTargetType(DartType type) {
    if (type is InterfaceType) {
      if (type.element.name == 'List' && type.typeArguments.isNotEmpty) {
        // For List<T>, get T
        final elementType = type.typeArguments.first;
        return elementType.element?.name ?? 'dynamic';
      }
      // For single type
      return type.element.name;
    }
    return 'dynamic';
  }

  /// Gets the set of field names for non-optional relationships.
  ///
  /// Non-optional relationships should be auto-included in queries.
  static Set<String> getAutoIncludeFields(
    Map<String, RelationshipMetadata> relationships,
  ) {
    final autoIncludes = <String>{};

    for (final entry in relationships.entries) {
      if (!entry.value.isOptional) {
        autoIncludes.add(entry.key);
      }
    }

    return autoIncludes;
  }
}
