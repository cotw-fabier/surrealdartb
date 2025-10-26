/// Build_runner generator for SurrealDB table definitions.
///
/// This generator processes @SurrealTable annotated classes and generates
/// TableDefinition objects with field metadata for schema validation and
/// migration support.
library;

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:surrealdartb/src/schema/annotations.dart';

/// Builder factory function for build_runner integration.
///
/// This function is called by build_runner to create instances of the
/// SurrealTableGenerator.
Builder surrealTableBuilder(BuilderOptions options) =>
    SharedPartBuilder([SurrealTableGenerator()], 'surreal_table');

/// Generator for creating TableDefinition classes from @SurrealTable annotations.
///
/// This generator extends GeneratorForAnnotation to process classes annotated
/// with @SurrealTable and generate corresponding .surreal.dart part files
/// containing TableDefinition objects.
///
/// ## Generated Output
///
/// For an annotated class like:
/// ```dart
/// @SurrealTable('users')
/// class User {
///   @SurrealField(type: StringType())
///   final String name;
/// }
/// ```
///
/// Generates a part file with:
/// ```dart
/// part of 'user.dart';
///
/// final userTableDefinition = TableStructure('users', {
///   'name': FieldDefinition(StringType()),
/// });
/// ```
class SurrealTableGenerator extends GeneratorForAnnotation<SurrealTable> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Validate that the annotation is on a class
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@SurrealTable can only be applied to classes',
        element: element,
      );
    }

    // Extract table name from annotation
    final tableName = annotation.read('tableName').stringValue;

    // Validate table name is not empty
    if (tableName.isEmpty) {
      throw InvalidGenerationSourceError(
        '@SurrealTable table name cannot be empty',
        element: element,
      );
    }

    // Validate table name format (basic check)
    if (!_isValidTableName(tableName)) {
      throw InvalidGenerationSourceError(
        '@SurrealTable table name "$tableName" must be a valid identifier: '
        'lowercase letters, numbers, underscores, starting with a letter',
        element: element,
      );
    }

    final className = element.name;
    final fields = _extractFields(element);

    // Generate the TableDefinition code
    return _generateTableDefinition(
      className: className,
      tableName: tableName,
      fields: fields,
    );
  }

  /// Validates that a table name follows SurrealDB naming conventions.
  ///
  /// Valid table names:
  /// - Start with a lowercase letter
  /// - Contain only lowercase letters, numbers, and underscores
  /// - Are not empty
  bool _isValidTableName(String name) {
    if (name.isEmpty) return false;
    final validPattern = RegExp(r'^[a-z][a-z0-9_]*$');
    return validPattern.hasMatch(name);
  }

  /// Extracts field information from a class element.
  ///
  /// Processes all fields annotated with @SurrealField and extracts:
  /// - Field name
  /// - Field type (from annotation)
  /// - Whether field is optional (nullable in Dart)
  /// - Default value
  /// - Assert clause
  /// - Indexed flag
  /// - Dimensions (for vector types)
  List<_FieldInfo> _extractFields(ClassElement classElement) {
    final fields = <_FieldInfo>[];

    // Check for @SurrealField annotations on fields
    final checker = const TypeChecker.fromRuntime(SurrealField);

    for (final field in classElement.fields) {
      final annotation = checker.firstAnnotationOf(field);
      if (annotation == null) {
        // Skip fields without @SurrealField annotation
        continue;
      }

      // Extract annotation parameters
      final annotationReader = ConstantReader(annotation);

      // Get the type from annotation
      final typeObj = annotationReader.read('type').objectValue;

      // Check if field is nullable (optional)
      final isOptional =
          field.type.nullabilitySuffix == NullabilitySuffix.question;

      // Extract other parameters
      final defaultValue = annotationReader.read('defaultValue');
      final assertClause = annotationReader.read('assertClause');
      final indexed = annotationReader.read('indexed').boolValue;
      final dimensions = annotationReader.read('dimensions');

      fields.add(_FieldInfo(
        name: field.name,
        type: typeObj,
        isOptional: isOptional,
        defaultValue: defaultValue.isNull ? null : defaultValue.objectValue,
        assertClause: assertClause.isNull ? null : assertClause.stringValue,
        indexed: indexed,
        dimensions: dimensions.isNull ? null : dimensions.intValue,
      ));
    }

    // Validate that at least one field is annotated
    if (fields.isEmpty) {
      throw InvalidGenerationSourceError(
        '@SurrealTable class must have at least one @SurrealField annotated field',
        element: classElement,
      );
    }

    return fields;
  }

  /// Generates the TableDefinition code.
  ///
  /// Creates a Dart source code string containing the TableStructure
  /// definition with all fields and their metadata.
  String _generateTableDefinition({
    required String className,
    required String tableName,
    required List<_FieldInfo> fields,
  }) {
    final buffer = StringBuffer();

    // Generate part of directive comment
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated by SurrealTableGenerator');
    buffer.writeln();

    // Generate table definition variable
    final varName = '${_camelCase(className)}TableDefinition';
    buffer.writeln('/// TableDefinition for $className');
    buffer.writeln('final $varName = TableStructure(');
    buffer.writeln("  '$tableName',");
    buffer.writeln('  {');

    // Generate field definitions
    for (final field in fields) {
      buffer.writeln('    \'${field.name}\': FieldDefinition(');
      buffer.writeln('      ${_generateTypeExpression(field.type)},');

      if (field.isOptional) {
        buffer.writeln('      optional: true,');
      }

      if (field.defaultValue != null) {
        buffer.writeln(
            '      defaultValue: ${_generateDefaultValue(field.defaultValue!)},');
      }

      buffer.writeln('    ),');
    }

    buffer.writeln('  },');
    buffer.writeln(');');

    return buffer.toString();
  }

  /// Converts a class name to camelCase for variable naming.
  ///
  /// Example: 'UserProfile' -> 'userProfile'
  String _camelCase(String name) {
    if (name.isEmpty) return name;
    return name[0].toLowerCase() + name.substring(1);
  }

  /// Generates a Dart expression for a SurrealType from a DartObject.
  ///
  /// Inspects the DartObject to determine which SurrealType it represents
  /// and generates the appropriate constructor call.
  String _generateTypeExpression(DartObject typeObj) {
    final type = typeObj.type;
    final typeName = type?.element?.name;

    // Handle different SurrealType subclasses
    switch (typeName) {
      case 'StringType':
        return 'StringType()';
      case 'BoolType':
        return 'BoolType()';
      case 'DatetimeType':
        return 'DatetimeType()';
      case 'DurationType':
        return 'DurationType()';
      case 'NumberType':
        return _generateNumberType(typeObj);
      case 'VectorType':
        return _generateVectorType(typeObj);
      case 'ArrayType':
        return _generateArrayType(typeObj);
      case 'ObjectType':
        return _generateObjectType(typeObj);
      case 'RecordType':
        return _generateRecordType(typeObj);
      case 'GeometryType':
        return _generateGeometryType(typeObj);
      case 'AnyType':
        return 'AnyType()';
      default:
        // Fallback for unknown types
        return 'AnyType()';
    }
  }

  /// Generates NumberType expression with format parameter if specified.
  String _generateNumberType(DartObject typeObj) {
    final formatField = typeObj.getField('format');
    if (formatField == null || formatField.isNull) {
      return 'NumberType()';
    }

    final formatName = formatField.getField('_name')?.toStringValue();
    if (formatName == null) {
      return 'NumberType()';
    }

    return 'NumberType(format: NumberFormat.$formatName)';
  }

  /// Generates VectorType expression with format and dimensions.
  String _generateVectorType(DartObject typeObj) {
    final formatField = typeObj.getField('format');
    final dimensionsField = typeObj.getField('dimensions');
    final normalizedField = typeObj.getField('normalized');

    final formatName = formatField?.getField('_name')?.toStringValue();
    final dimensions = dimensionsField?.toIntValue();
    final normalized = normalizedField?.toBoolValue() ?? false;

    if (formatName == null || dimensions == null) {
      throw InvalidGenerationSourceError(
        'VectorType requires format and dimensions to be specified',
      );
    }

    final normalizedStr = normalized ? ', normalized: true' : '';
    return 'VectorType(format: VectorFormat.$formatName, dimensions: $dimensions$normalizedStr)';
  }

  /// Generates ArrayType expression with element type.
  String _generateArrayType(DartObject typeObj) {
    final elementTypeField = typeObj.getField('elementType');
    final lengthField = typeObj.getField('length');

    if (elementTypeField == null) {
      throw InvalidGenerationSourceError(
        'ArrayType requires elementType to be specified',
      );
    }

    final elementTypeExpr = _generateTypeExpression(elementTypeField);
    final length = lengthField?.toIntValue();

    if (length != null) {
      return 'ArrayType($elementTypeExpr, length: $length)';
    }

    return 'ArrayType($elementTypeExpr)';
  }

  /// Generates ObjectType expression.
  String _generateObjectType(DartObject typeObj) {
    // For now, we generate schemaless ObjectType
    // Schema support will be added in Phase 2 (nested objects)
    return 'ObjectType()';
  }

  /// Generates RecordType expression with optional table constraint.
  String _generateRecordType(DartObject typeObj) {
    final tableField = typeObj.getField('table');
    if (tableField == null || tableField.isNull) {
      return 'RecordType()';
    }

    final table = tableField.toStringValue();
    if (table == null) {
      return 'RecordType()';
    }

    return 'RecordType(table: \'$table\')';
  }

  /// Generates GeometryType expression with optional kind constraint.
  String _generateGeometryType(DartObject typeObj) {
    final kindField = typeObj.getField('kind');
    if (kindField == null || kindField.isNull) {
      return 'GeometryType()';
    }

    final kindName = kindField.getField('_name')?.toStringValue();
    if (kindName == null) {
      return 'GeometryType()';
    }

    return 'GeometryType(kind: GeometryKind.$kindName)';
  }

  /// Generates a Dart expression for a default value.
  ///
  /// Handles different types of default values (strings, numbers, booleans, etc.)
  String _generateDefaultValue(DartObject value) {
    // Handle different value types
    if (value.toBoolValue() != null) {
      return value.toBoolValue().toString();
    }
    if (value.toIntValue() != null) {
      return value.toIntValue().toString();
    }
    if (value.toDoubleValue() != null) {
      return value.toDoubleValue().toString();
    }
    if (value.toStringValue() != null) {
      final str = value.toStringValue()!;
      // Escape special characters in strings
      final escaped = str
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
      return "'$escaped'";
    }

    // Fallback to null for unsupported types
    return 'null';
  }
}

/// Internal class to store field information during generation.
class _FieldInfo {
  final String name;
  final DartObject type;
  final bool isOptional;
  final DartObject? defaultValue;
  final String? assertClause;
  final bool indexed;
  final int? dimensions;

  const _FieldInfo({
    required this.name,
    required this.type,
    required this.isOptional,
    this.defaultValue,
    this.assertClause,
    required this.indexed,
    this.dimensions,
  });
}
