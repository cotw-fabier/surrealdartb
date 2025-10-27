/// Annotations for automatic SurrealDB table definition generation.
///
/// This library provides decorators that enable build_runner code generation
/// to automatically create TableDefinition classes from annotated Dart classes.
///
/// ## Usage Example
///
/// ```dart
/// @SurrealTable('users')
/// class User {
///   @SurrealField(type: StringType())
///   final String id;
///
///   @SurrealField(type: StringType())
///   final String name;
///
///   @SurrealField(
///     type: NumberType(format: NumberFormat.integer),
///     assertClause: r'$value >= 0',
///     indexed: false,
///   )
///   final int age;
///
///   @SurrealField(type: StringType(), defaultValue: 'active')
///   final String status;
///
///   @SurrealField(
///     type: VectorType(format: VectorFormat.f32, dimensions: 384),
///     dimensions: 384,
///   )
///   final List<double> embedding;
///
///   @JsonField()
///   final Map<String, dynamic> metadata;
///
///   const User({
///     required this.id,
///     required this.name,
///     required this.age,
///     required this.status,
///     required this.embedding,
///     required this.metadata,
///   });
/// }
/// ```
///
/// After running `dart run build_runner build`, a file `user.surreal.dart`
/// will be generated containing a TableDefinition for the User class.
library;

import 'surreal_types.dart';

/// Marks a Dart class as a SurrealDB table for code generation.
///
/// When applied to a class, this annotation triggers the build_runner generator
/// to create a TableDefinition class based on the annotated fields.
///
/// The [tableName] parameter specifies the name of the table in SurrealDB.
/// It should be a valid SurrealDB identifier (lowercase, alphanumeric, underscores).
///
/// ## Example
///
/// ```dart
/// @SurrealTable('users')
/// class User {
///   @SurrealField(type: StringType())
///   final String name;
/// }
/// ```
///
/// Generates a table definition:
/// ```dart
/// final userTableDefinition = TableDefinition(
///   tableName: 'users',
///   fields: {
///     'name': FieldDefinition(StringType()),
///   },
/// );
/// ```
class SurrealTable {
  /// The name of the table in SurrealDB.
  ///
  /// Should be a valid SurrealDB table identifier:
  /// - Lowercase letters, numbers, underscores
  /// - Must start with a letter
  /// - No spaces or special characters (except underscore)
  ///
  /// Examples: 'users', 'blog_posts', 'user_profiles'
  final String tableName;

  /// Creates a SurrealTable annotation.
  ///
  /// The [tableName] parameter is required and specifies the table name
  /// in the SurrealDB database.
  const SurrealTable(this.tableName);
}

/// Marks a field for inclusion in the generated table definition.
///
/// This annotation provides metadata about the field's database schema:
/// - **type**: The SurrealDB type (required)
/// - **defaultValue**: Default value for the field in the database
/// - **assertClause**: SurrealQL assertion expression for validation
/// - **indexed**: Whether to create an index on this field
/// - **dimensions**: Vector dimensions (required for vector types)
///
/// ## Basic Field Example
///
/// ```dart
/// @SurrealField(type: StringType())
/// final String name;
/// ```
///
/// ## Field with Constraints
///
/// ```dart
/// @SurrealField(
///   type: NumberType(format: NumberFormat.integer),
///   assertClause: r'$value >= 18',
///   defaultValue: 18,
///   indexed: true,
/// )
/// final int age;
/// ```
///
/// ## Vector Field Example
///
/// ```dart
/// @SurrealField(
///   type: VectorType(format: VectorFormat.f32, dimensions: 1536),
///   dimensions: 1536,
/// )
/// final List<double> embedding;
/// ```
///
/// ## Nullable Fields
///
/// For nullable Dart types, the generated FieldDefinition will have
/// `optional: true`:
///
/// ```dart
/// @SurrealField(type: StringType())
/// final String? optionalField;  // Generated with optional: true
/// ```
class SurrealField {
  /// The SurrealDB type for this field.
  ///
  /// This is a required parameter that specifies how the field should be
  /// stored in the database. Use one of the SurrealType subclasses:
  /// - StringType()
  /// - NumberType()
  /// - BoolType()
  /// - DatetimeType()
  /// - DurationType()
  /// - ArrayType(elementType)
  /// - ObjectType()
  /// - VectorType(format: ..., dimensions: n)
  /// - etc.
  final SurrealType type;

