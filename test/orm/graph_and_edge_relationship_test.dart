/// Unit tests for graph relation and edge table relationships (Task Group 13).
///
/// These tests verify:
/// - Outgoing graph relation traversal syntax
/// - Incoming graph relation traversal syntax
/// - Bidirectional graph relation traversal syntax
/// - Graph traversal with WHERE filtering
/// - Edge table RELATE statement generation
/// - Edge table metadata handling
/// - Edge creation with content
///
/// Total tests: 8 focused tests covering graph and edge relationship behaviors
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 13: Graph Relation & Edge Table Relationships', () {
    late Map<String, RelationshipMetadata> testRelationships;

    setUp(() {
      // Set up test relationship metadata
      testRelationships = {
        'likedPosts': const GraphRelationMetadata(
          fieldName: 'likedPosts',
          targetType: 'Post',
          isList: true,
          isOptional: false,
          relationName: 'likes',
          direction: RelationDirection.out,
          targetTable: 'posts',
        ),
        'authors': const GraphRelationMetadata(
          fieldName: 'authors',
          targetType: 'User',
          isList: true,
          isOptional: true,
          relationName: 'authored',
          direction: RelationDirection.inbound,
          targetTable: 'users',
        ),
        'connections': const GraphRelationMetadata(
          fieldName: 'connections',
          targetType: 'User',
          isList: true,
          isOptional: false,
          relationName: 'follows',
          direction: RelationDirection.both,
          targetTable: null, // Wildcard
        ),
        'userPostEdge': const EdgeTableMetadata(
          fieldName: 'UserPostEdge',
          targetType: 'UserPostEdge',
          isList: false,
          isOptional: false,
          edgeTableName: 'user_posts',
          sourceField: 'user',
          targetField: 'post',
          metadataFields: ['role', 'createdAt'],
        ),
      };
    });

    // Test 1: Outgoing graph relation traversal
    test('Test 1: Generate outgoing graph traversal syntax', () {
      final metadata = testRelationships['likedPosts'] as GraphRelationMetadata;
      final traversal = generateGraphTraversal(metadata);

      // Verify outgoing syntax: ->relation->target
      expect(traversal, equals('->likes->posts'));
    });

    // Test 2: Incoming graph relation traversal
    test('Test 2: Generate incoming graph traversal syntax', () {
      final metadata = testRelationships['authors'] as GraphRelationMetadata;
      final traversal = generateGraphTraversal(metadata);

      // Verify incoming syntax: <-relation<-target
      expect(traversal, equals('<-authored<-users'));
    });

    // Test 3: Bidirectional graph relation traversal
    test('Test 3: Generate bidirectional graph traversal syntax', () {
      final metadata = testRelationships['connections'] as GraphRelationMetadata;
      final traversal = generateGraphTraversal(metadata);

      // Verify bidirectional syntax with wildcard: <->relation<->*
      expect(traversal, equals('<->follows<->*'));
    });

    // Test 4: Graph traversal with WHERE filtering
    test('Test 4: Generate graph traversal with WHERE condition', () async {
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

        // Verify wrapped traversal with WHERE clause
        expect(traversal, contains('->likes->posts'));
        expect(traversal, contains('WHERE'));
        expect(traversal, contains("status = 'published'"));
        expect(traversal, startsWith('('));
        expect(traversal, endsWith(')'));
      } finally {
        await db.close();
      }
    });

    // Test 5: Edge table RELATE statement generation (basic)
    test('Test 5: Generate basic RELATE statement for edge table', () {
      final metadata = testRelationships['userPostEdge'] as EdgeTableMetadata;
      final stmt = generateRelateStatement(
        metadata,
        sourceId: 'user:john',
        targetId: 'post:123',
      );

      // Verify RELATE syntax
      expect(stmt, equals('RELATE user:john->user_posts->post:123'));
    });

    // Test 6: Edge table RELATE statement with metadata
    test('Test 6: Generate RELATE statement with edge metadata', () {
      final metadata = testRelationships['userPostEdge'] as EdgeTableMetadata;
      final stmt = generateRelateStatement(
        metadata,
        sourceId: 'user:john',
        targetId: 'post:123',
        content: {
          'role': 'author',
          'createdAt': '2024-01-01T00:00:00Z',
        },
      );

      // Verify RELATE with SET clause
      expect(stmt, contains('RELATE user:john->user_posts->post:123'));
      expect(stmt, contains('SET'));
      expect(stmt, contains("role = 'author'"));
      expect(stmt, contains("createdAt = '2024-01-01T00:00:00Z'"));
    });

    // Test 7: Edge table metadata fields
    test('Test 7: Edge table metadata stores field information', () {
      final metadata = testRelationships['userPostEdge'] as EdgeTableMetadata;

      // Verify edge table metadata fields
      expect(metadata.edgeTableName, equals('user_posts'));
      expect(metadata.sourceField, equals('user'));
      expect(metadata.targetField, equals('post'));
      expect(metadata.metadataFields, equals(['role', 'createdAt']));
    });

    // Test 8: Edge tables cannot be used in include clauses
    test('Test 8: Edge tables throw error when used in include clauses', () async {
      final specs = [
        IncludeSpec('userPostEdge'),
      ];

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        // Verify edge tables throw error in include clauses
        expect(
          () => buildIncludeClauses(specs, testRelationships, db: db),
          throwsA(isA<ArgumentError>()),
        );
      } finally {
        await db.close();
      }
    });
  });

  group('Task Group 13: Graph Relation Advanced Features', () {
    // Test 9 (bonus): Complex graph traversal with AND/OR conditions
    test('Test 9: Graph traversal with complex WHERE conditions', () async {
      final metadata = const GraphRelationMetadata(
        fieldName: 'likedPosts',
        targetType: 'Post',
        isList: true,
        isOptional: false,
        relationName: 'likes',
        direction: RelationDirection.out,
        targetTable: 'posts',
      );

      final condition = EqualsCondition('status', 'published') |
          GreaterThanCondition('views', 1000);
      final spec = IncludeSpec('likedPosts', where: condition);

      final db = await Database.connect(
        backend: StorageBackend.memory,
        namespace: 'test',
        database: 'test',
      );

      try {
        final traversal = generateGraphTraversal(metadata, spec: spec, db: db);

        // Verify complex WHERE condition
        expect(traversal, contains('->likes->posts'));
        expect(traversal, contains('WHERE'));
        expect(traversal, contains('OR'));
      } finally {
        await db.close();
      }
    });
  });
}
