/// Unit tests for filtered include SurrealQL generation (Task Group 15).
///
/// These tests verify:
/// - FETCH clauses with WHERE filtering
/// - FETCH clauses with LIMIT and ORDER BY
/// - Nested FETCH with independent filters at each level
/// - Graph relation filtering
/// - Complex where conditions in includes
/// - Multi-level nested includes with filtering
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

    // Test 1: FETCH with WHERE clause generation
    test('Test 1: Generate FETCH clause with WHERE condition', () async {
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

        // Verify FETCH with WHERE clause
        expect(clause, contains('FETCH posts'));
        expect(clause, contains('WHERE'));
        expect(clause, contains("status = 'published'"));
      } finally {
        await db.close();
      }
    });

    // Test 2: FETCH with LIMIT and ORDER BY
    test('Test 2: Generate FETCH with LIMIT and ORDER BY', () {
      final metadata = testRelationships['posts'] as RecordLinkMetadata;
      final spec = IncludeSpec(
        'posts',
        limit: 10,
        orderBy: 'createdAt',
        descending: true,
      );

      final clause = generateFetchClause(metadata, spec: spec);

      // Verify ORDER BY comes before LIMIT
      expect(clause, equals('FETCH posts ORDER BY createdAt DESC LIMIT 10'));
    });

    // Test 3: Nested FETCH with independent filters at each level
    test('Test 3: Generate nested FETCH with independent filters', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final specs = [
          IncludeSpec(
            'posts',
            where: EqualsCondition('status', 'published'),
            limit: 5,
            include: [
              IncludeSpec(
                'comments',
                where: EqualsCondition('approved', true),
                limit: 10,
              ),
              IncludeSpec('tags'),
            ],
          ),
        ];

        final clause = buildIncludeClauses(specs, testRelationships, db: db);

        // Verify nested structure with independent filters
        expect(clause, contains('FETCH posts'));
        expect(clause, contains("status = 'published'"));
        expect(clause, contains('LIMIT 5'));
        expect(clause, contains('FETCH comments'));
        expect(clause, contains('approved = true'));
        expect(clause, contains('LIMIT 10'));
        expect(clause, contains('FETCH tags'));

        // Verify nesting syntax with braces
        expect(clause, contains('{'));
        expect(clause, contains('}'));
      } finally {
        await db.close();
      }
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

    // Test 5: FETCH with complex AND/OR where conditions
    test('Test 5: Generate FETCH with complex WHERE condition', () async {
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

        // Verify complex condition with proper parentheses
        expect(clause, contains('FETCH posts'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('AND'));
        expect(clause, contains('OR'));
        expect(clause, contains("status = 'published'"));
        expect(clause, contains('views > 100'));
        expect(clause, contains('featured = true'));
      } finally {
        await db.close();
      }
    });

    // Test 6: FETCH with all filtering options combined
    test('Test 6: Generate FETCH with WHERE, ORDER BY, and LIMIT', () async {
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

        // Verify correct order: WHERE, ORDER BY, LIMIT
        expect(clause, contains('FETCH posts'));
        expect(clause, contains('WHERE'));
        expect(clause, matches(RegExp(r'WHERE.*ORDER BY.*LIMIT')));
        expect(clause, contains('ORDER BY views DESC'));
        expect(clause, contains('LIMIT 5'));
      } finally {
        await db.close();
      }
    });

    // Test 7: Multi-level nested includes with filtering at each level
    test('Test 7: Generate multi-level nested includes with filtering', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Three levels deep: user -> posts -> comments
        final specs = [
          IncludeSpec(
            'posts',
            where: EqualsCondition('status', 'published'),
            orderBy: 'createdAt',
            descending: true,
            limit: 10,
            include: [
              IncludeSpec(
                'comments',
                where: EqualsCondition('approved', true),
                orderBy: 'createdAt',
                limit: 5,
                include: [
                  IncludeSpec('profile'),
                ],
              ),
            ],
          ),
        ];

        final clause = buildIncludeClauses(specs, testRelationships, db: db);

        // Verify all three levels are present
        expect(clause, contains('FETCH posts'));
        expect(clause, contains('FETCH comments'));
        expect(clause, contains('FETCH profile'));

        // Verify independent filtering at each level
        expect(clause, contains("status = 'published'"));
        expect(clause, contains('approved = true'));

        // Verify multiple nesting levels
        final openBraces = '{'.allMatches(clause).length;
        final closeBraces = '}'.allMatches(clause).length;
        expect(openBraces, equals(2)); // Two levels of nesting
        expect(closeBraces, equals(2));
      } finally {
        await db.close();
      }
    });

    // Test 8: Multiple top-level includes with mixed filtering
    test('Test 8: Generate multiple includes with different filter types', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final specs = [
          IncludeSpec(
            'posts',
            where: EqualsCondition('status', 'published'),
            limit: 10,
          ),
          IncludeSpec('profile'), // No filtering
          IncludeSpec(
            'tags',
            orderBy: 'name',
          ),
        ];

        final clause = buildIncludeClauses(specs, testRelationships, db: db);

        // Verify all three includes are present
        expect(clause, contains('FETCH posts'));
        expect(clause, contains('FETCH profile'));
        expect(clause, contains('FETCH tags'));

        // Verify filtering only on appropriate includes
        expect(clause, contains("status = 'published'"));
        expect(clause, contains('ORDER BY name'));

        // Verify comma separation
        expect(','.allMatches(clause).length, equals(2));
      } finally {
        await db.close();
      }
    });
  });
}
