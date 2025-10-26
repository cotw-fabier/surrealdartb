/// Tests for schema introspection functionality (Task Group 3.1).
///
/// This test file covers schema introspection using INFO FOR DB and
/// INFO FOR TABLE queries, parsing SurrealDB schema responses, and
/// building schema snapshot data structures.
library;

import 'package:surrealdartb/surrealdartb.dart';
import 'package:test/test.dart';

void main() {
  group('Task Group 3.1: Schema Introspection Tests', () {
    late Database db;

    setUp(() async {
      // Use in-memory database for faster tests
      db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );
    });

    tearDown(() async {
      await db.close();
      // Small delay to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('3.1.1 - INFO FOR DB query executes successfully', () async {
      // Create a test table first
      await db.query('''
        DEFINE TABLE test_users SCHEMAFULL;
        DEFINE FIELD name ON test_users TYPE string;
        DEFINE FIELD age ON test_users TYPE int;
      ''');

      // Execute INFO FOR DB
      final response = await db.query('INFO FOR DB');
      final results = response.getResults();

      // Should return schema information
      expect(results, isNotEmpty);
      expect(results.first, isA<Map<String, dynamic>>());
    });

    test('3.1.2 - INFO FOR DB returns table definitions', () async {
      // Create multiple tables
      await db.query('''
        DEFINE TABLE users SCHEMAFULL;
        DEFINE FIELD username ON users TYPE string;

        DEFINE TABLE posts SCHEMAFULL;
        DEFINE FIELD title ON posts TYPE string;
      ''');

      // Get database schema
      final response = await db.query('INFO FOR DB');
      final results = response.getResults();
      final info = results.first as Map<String, dynamic>;

      // Should contain tables
      expect(info, contains('tables'));
      final tables = info['tables'] as Map<String, dynamic>;
      expect(tables, contains('users'));
      expect(tables, contains('posts'));
    });

    test('3.1.3 - INFO FOR TABLE returns field metadata', () async {
      // Create table with fields
      await db.query('''
        DEFINE TABLE products SCHEMAFULL;
        DEFINE FIELD name ON products TYPE string;
        DEFINE FIELD price ON products TYPE float;
        DEFINE FIELD in_stock ON products TYPE bool;
      ''');

      // Get table schema
      final response = await db.query('INFO FOR TABLE products');
      final results = response.getResults();
      final tableInfo = results.first as Map<String, dynamic>;

      // Should contain fields
      expect(tableInfo, contains('fields'));
      final fields = tableInfo['fields'] as Map<String, dynamic>;
      expect(fields, contains('name'));
      expect(fields, contains('price'));
      expect(fields, contains('in_stock'));
    });

    test('3.1.4 - Parse field type information', () async {
      // Create table with various field types
      await db.query('''
        DEFINE TABLE documents SCHEMAFULL;
        DEFINE FIELD title ON documents TYPE string;
        DEFINE FIELD views ON documents TYPE int;
        DEFINE FIELD rating ON documents TYPE float;
        DEFINE FIELD published ON documents TYPE bool;
        DEFINE FIELD created_at ON documents TYPE datetime;
      ''');

      // Get table schema
      final response = await db.query('INFO FOR TABLE documents');
      final results = response.getResults();
      final tableInfo = results.first as Map<String, dynamic>;
      final fields = tableInfo['fields'] as Map<String, dynamic>;

      // Verify field types exist
      expect(fields['title'], isA<String>());
      expect(fields['views'], isA<String>());
      expect(fields['rating'], isA<String>());
    });

    test('3.1.5 - Parse index definitions', () async {
      // Create table with indexed fields
      await db.query('''
        DEFINE TABLE users SCHEMAFULL;
        DEFINE FIELD email ON users TYPE string;
        DEFINE INDEX idx_email ON users FIELDS email;
      ''');

      // Get table schema
      final response = await db.query('INFO FOR TABLE users');
      final results = response.getResults();
      final tableInfo = results.first as Map<String, dynamic>;

      // Should contain indexes
      expect(tableInfo, contains('indexes'));
      final indexes = tableInfo['indexes'] as Map<String, dynamic>;
      expect(indexes, contains('idx_email'));
    });

    test('3.1.6 - Handle empty database schema', () async {
      // Query schema without any tables defined
      final response = await db.query('INFO FOR DB');
      final results = response.getResults();
      final info = results.first as Map<String, dynamic>;

      // Should return valid structure with empty tables
      expect(info, isA<Map<String, dynamic>>());
      // Tables key may not exist or be empty
      if (info.containsKey('tables')) {
        expect(info['tables'], isA<Map<String, dynamic>>());
      }
    });

    test('3.1.7 - Handle table with ASSERT clauses', () async {
      // Create table with ASSERT constraints
      await db.query('''
        DEFINE TABLE users SCHEMAFULL;
        DEFINE FIELD age ON users TYPE int ASSERT \$value >= 0 AND \$value <= 150;
        DEFINE FIELD email ON users TYPE string ASSERT string::is::email(\$value);
      ''');

      // Get table schema
      final response = await db.query('INFO FOR TABLE users');
      final results = response.getResults();
      final tableInfo = results.first as Map<String, dynamic>;

      // Should contain fields with assertions
      expect(tableInfo, contains('fields'));
      final fields = tableInfo['fields'] as Map<String, dynamic>;
      expect(fields, contains('age'));
      expect(fields, contains('email'));
    });

    test('3.1.8 - Handle optional and required fields', () async {
      // Create table with both optional and required fields
      await db.query('''
        DEFINE TABLE profiles SCHEMAFULL;
        DEFINE FIELD username ON profiles TYPE string;
        DEFINE FIELD bio ON profiles TYPE option<string>;
        DEFINE FIELD avatar_url ON profiles TYPE option<string>;
      ''');

      // Get table schema
      final response = await db.query('INFO FOR TABLE profiles');
      final results = response.getResults();
      final tableInfo = results.first as Map<String, dynamic>;

      // Should contain fields
      expect(tableInfo, contains('fields'));
      final fields = tableInfo['fields'] as Map<String, dynamic>;
      expect(fields, contains('username'));
      expect(fields, contains('bio'));
      expect(fields, contains('avatar_url'));
    });
  });
}
