/// Unit tests for filtered include SurrealQL generation (Task Group 15).
///
/// These tests verify:
/// - Subquery generation with WHERE filtering (uses $parent correlation)
/// - Subquery generation with LIMIT and ORDER BY
/// - Simple FETCH for includes without filters
/// - Graph relation filtering (unchanged - uses graph syntax)
/// - Complex where conditions in subqueries
/// - Custom foreign key configuration support
/// - Subquery triggered by ORDER BY alone
///
/// **Note:** SurrealDB doesn't support WHERE clauses on FETCH statements.
/// Filtered includes now use correlated subqueries with `$parent.id` instead.
///
/// Total tests: 8 focused tests covering filtered include scenarios
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 15: Filtered Include SurrealQL Generation', () {
    late Map<String, RelationshipMetadata> testRelationships;

    setUp(() {
      // Set up test relationship metadata for various scenarios
      testRelationships = {
        'posts': const RecordLinkMetadata(
          fieldName: 'posts',
          targetType: 'Post',
          isList: true,
          isOptional: true,
          tableName: null,
        ),
        'comments': const RecordLinkMetadata(
          fieldName: 'comments',
          targetType: 'Comment',
          isList: true,
          isOptional: true,
          tableName: null,
        ),
        'tags': const RecordLinkMetadata(
          fieldName: 'tags',
          targetType: 'Tag',
          isList: true,
          isOptional: true,
          tableName: null,
        ),
        'profile': const RecordLinkMetadata(
          fieldName: 'profile',
          targetType: 'Profile',
          isList: false,
          isOptional: false,
          tableName: null,
        ),
        'likedPosts': const GraphRelationMetadata(
          fieldName: 'likedPosts',
          targetType: 'Post',
          isList: true,
          isOptional: true,
          relationName: 'likes',
          direction: RelationDirection.out,
          targetTable: 'posts',
        ),
      };
    });

    // Test 1: Subquery generation with WHERE clause
    test('Test 1: Generate subquery with WHERE condition', () async {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final whereCondition = EqualsCondition('status', 'published');
      final spec = IncludeSpec('posts', where: whereCondition);

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final clause = generateFetchClause(metadata, spec: spec, db: db);

        // Verify subquery structure with $parent correlation
        expect(clause, contains('(SELECT * FROM'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('author = \$parent.id'));
        expect(clause, contains("status = 'published'"));
        expect(clause, endsWith(') AS posts'));
      } finally {
        await db.close();
      }
    });

    // Test 2: Subquery with LIMIT and ORDER BY
    test('Test 2: Generate subquery with LIMIT and ORDER BY', () {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final spec = IncludeSpec(
        'posts',
        limit: 10,
        orderBy: 'createdAt',
        descending: true,
      );

      final clause = generateFetchClause(metadata, spec: spec);

      // Verify subquery with ORDER BY before LIMIT and $parent correlation
      expect(clause, contains('(SELECT * FROM'));
      expect(clause, contains('author = \$parent.id'));
      expect(clause, contains('ORDER BY createdAt DESC'));
      expect(clause, contains('LIMIT 10'));
      expect(clause, matches(RegExp(r'ORDER BY.*LIMIT'))); // Order matters
      expect(clause, endsWith(') AS posts'));
    });

    // Test 3: Simple FETCH without filters (should not use subquery)
    test('Test 3: Generate simple FETCH without filters', () {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      // No spec means no filters, should use simple FETCH
      final clause = generateFetchClause(metadata);

      // Verify simple FETCH syntax (not subquery)
      expect(clause, equals('FETCH posts'));
      expect(clause, isNot(contains('SELECT')));
      expect(clause, isNot(contains('\$parent')));
    });

    // Test 4: Graph relation filtering
    test('Test 4: Generate graph traversal with WHERE clause', () async {
      final metadata = testRelationships['likedPosts'] as GraphRelationMetadata;
      final whereCondition = EqualsCondition('status', 'published');
      final spec = IncludeSpec('likedPosts', where: whereCondition);

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final traversal = generateGraphTraversal(metadata, spec: spec, db: db);

        // Verify graph traversal with WHERE in parentheses
        expect(traversal, contains('->likes->posts'));
        expect(traversal, contains('WHERE'));
        expect(traversal, contains("status = 'published'"));
        expect(traversal, startsWith('('));
        expect(traversal, endsWith(')'));
      } finally {
        await db.close();
      }
    });

    // Test 5: Subquery with complex AND/OR where conditions
    test('Test 5: Generate subquery with complex WHERE condition', () async {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final whereCondition = (EqualsCondition('status', 'published') &
              GreaterThanCondition('views', 100)) |
          EqualsCondition('featured', true);
      final spec = IncludeSpec('posts', where: whereCondition);

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final clause = generateFetchClause(metadata, spec: spec, db: db);

        // Verify subquery with complex condition and $parent correlation
        expect(clause, contains('(SELECT * FROM'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('author = \$parent.id'));
        expect(clause, contains('AND'));
        expect(clause, contains('OR'));
        expect(clause, contains("status = 'published'"));
        expect(clause, contains('views > 100'));
        expect(clause, contains('featured = true'));
        expect(clause, endsWith(') AS posts'));
      } finally {
        await db.close();
      }
    });

    // Test 6: Subquery with all filtering options combined
    test('Test 6: Generate subquery with WHERE, ORDER BY, and LIMIT', () async {
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

        // Verify subquery with correct order: WHERE (with $parent), ORDER BY, LIMIT
        expect(clause, contains('(SELECT * FROM'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('author = \$parent.id'));
        expect(clause, matches(RegExp(r'WHERE.*ORDER BY.*LIMIT')));
        expect(clause, contains('ORDER BY views DESC'));
        expect(clause, contains('LIMIT 5'));
        expect(clause, endsWith(') AS posts'));
      } finally {
        await db.close();
      }
    });

    // Test 7: Subquery with explicit foreignKey from metadata
    test('Test 7: Generate subquery with custom foreign key', () async {
      final customMetadata = const RecordLinkMetadata(
        fieldName: 'posts',
        targetType: 'Post',
        isList: true,
        isOptional: true,
        tableName: null,
        foreignKey: 'user_id', // Custom foreign key
      );
      final spec = IncludeSpec('posts', where: EqualsCondition('status', 'draft'));

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final clause = generateFetchClause(customMetadata, spec: spec, db: db);

        // Verify custom foreign key is used instead of default 'author'
        expect(clause, contains('(SELECT * FROM'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('user_id = \$parent.id')); // Custom key
        expect(clause, isNot(contains('author = \$parent.id'))); // Not default
        expect(clause, contains("status = 'draft'"));
        expect(clause, endsWith(') AS posts'));
      } finally {
        await db.close();
      }
    });

    // Test 8: Verify only ORDER BY triggers subquery
    test('Test 8: Generate subquery when only ORDER BY is specified', () {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final spec = IncludeSpec(
        'posts',
        orderBy: 'createdAt',
        descending: true,
      );

      final clause = generateFetchClause(metadata, spec: spec);

      // Verify that ORDER BY alone triggers subquery generation
      expect(clause, contains('(SELECT * FROM'));
      expect(clause, contains('WHERE author = \$parent.id')); // Still needs correlation
      expect(clause, contains('ORDER BY createdAt DESC'));
      expect(clause, isNot(contains('LIMIT'))); // No LIMIT
      expect(clause, endsWith(') AS posts'));
    });
  });
}
