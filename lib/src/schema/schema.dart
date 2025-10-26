/// SurrealDB schema definition library.
///
/// This library provides types and utilities for defining database schemas
/// with compile-time type safety and runtime validation.
///
/// ## Core Components
///
/// - [SurrealType] - Base sealed class for all type definitions
/// - [FieldDefinition] - Defines a field with type and constraints
/// - [TableStructure] - Defines a complete table schema with validation
/// - Scalar types: [StringType], [NumberType], [BoolType], [DatetimeType], [DurationType]
/// - Collection types: [ArrayType], [ObjectType]
/// - Special types: [RecordType], [GeometryType], [VectorType], [AnyType]
///
/// ## Example Usage
///
/// ```dart
/// import 'package:surrealdartb/src/schema/schema.dart';
///
/// // Define a table schema
/// final schema = TableStructure('documents', {
///   'title': FieldDefinition(StringType()),
///   'price': FieldDefinition(NumberType(format: NumberFormat.decimal)),
///   'tags': FieldDefinition(ArrayType(StringType()), optional: true),
///   'embedding': FieldDefinition(VectorType.f32(1536, normalized: true)),
/// });
///
/// // Validate data
/// schema.validate({
///   'title': 'My Document',
///   'price': 19.99,
///   'embedding': VectorValue.fromList(List.filled(1536, 0.1)).toJson(),
/// });
/// ```
library;

export 'surreal_types.dart';
export 'table_structure.dart';
