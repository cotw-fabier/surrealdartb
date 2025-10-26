/// Unit tests for filtered include SurrealQL generation (Task Group 15).
///
/// These tests verify:
/// - FETCH clause generation for record links
/// - FETCH with WHERE clause generation
/// - FETCH with LIMIT and ORDER BY
/// - Graph traversal syntax with filtering
/// - Nested include clause generation
/// - buildIncludeClauses for complex include structures
///
/// Total tests: 8 focused tests covering critical filtered include generation
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 15: Filtered Include SurrealQL Generation', () {
    // Test 1: Basic FETCH clause generation
    test('Test 1: generateFetchClause creates basic FETCH clause', () {
      final metadata = RecordLinkMetadata(
        fieldName: 'posts',
        targetType: 'Post',
        isList: true,
        isOptional: true,
      );

      final clause = generateFetchClause(metadata);

      // Verify basic FETCH syntax
      expect(clause, equals('FETCH posts'));
    });

    // Test 2: FETCH clause with WHERE clause
    test('Test 2: generateFetchClause with WHERE clause', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final metadata = RecordLinkMetadata(
          fieldName: 'posts',
          targetType: 'Post',
          isList: true,
          isOptional: true,
        );

        final whereCondition = EqualsCondition('status', 'published');
        final spec = IncludeSpec('posts', where: whereCondition);

        final clause = generateFetchClause(metadata, spec: spec, db: db);

        // Verify FETCH with WHERE clause
        expect(clause, contains('FETCH posts'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('status'));
        expect(clause, contains('published'));
      } finally {
        await db.close();
      }
    });

    // Test 3: FETCH clause with LIMIT and ORDER BY
    test('Test 3: generateFetchClause with LIMIT and ORDER BY', () {
      final metadata = RecordLinkMetadata(
        fieldName: 'posts',
        targetType: 'Post',
        isList: true,
        isOptional: true,
      );

      final spec = IncludeSpec(
        'posts',
        limit: 10,
        orderBy: 'createdAt',
        descending: true,
      );

      final clause = generateFetchClause(metadata, spec: spec);

      // Verify FETCH with ORDER BY and LIMIT
      expect(clause, equals('FETCH posts ORDER BY createdAt DESC LIMIT 10'));
    });

    // Test 4: FETCH clause with all filtering options
    test('Test 4: generateFetchClause with WHERE, LIMIT, and ORDER BY',
        () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final metadata = RecordLinkMetadata(
          fieldName: 'posts',
          targetType: 'Post',
          isList: true,
          isOptional: true,
        );

        final whereCondition = EqualsCondition('status', 'published');
        final spec = IncludeSpec(
          'posts',
          where: whereCondition,
          limit: 5,
          orderBy: 'createdAt',
          descending: true,
        );

        final clause = generateFetchClause(metadata, spec: spec, db: db);

        // Verify complete FETCH clause
        expect(clause, contains('FETCH posts'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('status'));
        expect(clause, contains('ORDER BY createdAt DESC'));
        expect(clause, contains('LIMIT 5'));
      } finally {
        await db.close();
      }
    });

    // Test 5: Graph traversal generation
    test('Test 5: generateGraphTraversal creates correct syntax', () {
      // Test outgoing relation
      final outgoingMetadata = GraphRelationMetadata(
        fieldName: 'likedPosts',
        targetType: 'Post',
        isList: true,
        isOptional: false,
        relationName: 'likes',
        direction: RelationDirection.out,
        targetTable: 'posts',
      );

      final outgoingTraversal = generateGraphTraversal(outgoingMetadata);
      expect(outgoingTraversal, equals('->likes->posts'));

      // Test incoming relation
      final incomingMetadata = GraphRelationMetadata(
        fieldName: 'authors',
        targetType: 'User',
        isList: true,
        isOptional: false,
        relationName: 'authored',
        direction: RelationDirection.inbound,
        targetTable: 'users',
      );

      final incomingTraversal = generateGraphTraversal(incomingMetadata);
      expect(incomingTraversal, equals('<-authored<-users'));

      // Test bidirectional relation
      final bothMetadata = GraphRelationMetadata(
        fieldName: 'connections',
        targetType: 'User',
        isList: true,
        isOptional: false,
        relationName: 'follows',
        direction: RelationDirection.both,
        targetTable: 'users',
      );

      final bothTraversal = generateGraphTraversal(bothMetadata);
      expect(bothTraversal, equals('<->follows<->users'));
    });

    // Test 6: Graph traversal with WHERE clause
    test('Test 6: generateGraphTraversal with WHERE clause', () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final metadata = GraphRelationMetadata(
          fieldName: 'likedPosts',
          targetType: 'Post',
          isList: true,
          isOptional: false,
          relationName: 'likes',
          direction: RelationDirection.out,
          targetTable: 'posts',
        );

        final whereCondition = EqualsCondition('status', 'published');
        final spec = IncludeSpec('likedPosts', where: whereCondition);

        final traversal = generateGraphTraversal(metadata, spec: spec, db: db);

        // Verify graph traversal with WHERE wrapped in parentheses
        expect(traversal, contains('('));
        expect(traversal, contains('->likes->posts'));
        expect(traversal, contains('WHERE'));
        expect(traversal, contains('status'));
        expect(traversal, contains(')'));
      } finally {
        await db.close();
      }
    });

    // Test 7: buildIncludeClauses with multiple includes
    test('Test 7: buildIncludeClauses combines multiple include specs', () {
      final relationships = {
        'posts': RecordLinkMetadata(
          fieldName: 'posts',
          targetType: 'Post',
          isList: true,
          isOptional: true,
        ),
        'profile': RecordLinkMetadata(
          fieldName: 'profile',
          targetType: 'Profile',
          isList: false,
          isOptional: true,
        ),
      };

      final specs = [
        IncludeSpec('posts', limit: 10),
        IncludeSpec('profile'),
      ];

      final clause = buildIncludeClauses(specs, relationships);

      // Verify multiple FETCH clauses are combined
      expect(clause, contains('FETCH posts LIMIT 10'));
      expect(clause, contains('FETCH profile'));
      expect(clause, contains(','));
    });

    // Test 8: buildIncludeClauses with nested includes
    test('Test 8: buildIncludeClauses generates nested include syntax',
        () async {
      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final relationships = {
          'posts': RecordLinkMetadata(
            fieldName: 'posts',
            targetType: 'Post',
            isList: true,
            isOptional: true,
          ),
          'comments': RecordLinkMetadata(
            fieldName: 'comments',
            targetType: 'Comment',
            isList: true,
            isOptional: true,
          ),
          'tags': RecordLinkMetadata(
            fieldName: 'tags',
            targetType: 'Tag',
            isList: true,
            isOptional: true,
          ),
        };

        final specs = [
          IncludeSpec(
            'posts',
            where: EqualsCondition('status', 'published'),
            limit: 5,
            include: [
              IncludeSpec('comments', limit: 10),
              IncludeSpec('tags'),
            ],
          ),
        ];

        final clause = buildIncludeClauses(specs, relationships, db: db);

        // Verify nested include structure
        expect(clause, contains('FETCH posts'));
        expect(clause, contains('WHERE'));
        expect(clause, contains('LIMIT 5'));
        expect(clause, contains('{'));
        expect(clause, contains('FETCH comments LIMIT 10'));
        expect(clause, contains('FETCH tags'));
        expect(clause, contains('}'));
      } finally {
        await db.close();
      }
    });
  });
}