  /// Default value for the field in the database.
  ///
  /// This value is used when inserting records that don't provide a value
  /// for this field. The default is defined in the database schema, not
  /// in Dart constructors.
  ///
  /// Example:
  /// ```dart
  /// @SurrealField(type: StringType(), defaultValue: 'active')
  /// final String status;
  /// ```
  ///
  /// Generates: `DEFINE FIELD status ON users TYPE string DEFAULT 'active'`
  final dynamic defaultValue;

  /// SurrealQL assertion expression for field validation.
  ///
  /// This expression is evaluated when data is inserted or updated in the
  /// database. Use `$value` to refer to the field's value.
  ///
  /// Example:
  /// ```dart
  /// @SurrealField(
  ///   type: NumberType(),
  ///   assertClause: r'$value >= 0 AND $value <= 100',
  /// )
  /// final int percentage;
  /// ```
  ///
  /// Generates: `ASSERT $value >= 0 AND $value <= 100`
  final String? assertClause;

  /// Whether to create an index on this field.
  ///
  /// When true, the generator will create a DEFINE INDEX statement for
  /// this field, improving query performance for lookups on this field.
  ///
  /// Example:
  /// ```dart
  /// @SurrealField(type: StringType(), indexed: true)
  /// final String email;
  /// ```
  ///
  /// Generates: `DEFINE INDEX idx_email ON users FIELDS email`
  final bool indexed;

  /// Whether this field is optional (can be omitted).
  ///
  /// When true, the field can be omitted from inserts/updates and will use
  /// the [defaultValue] if specified. When false, the field is required.
  ///
  /// Note: This is typically inferred from the Dart type (nullable vs non-nullable),
  /// but can be explicitly set if needed.
  ///
  /// Example:
  /// ```dart
  /// @SurrealField(type: StringType(), optional: true)
  /// String? bio;
  /// ```
  final bool optional;

  /// Vector dimensions for vector type fields.
  ///
  /// This parameter is required when [type] is VectorType. It specifies
  /// the number of dimensions in the vector embedding.
  ///
  /// Example:
  /// ```dart
  /// @SurrealField(
  ///   type: VectorType(format: VectorFormat.f32, dimensions: 384),
  ///   dimensions: 384,
  /// )
  /// final List<double> embedding;
  /// ```
  ///
  /// Generates: `DEFINE FIELD embedding ON documents TYPE array<float, 384>`
  final int? dimensions;

  /// Creates a SurrealField annotation.
  ///
  /// The [type] parameter is required. All other parameters are optional.
  ///
  /// For vector fields, both [type] should be VectorType and [dimensions]
  /// should be specified with the same dimension count.
  const SurrealField({
    required this.type,
    this.optional = false,
    this.defaultValue,
    this.assertClause,
    this.indexed = false,
    this.dimensions,
  });
}

/// Marks a field for JSON serialization in the generated code.
///
/// This annotation is used for complex types (Map, custom objects) that need
/// to be serialized to JSON for storage in SurrealDB object fields.
///
/// ## Example
///
/// ```dart
/// @SurrealField(type: ObjectType())
/// @JsonField()
/// final Map<String, dynamic> metadata;
/// ```
///
/// The generator will create JSON serialization/deserialization code for
/// this field, similar to json_serializable package behavior.
///
/// For custom class types:
/// ```dart
/// @SurrealField(type: ObjectType(schema: {...}))
/// @JsonField()
/// final CustomData data;
/// ```
///
/// The generator will use `.toJson()` and `.fromJson()` methods if available,
/// or fall back to `.toString()` for types without explicit converters.
class JsonField {
  /// Creates a JsonField annotation.
  const JsonField();
}
