/// SurrealDB Dart FFI bindings library.
///
/// This library provides a high-level, Future-based API for interacting
/// with SurrealDB through native FFI bindings. All operations are performed
/// asynchronously using direct FFI calls to ensure non-blocking behavior.
///
/// ## Features
///
/// - **Async Operations**: All database operations return Futures and execute
///   asynchronously, preventing UI blocking.
/// - **Memory Safety**: Automatic memory management using NativeFinalizer
///   ensures no memory leaks.
/// - **Storage Backends**: Support for in-memory (mem://) and persistent
///   (RocksDB) storage.
/// - **Type Safety**: Full Dart null safety and strong typing throughout.
/// - **Error Handling**: Clear exception hierarchy for different error types.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:surrealdartb/surrealdartb.dart';
///
/// void main() async {
///   // Connect to an in-memory database
///   final db = await Database.connect(
///     backend: StorageBackend.memory,
///     namespace: 'test',
///     database: 'test',
///   );
///
///   try {
///     // Create a record
///     final person = await db.create('person', {
///       'name': 'John Doe',
///       'age': 30,
///     });
///     print('Created: ${person['id']}');
///
///     // Query records
///     final response = await db.query('SELECT * FROM person');
///     final results = response.getResults();
///     print('Found ${results.length} persons');
///
///     // Select all from table
///     final persons = await db.select('person');
///     for (final p in persons) {
///       print('${p['name']}: ${p['age']}');
///     }
///   } finally {
///     // Always close the database
///     await db.close();
///   }
/// }
/// ```
///
/// ## Storage Backends
///
/// ### In-Memory (Development/Testing)
/// ```dart
/// final db = await Database.connect(
///   backend: StorageBackend.memory,
/// );
/// ```
///
/// ### RocksDB (Production/Persistent)
/// ```dart
/// final db = await Database.connect(
///   backend: StorageBackend.rocksdb,
///   path: '/data/mydb',
/// );
/// ```
///
/// ## Error Handling
///
/// The library throws specific exception types for different error scenarios:
///
/// ```dart
/// try {
///   final db = await Database.connect(
///     backend: StorageBackend.rocksdb,
///     path: '/invalid/path',
///   );
/// } on ConnectionException catch (e) {
///   print('Connection failed: ${e.message}');
/// } on QueryException catch (e) {
///   print('Query failed: ${e.message}');
/// } on DatabaseException catch (e) {
///   print('Database error: ${e.message}');
/// }
/// ```
library;

// Public API exports
export 'src/database.dart' show Database;
export 'src/exceptions.dart'
    show
        DatabaseException,
        ConnectionException,
        QueryException,
        AuthenticationException,
        TransactionException,
        LiveQueryException,
        ParameterException,
        ExportException,
        ImportException,
        ValidationException,
        SchemaIntrospectionException,
        MigrationException,
        MigrationReport,
        // ORM exceptions (Task Group 3)
        OrmException,
        OrmValidationException,
        OrmSerializationException,
        OrmRelationshipException,
        OrmQueryException;
export 'src/response.dart' show Response;
export 'src/storage_backend.dart' show StorageBackend, StorageBackendExt;
export 'src/types/types.dart'
    show
        RecordId,
        Datetime,
        SurrealDuration,
        PatchOp,
        PatchOperation,
        Jwt,
        Credentials,
        RootCredentials,
        NamespaceCredentials,
        DatabaseCredentials,
        ScopeCredentials,
        RecordCredentials,
        Notification,
        NotificationAction,
        VectorValue,
        VectorFormat;
export 'src/schema/schema.dart'
    show
        SurrealType,
        StringType,
        NumberType,
        NumberFormat,
        BoolType,
        DatetimeType,
        DurationType,
        ArrayType,
        ObjectType,
        RecordType,
        GeometryType,
        GeometryKind,
        VectorType,
        AnyType,
        FieldDefinition,
        TableStructure;
export 'src/schema/introspection.dart'
    show DatabaseSchema, TableSchema, FieldSchema, IndexSchema;
export 'src/schema/diff_engine.dart' show SchemaDiff, FieldModification;
export 'src/schema/ddl_generator.dart' show DdlGenerator;
export 'src/schema/migration_engine.dart' show MigrationEngine;
export 'src/schema/migration_history.dart'
    show MigrationHistory, MigrationRecord;
export 'src/schema/orm_annotations.dart'
    show
        SurrealRecord,
        SurrealRelation,
        RelationDirection,
        SurrealEdge,
        SurrealId;
// ORM core classes (Task Groups 8-9)
export 'src/orm/where_condition.dart'
    show
        WhereCondition,
        // Logical operators
        AndCondition,
        OrCondition,
        // Equality and comparison
        EqualsCondition,
        GreaterThanCondition,
        LessThanCondition,
        GreaterOrEqualCondition,
        LessOrEqualCondition,
        BetweenCondition,
        // String conditions
        ContainsCondition,
        IlikeCondition,
        StartsWithCondition,
        EndsWithCondition,
        InListCondition;
export 'src/orm/where_builder.dart'
    show
        StringFieldCondition,
        NumberFieldCondition,
        BoolFieldCondition,
        DateTimeFieldCondition;

// Internal implementation details are NOT exported
// - src/ffi/* (FFI bindings and native types)
