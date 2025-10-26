/// Test models for build_runner code generation testing.
///
/// These classes are used to validate that the generator produces correct
/// TableDefinition code for basic types.
library;

import 'package:surrealdartb/src/schema/annotations.dart';
import 'package:surrealdartb/src/schema/surreal_types.dart';
import 'package:surrealdartb/src/schema/table_structure.dart';

part 'test_models.surreal_table.g.part';

/// Test class with basic primitive types.
///
/// Used to validate that the generator correctly handles:
/// - String → StringType()
/// - int → NumberType(format: NumberFormat.integer)
/// - double → NumberType(format: NumberFormat.floating)
/// - bool → BoolType()
/// - DateTime → DatetimeType()
/// - Duration → DurationType()
@SurrealTable('test_users')
class TestUser {
  @SurrealField(type: StringType())
  final String id;

  @SurrealField(type: StringType())
  final String name;

  @SurrealField(type: NumberType(format: NumberFormat.integer))
  final int age;

  @SurrealField(type: NumberType(format: NumberFormat.floating))
  final double score;

  @SurrealField(type: BoolType())
  final bool isActive;

  @SurrealField(type: DatetimeType())
  final DateTime createdAt;

  @SurrealField(type: DurationType())
  final Duration sessionDuration;

  const TestUser({
    required this.id,
    required this.name,
    required this.age,
    required this.score,
    required this.isActive,
    required this.createdAt,
    required this.sessionDuration,
  });
}

/// Test class with optional fields and default values.
///
/// Used to validate that the generator correctly handles:
/// - Nullable types (optional: true)
/// - Default values
@SurrealTable('test_products')
class TestProduct {
  @SurrealField(type: StringType())
  final String id;

  @SurrealField(type: StringType())
  final String name;

  @SurrealField(type: NumberType(format: NumberFormat.decimal))
  final double price;

  @SurrealField(type: StringType(), defaultValue: 'available')
  final String status;

  @SurrealField(type: NumberType(format: NumberFormat.integer), defaultValue: 0)
  final int quantity;

  @SurrealField(type: StringType())
  final String? description;

  @SurrealField(type: BoolType())
  final bool? featured;

  const TestProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.status,
    required this.quantity,
    this.description,
    this.featured,
  });
}
