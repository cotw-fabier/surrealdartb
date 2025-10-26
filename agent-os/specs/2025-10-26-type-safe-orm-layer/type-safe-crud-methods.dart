// ============================================================================
// Type-Safe CRUD Operations (Task Group 5)
// ============================================================================
// INSERT THESE METHODS IN lib/src/database.dart AFTER line 1408 (after the query() method)

  /// Creates a new record using a type-safe Dart object.
  ///
  /// This method provides a type-safe alternative to [createQL] by accepting
  /// a Dart object instead of a Map. The object is automatically serialized
  /// using its generated `toSurrealMap()` method, validated against its schema,
  /// and the result is deserialized back into the same type.
  ///
  /// The table name is automatically extracted from the object's `@SurrealTable`
  /// annotation via the generated `tableName` getter.
  ///
  /// Parameters:
  /// - [object] - The typed Dart object to create in the database
  ///
  /// Returns the created object with any auto-generated fields populated.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [OrmValidationException] if validation fails
  /// - [QueryException] if create operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// @SurrealTable('users')
  /// class User {
  ///   @SurrealField(type: StringType())
  ///   final String? id;
  ///
  ///   @SurrealField(type: StringType())
  ///   final String name;
  ///
  ///   User({this.id, required this.name});
  /// }
  ///
  /// final user = User(name: 'Alice');
  /// final created = await db.create(user);
  /// print('Created user: ${created.id}');
  /// ```
  Future<T> create<T>(T object) async {
    _ensureNotClosed();

    return Future(() async {
      // Access generated extension methods via dynamic cast
      final extension = object as dynamic;

      // Extract table name from generated static getter
      final tableName = extension.tableName as String;

      // Extract TableStructure from generated static getter
      final tableStructure = extension.tableStructure as TableStructure;

      // Validate object before sending
      try {
        tableStructure.validate(extension.toSurrealMap());
      } on ValidationException catch (e) {
        throw OrmValidationException(
          'Validation failed for ${T.toString()}',
          field: e.fieldName,
          constraint: e.constraint,
          cause: e,
        );
      }

      // Serialize object to map
      final Map<String, dynamic> data = extension.toSurrealMap();

      // Call existing createQL method
      final result = await createQL(tableName, data);

      // Deserialize result back to typed object
      return extension.fromSurrealMap(result) as T;
    });
  }

  /// Updates an existing record using a type-safe Dart object.
  ///
  /// This method provides a type-safe alternative to [updateQL] by accepting
  /// a Dart object instead of a Map. The object's ID is automatically extracted
  /// using the generated `recordId` getter, the object is serialized and validated,
  /// and the result is deserialized back into the same type.
  ///
  /// The table name is automatically extracted from the object's `@SurrealTable`
  /// annotation via the generated `tableName` getter.
  ///
  /// Parameters:
  /// - [object] - The typed Dart object to update in the database
  ///
  /// Returns the updated object.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ArgumentError] if object ID is null or empty
  /// - [OrmValidationException] if validation fails
  /// - [QueryException] if update operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// final user = await db.get<User>('users:alice');
  /// final updated = User(id: user.id, name: 'Alice Updated');
  /// final result = await db.update(updated);
  /// print('Updated user: ${result.name}');
  /// ```
  Future<T> update<T>(T object) async {
    _ensureNotClosed();

    return Future(() async {
      // Access generated extension methods via dynamic cast
      final extension = object as dynamic;

      // Extract ID from object using generated recordId getter
      final id = extension.recordId;
      if (id == null || (id is String && id.isEmpty)) {
        throw ArgumentError.value(
          id,
          'object.recordId',
          'Object ID cannot be null or empty for update operation',
        );
      }

      // Extract table name from generated static getter
      final tableName = extension.tableName as String;

      // Extract TableStructure from generated static getter
      final tableStructure = extension.tableStructure as TableStructure;

      // Validate object before sending
      try {
        tableStructure.validate(extension.toSurrealMap());
      } on ValidationException catch (e) {
        throw OrmValidationException(
          'Validation failed for ${T.toString()}',
          field: e.fieldName,
          constraint: e.constraint,
          cause: e,
        );
      }

      // Serialize object to map
      final Map<String, dynamic> data = extension.toSurrealMap();

      // Build resource identifier (table:id)
      final resource = '$tableName:$id';

      // Call existing updateQL method
      final result = await updateQL(resource, data);

      // Deserialize result back to typed object
      return extension.fromSurrealMap(result) as T;
    });
  }

  /// Deletes a record using a type-safe Dart object.
  ///
  /// This method provides a type-safe alternative to [deleteQL] by accepting
  /// a Dart object instead of a resource string. The object's ID and table name
  /// are automatically extracted from the object using generated methods.
  ///
  /// Parameters:
  /// - [object] - The typed Dart object to delete from the database
  ///
  /// Returns a Future that completes when the delete operation succeeds.
  ///
  /// Throws:
  /// - [StateError] if database is closed
  /// - [ArgumentError] if object ID is null or empty
  /// - [QueryException] if delete operation fails
  /// - [DatabaseException] for other errors
  ///
  /// Example:
  /// ```dart
  /// final user = await db.get<User>('users:alice');
  /// await db.delete(user);
  /// print('Deleted user: ${user.id}');
  /// ```
  Future<void> delete<T>(T object) async {
    _ensureNotClosed();

    return Future(() async {
      // Access generated extension methods via dynamic cast
      final extension = object as dynamic;

      // Extract ID from object using generated recordId getter
      final id = extension.recordId;
      if (id == null || (id is String && id.isEmpty)) {
        throw ArgumentError.value(
          id,
          'object.recordId',
          'Object ID cannot be null or empty for delete operation',
        );
      }

      // Extract table name from generated static getter
      final tableName = extension.tableName as String;

      // Build resource identifier (table:id)
      final resource = '$tableName:$id';

      // Call existing deleteQL method
      await deleteQL(resource);
    });
  }
