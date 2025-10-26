/// Tests for relationship metadata classes.
library;

import 'package:surrealdartb/src/orm/relationship_metadata.dart';
import 'package:surrealdartb/src/schema/orm_annotations.dart';
import 'package:test/test.dart';

void main() {
  group('RecordLinkMetadata', () {
    test('stores record link relationship information correctly', () {
      // Arrange & Act
      const metadata = RecordLinkMetadata(
        fieldName: 'profile',
        targetType: 'Profile',
        isList: false,
        isOptional: true,
        tableName: null,
      );

      // Assert
      expect(metadata.fieldName, equals('profile'));
      expect(metadata.targetType, equals('Profile'));
      expect(metadata.isList, isFalse);
      expect(metadata.isOptional, isTrue);
      expect(metadata.tableName, isNull);
    });

    test('infers table name from target type when not explicitly provided', () {
      // Arrange & Act
      const metadata = RecordLinkMetadata(
        fieldName: 'posts',
        targetType: 'Post',
        isList: true,
        isOptional: false,
        tableName: null,
      );

      // Assert
      expect(metadata.effectiveTableName, equals('post'));
    });

    test('uses explicit table name when provided', () {
      // Arrange & Act
      const metadata = RecordLinkMetadata(
        fieldName: 'profile',
        targetType: 'Profile',
        isList: false,
        isOptional: true,
        tableName: 'user_profiles',
      );

      // Assert
      expect(metadata.effectiveTableName, equals('user_profiles'));
    });

    test('converts PascalCase to snake_case for table names', () {
      // Arrange & Act
      const metadata = RecordLinkMetadata(
        fieldName: 'userProfile',
        targetType: 'UserProfile',
        isList: false,
        isOptional: true,
        tableName: null,
      );

      // Assert
      expect(metadata.effectiveTableName, equals('user_profile'));
    });
  });

  group('GraphRelationMetadata', () {
    test('stores outgoing graph relation information correctly', () {
      // Arrange & Act
      const metadata = GraphRelationMetadata(
        fieldName: 'likedPosts',
        targetType: 'Post',
        isList: true,
        isOptional: false,
        relationName: 'likes',
        direction: RelationDirection.out,
        targetTable: 'posts',
      );

      // Assert
      expect(metadata.fieldName, equals('likedPosts'));
      expect(metadata.targetType, equals('Post'));
      expect(metadata.isList, isTrue);
      expect(metadata.isOptional, isFalse);
      expect(metadata.relationName, equals('likes'));
      expect(metadata.direction, equals(RelationDirection.out));
      expect(metadata.targetTable, equals('posts'));
    });

    test('stores incoming graph relation information correctly', () {
      // Arrange & Act
      const metadata = GraphRelationMetadata(
        fieldName: 'authoredPosts',
        targetType: 'Post',
        isList: true,
        isOptional: false,
        relationName: 'authored',
        direction: RelationDirection.inbound,
        targetTable: null,
      );

      // Assert
      expect(metadata.direction, equals(RelationDirection.inbound));
      expect(metadata.targetTable, isNull);
      expect(metadata.effectiveTargetTable, equals('*'));
    });

    test('uses wildcard for target table when not specified', () {
      // Arrange & Act
      const metadata = GraphRelationMetadata(
        fieldName: 'connections',
        targetType: 'User',
        isList: true,
        isOptional: false,
        relationName: 'follows',
        direction: RelationDirection.both,
        targetTable: null,
      );

      // Assert
      expect(metadata.effectiveTargetTable, equals('*'));
    });
  });

  group('EdgeTableMetadata', () {
    test('stores edge table information correctly', () {
      // Arrange & Act
      const metadata = EdgeTableMetadata(
        fieldName: 'UserPostEdge',
        targetType: 'UserPostEdge',
        isList: false,
        isOptional: false,
        edgeTableName: 'user_posts',
        sourceField: 'user',
        targetField: 'post',
        metadataFields: ['role', 'createdAt'],
      );

      // Assert
      expect(metadata.fieldName, equals('UserPostEdge'));
      expect(metadata.edgeTableName, equals('user_posts'));
      expect(metadata.sourceField, equals('user'));
      expect(metadata.targetField, equals('post'));
      expect(metadata.metadataFields, equals(['role', 'createdAt']));
    });

    test('handles edge table with no metadata fields', () {
      // Arrange & Act
      const metadata = EdgeTableMetadata(
        fieldName: 'PersonKnowsEdge',
        targetType: 'PersonKnowsEdge',
        isList: false,
        isOptional: false,
        edgeTableName: 'knows',
        sourceField: 'from',
        targetField: 'to',
        metadataFields: [],
      );

      // Assert
      expect(metadata.metadataFields, isEmpty);
    });
  });

  group('RelationshipMetadata pattern matching', () {
    test('can pattern match on different relationship types', () {
      // Arrange
      const relationships = <RelationshipMetadata>[
        RecordLinkMetadata(
          fieldName: 'profile',
          targetType: 'Profile',
          isList: false,
          isOptional: true,
        ),
        GraphRelationMetadata(
          fieldName: 'liked',
          targetType: 'Post',
          isList: true,
          isOptional: false,
          relationName: 'likes',
          direction: RelationDirection.out,
        ),
        EdgeTableMetadata(
          fieldName: 'UserPostEdge',
          targetType: 'UserPostEdge',
          isList: false,
          isOptional: false,
          edgeTableName: 'user_posts',
          sourceField: 'user',
          targetField: 'post',
          metadataFields: [],
        ),
      ];

      // Act & Assert
      for (final meta in relationships) {
        final description = switch (meta) {
          RecordLinkMetadata() => 'record link',
          GraphRelationMetadata() => 'graph relation',
          EdgeTableMetadata() => 'edge table',
        };

        expect(description, isNotEmpty);
      }
    });
  });
}
