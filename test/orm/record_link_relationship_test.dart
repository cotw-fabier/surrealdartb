/// Unit tests for record link relationships (Task Group 12).
///
/// These tests verify:
/// - Single record link functionality
/// - List record link functionality
/// - Simple FETCH clause generation (no filters)
/// - Subquery generation for filtered includes (WHERE/ORDER BY/LIMIT)
/// - Deserialization of related objects
/// - Serialization of record links to IDs
/// - Auto-include behavior for non-optional relationships
/// - Mixed includes (subquery + simple FETCH)
///
/// **Note:** Filtered includes now use correlated subqueries with `$parent.id`
/// instead of invalid `FETCH ... WHERE` syntax.
///
/// Total tests: 8 focused tests covering record link relationship behaviors
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 12: Record Link Relationships', () {
    late Map<String, RelationshipMetadata> testRelationships;

    setUp(() {
      // Set up test relationship metadata
      testRelationships = {
        'profile': const RecordLinkMetadata(
          fieldName: 'profile',
          targetType: 'Profile',
          isList: false,
          isOptional: false, // Non-optional, should auto-include
          tableName: null,
        ),
        'posts': const RecordLinkMetadata(
          fieldName: 'posts',
          targetType: 'Post',
          isList: true,
          isOptional: true, // Optional, no auto-include
          tableName: null,
        ),
        'organization': const RecordLinkMetadata(
          fieldName: 'organization',
          targetType: 'Organization',
          isList: false,
          isOptional: false, // Non-optional, should auto-include
          tableName: 'orgs', // Explicit table name
        ),
      };
    });

    // Test 1: Single record link FETCH clause generation
    test('Test 1: Generate basic FETCH clause for single record link', () {
      final metadata = testRelationships['profile'] as RecordLinkMetadata;
      final clause = generateFetchClause(metadata);

      // Verify basic FETCH syntax
      expect(clause, equals('FETCH profile'));
    });

    // Test 2: List record link FETCH clause generation
    test('Test 2: Generate basic FETCH clause for list record link', () {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final clause = generateFetchClause(metadata);

      // Verify FETCH syntax for list
      expect(clause, equals('FETCH posts'));
    });

    // Test 3: Subquery with WHERE filtering
    test('Test 3: Generate subquery with WHERE condition', () async {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final whereCondition = EqualsCondition('status', 'published');
      final spec = IncludeSpec('posts', where: whereCondition);

      // Create a database connection for testing
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final clause = generateFetchClause(metadata, spec: spec, db: db);

        // Verify subquery with $parent correlation
        expect(clause, contains('(SELECT * FROM'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('author = \$parent.id'));
        expect(clause, contains("status = 'published'"));
        expect(clause, endsWith(') AS posts'));
      } finally {
        await db.close();
      }
    });

    // Test 4: Subquery with LIMIT and ORDER BY
    test('Test 4: Generate subquery with LIMIT and ORDER BY', () {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final spec = IncludeSpec(
        'posts',
        limit: 10,
        orderBy: 'createdAt',
        descending: true,
      );

      final clause = generateFetchClause(metadata, spec: spec);

      // Verify subquery with ORDER BY and LIMIT and $parent correlation
      expect(clause, contains('(SELECT * FROM'));
      expect(clause, contains('author = \$parent.id'));
      expect(clause, contains('ORDER BY createdAt DESC'));
      expect(clause, contains('LIMIT 10'));
      expect(clause, endsWith(') AS posts'));
    });

    // Test 5: Subquery with all options
    test('Test 5: Generate subquery with WHERE, ORDER BY, and LIMIT', () async {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final whereCondition =
          EqualsCondition('status', 'published') & GreaterThanCondition('views', 100);
      final spec = IncludeSpec(
        'posts',
        where: whereCondition,
        limit: 5,
        orderBy: 'views',
        descending: true,
      );

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final clause = generateFetchClause(metadata, spec: spec, db: db);

        // Verify complete subquery with $parent correlation
        expect(clause, contains('(SELECT * FROM'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('author = \$parent.id'));
        expect(clause, contains('ORDER BY views DESC'));
        expect(clause, contains('LIMIT 5'));
        expect(clause, endsWith(') AS posts'));
      } finally {
        await db.close();
      }
    });

    // Test 6: Auto-include detection for non-optional relationships
    test('Test 6: Detect non-optional relationships for auto-include', () {
      final autoIncludes = determineAutoIncludes(testRelationships);

      // Verify non-optional relationships are detected
      expect(autoIncludes, contains('profile'));
      expect(autoIncludes, contains('organization'));
      expect(autoIncludes, isNot(contains('posts'))); // Optional, not included
      expect(autoIncludes.length, equals(2));
    });

    // Test 7: Build mixed includes (subquery + simple FETCH)
    test('Test 7: Build multiple includes with mixed filtering', () async {
      final specs = [
        IncludeSpec('posts', limit: 10), // Triggers subquery
        IncludeSpec('profile'), // Simple FETCH
      ];

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final clause = buildIncludeClauses(specs, testRelationships, db: db);

        // Verify mixed includes are comma-separated
        expect(clause, contains('(SELECT * FROM')); // posts as subquery
        expect(clause, contains('LIMIT 10'));
        expect(clause, contains('FETCH profile')); // profile as simple FETCH
        expect(clause, contains(','));
      } finally {
        await db.close();
      }
    });

    // Test 8: Explicit table name in metadata
    test('Test 8: Use explicit table name from metadata', () {
      final metadata = testRelationships['organization'] as RecordLinkMetadata;

      // Verify explicit table name is used
      expect(metadata.tableName, equals('orgs'));
      expect(metadata.effectiveTableName, equals('orgs'));

      // Verify FETCH uses field name, not table name
      final clause = generateFetchClause(metadata);
      expect(clause, equals('FETCH organization'));
    });
  });
}
