/// Unit tests for ORM exception types (Task Group 3)
///
/// These tests verify the ORM exception hierarchy and ensure proper
/// construction, message formatting, and type relationships.
///
/// Test coverage:
/// - Exception construction with various parameters
/// - Exception message formatting
/// - Exception type hierarchy
/// - Field accessor validation
///
/// Total tests in this file: 8 focused tests
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';

void main() {
  group('Task Group 3: ORM Exception Types', () {
    // Test 1: OrmException base class construction
    test('Test 1: OrmException constructs with message', () {
      // Arrange & Act
      final exception = OrmException('Test ORM error');

      // Assert
      expect(exception, isA<DatabaseException>());
      expect(exception.message, equals('Test ORM error'));
      expect(exception.toString(), contains('OrmException: Test ORM error'));
    });

    // Test 2: OrmValidationException with all fields
    test('Test 2: OrmValidationException constructs with all fields', () {
      // Arrange
      const field = 'email';
      const constraint = 'required';
      const value = 'invalid@';
      final cause = ValidationException('Email is required');

      // Act
      final exception = OrmValidationException(
        'Validation failed for User',
        field: field,
        constraint: constraint,
        value: value,
        cause: cause,
      );

      // Assert
      expect(exception, isA<OrmException>());
      expect(exception, isA<DatabaseException>());
      expect(exception.message, equals('Validation failed for User'));
      expect(exception.field, equals(field));
      expect(exception.constraint, equals(constraint));
      expect(exception.value, equals(value));
      expect(exception.cause, equals(cause));

      // Verify toString includes field details
      final str = exception.toString();
      expect(str, contains('OrmValidationException'));
      expect(str, contains('field: email'));
      expect(str, contains('constraint: required'));
      expect(str, contains('value: invalid@'));
    });

    // Test 3: OrmSerializationException with type and field
    test('Test 3: OrmSerializationException constructs with type and field',
        () {
      // Arrange
      const type = 'User';
      const field = 'createdAt';
      final cause = FormatException('Invalid date format');

      // Act
      final exception = OrmSerializationException(
        'Failed to serialize User.createdAt',
        type: type,
        field: field,
        cause: cause,
      );

      // Assert
      expect(exception, isA<OrmException>());
      expect(exception.message,
          equals('Failed to serialize User.createdAt'));
      expect(exception.type, equals(type));
      expect(exception.field, equals(field));
      expect(exception.cause, equals(cause));

      // Verify toString includes type and field
      final str = exception.toString();
      expect(str, contains('OrmSerializationException'));
      expect(str, contains('type: User'));
      expect(str, contains('field: createdAt'));
    });

    // Test 4: OrmRelationshipException with relationship details
    test('Test 4: OrmRelationshipException constructs with relationship details',
        () {
      // Arrange
      const relationName = 'posts';
      const sourceType = 'User';
      const targetType = 'Post';
      final cause = Exception('Target table not found');

      // Act
      final exception = OrmRelationshipException(
        'Failed to load posts relationship',
        relationName: relationName,
        sourceType: sourceType,
        targetType: targetType,
        cause: cause,
      );

      // Assert
      expect(exception, isA<OrmException>());
      expect(exception.message, equals('Failed to load posts relationship'));
      expect(exception.relationName, equals(relationName));
      expect(exception.sourceType, equals(sourceType));
      expect(exception.targetType, equals(targetType));
      expect(exception.cause, equals(cause));

      // Verify toString includes relationship details
      final str = exception.toString();
      expect(str, contains('OrmRelationshipException'));
      expect(str, contains('relation: posts'));
      expect(str, contains('source: User'));
      expect(str, contains('target: Post'));
    });

    // Test 5: OrmQueryException with query type and constraint
    test('Test 5: OrmQueryException constructs with query type and constraint',
        () {
      // Arrange
      const queryType = 'select';
      const constraint = 'Invalid where clause';
      final cause = Exception('Field does not exist');

      // Act
      final exception = OrmQueryException(
        'Query building failed',
        queryType: queryType,
        constraint: constraint,
        cause: cause,
      );

      // Assert
      expect(exception, isA<OrmException>());
      expect(exception.message, equals('Query building failed'));
      expect(exception.queryType, equals(queryType));
      expect(exception.constraint, equals(constraint));
      expect(exception.cause, equals(cause));

      // Verify toString includes query details
      final str = exception.toString();
      expect(str, contains('OrmQueryException'));
      expect(str, contains('queryType: select'));
      expect(str, contains('constraint: Invalid where clause'));
    });

    // Test 6: Exception type hierarchy verification
    test('Test 6: All ORM exceptions extend correct base classes', () {
      // Arrange & Act
      final ormEx = OrmException('test');
      final validationEx = OrmValidationException('test');
      final serializationEx = OrmSerializationException('test');
      final relationshipEx = OrmRelationshipException('test');
      final queryEx = OrmQueryException('test');

      // Assert - All should be instances of both OrmException and DatabaseException
      expect(ormEx, isA<DatabaseException>());

      expect(validationEx, isA<OrmException>());
      expect(validationEx, isA<DatabaseException>());

      expect(serializationEx, isA<OrmException>());
      expect(serializationEx, isA<DatabaseException>());

      expect(relationshipEx, isA<OrmException>());
      expect(relationshipEx, isA<DatabaseException>());

      expect(queryEx, isA<OrmException>());
      expect(queryEx, isA<DatabaseException>());
    });

    // Test 7: Exception message formatting without optional fields
    test('Test 7: Exceptions format correctly without optional fields', () {
      // Arrange & Act
      final validationEx = OrmValidationException('Validation failed');
      final serializationEx = OrmSerializationException('Serialization failed');
      final relationshipEx = OrmRelationshipException('Relationship failed');
      final queryEx = OrmQueryException('Query failed');

      // Assert - toString should work without optional fields
      expect(validationEx.toString(),
          contains('OrmValidationException: Validation failed'));
      expect(serializationEx.toString(),
          contains('OrmSerializationException: Serialization failed'));
      expect(relationshipEx.toString(),
          contains('OrmRelationshipException: Relationship failed'));
      expect(queryEx.toString(),
          contains('OrmQueryException: Query failed'));
    });

    // Test 8: Exception message clarity and actionability
    test('Test 8: Exception messages are descriptive and actionable', () {
      // Arrange & Act
      final validationEx = OrmValidationException(
        'Field "age" failed validation: value must be greater than 0',
        field: 'age',
        constraint: 'greaterThan(0)',
        value: -5,
      );

      final serializationEx = OrmSerializationException(
        'Cannot convert DateTime field "createdAt" - invalid format provided',
        type: 'User',
        field: 'createdAt',
      );

      final relationshipEx = OrmRelationshipException(
        'Relationship "posts" from User to Post is misconfigured: target table does not exist',
        relationName: 'posts',
        sourceType: 'User',
        targetType: 'Post',
      );

      final queryEx = OrmQueryException(
        'Invalid query pattern: cannot use LIMIT without FROM clause',
        queryType: 'select',
        constraint: 'LIMIT requires FROM',
      );

      // Assert - Messages should be clear and explain the problem
      expect(validationEx.message, contains('failed validation'));
      expect(validationEx.message, contains('must be greater than 0'));

      expect(serializationEx.message, contains('Cannot convert'));
      expect(serializationEx.message, contains('invalid format'));

      expect(relationshipEx.message, contains('misconfigured'));
      expect(relationshipEx.message, contains('does not exist'));

      expect(queryEx.message, contains('Invalid query pattern'));
      expect(queryEx.message, contains('cannot use LIMIT'));
    });
  });
}
