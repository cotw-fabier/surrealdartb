/// Tests for where builder base classes and field condition builders.
///
/// This test file validates the base field condition builder classes that
/// will be used by generated entity-specific where builders.
library;

import 'package:test/test.dart';
import 'package:surrealdartb/surrealdartb.dart';
import 'package:surrealdartb/src/orm/where_builder.dart';

void main() {
  late Database db;

  setUp(() async {
    db = await Database.connect(
      backend: StorageBackend.memory,
      namespace: 'test',
      database: 'test',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('StringFieldCondition', () {
    test('equals() creates EqualsCondition', () {
      final field = StringFieldCondition('name');
      final condition = field.equals('Alice');

      expect(condition, isA<EqualsCondition>());
      expect(condition.toSurrealQL(db), contains('name'));
      expect(condition.toSurrealQL(db), contains('='));
    });

    test('contains() creates ContainsCondition', () {
      final field = StringFieldCondition('email');
      final condition = field.contains('@example.com');

      expect(condition, isA<ContainsCondition>());
      expect(condition.toSurrealQL(db), contains('email'));
      expect(condition.toSurrealQL(db), contains('CONTAINS'));
    });

    test('ilike() creates IlikeCondition', () {
      final field = StringFieldCondition('name');
      final condition = field.ilike('%john%');

      expect(condition, isA<IlikeCondition>());
      expect(condition.toSurrealQL(db), contains('name'));
      expect(condition.toSurrealQL(db), contains('~'));
    });

    test('startsWith() creates StartsWithCondition', () {
      final field = StringFieldCondition('email');
      final condition = field.startsWith('admin');

      expect(condition, isA<StartsWithCondition>());
      expect(condition.toSurrealQL(db), contains('email'));
    });

    test('endsWith() creates EndsWithCondition', () {
      final field = StringFieldCondition('domain');
      final condition = field.endsWith('.com');

      expect(condition, isA<EndsWithCondition>());
      expect(condition.toSurrealQL(db), contains('domain'));
    });

    test('inList() creates InListCondition', () {
      final field = StringFieldCondition('status');
      final condition = field.inList(['active', 'pending']);

      expect(condition, isA<InListCondition>());
      expect(condition.toSurrealQL(db), contains('status'));
      expect(condition.toSurrealQL(db), contains('IN'));
    });
  });

  group('NumberFieldCondition', () {
    test('equals() creates EqualsCondition', () {
      final field = NumberFieldCondition<int>('age');
      final condition = field.equals(25);

      expect(condition, isA<EqualsCondition>());
      expect(condition.toSurrealQL(db), contains('age'));
      expect(condition.toSurrealQL(db), contains('='));
    });

    test('greaterThan() creates GreaterThanCondition', () {
      final field = NumberFieldCondition<int>('age');
      final condition = field.greaterThan(18);

      expect(condition, isA<GreaterThanCondition>());
      expect(condition.toSurrealQL(db), contains('age'));
      expect(condition.toSurrealQL(db), contains('>'));
    });

    test('lessThan() creates LessThanCondition', () {
      final field = NumberFieldCondition<int>('age');
      final condition = field.lessThan(65);

      expect(condition, isA<LessThanCondition>());
      expect(condition.toSurrealQL(db), contains('age'));
      expect(condition.toSurrealQL(db), contains('<'));
    });

    test('greaterOrEqual() creates GreaterOrEqualCondition', () {
      final field = NumberFieldCondition<int>('score');
      final condition = field.greaterOrEqual(100);

      expect(condition, isA<GreaterOrEqualCondition>());
      expect(condition.toSurrealQL(db), contains('score'));
      expect(condition.toSurrealQL(db), contains('>='));
    });

    test('lessOrEqual() creates LessOrEqualCondition', () {
      final field = NumberFieldCondition<int>('score');
      final condition = field.lessOrEqual(1000);

      expect(condition, isA<LessOrEqualCondition>());
      expect(condition.toSurrealQL(db), contains('score'));
      expect(condition.toSurrealQL(db), contains('<='));
    });

    test('between() creates BetweenCondition', () {
      final field = NumberFieldCondition<int>('age');
      final condition = field.between(18, 65);

      expect(condition, isA<BetweenCondition>());
      expect(condition.toSurrealQL(db), contains('age'));
      expect(condition.toSurrealQL(db), contains('>='));
      expect(condition.toSurrealQL(db), contains('AND'));
      expect(condition.toSurrealQL(db), contains('<='));
    });

    test('inList() creates InListCondition', () {
      final field = NumberFieldCondition<int>('category');
      final condition = field.inList([1, 2, 3]);

      expect(condition, isA<InListCondition>());
      expect(condition.toSurrealQL(db), contains('category'));
      expect(condition.toSurrealQL(db), contains('IN'));
    });
  });

  group('BoolFieldCondition', () {
    test('equals() creates EqualsCondition', () {
      final field = BoolFieldCondition('verified');
      final condition = field.equals(true);

      expect(condition, isA<EqualsCondition>());
      expect(condition.toSurrealQL(db), contains('verified'));
      expect(condition.toSurrealQL(db), contains('='));
    });

    test('isTrue() creates EqualsCondition with true', () {
      final field = BoolFieldCondition('active');
      final condition = field.isTrue();

      expect(condition, isA<EqualsCondition>());
      final sql = condition.toSurrealQL(db);
      expect(sql, contains('active'));
      expect(sql, contains('='));
    });

    test('isFalse() creates EqualsCondition with false', () {
      final field = BoolFieldCondition('deleted');
      final condition = field.isFalse();

      expect(condition, isA<EqualsCondition>());
      final sql = condition.toSurrealQL(db);
      expect(sql, contains('deleted'));
      expect(sql, contains('='));
    });
  });

  group('DateTimeFieldCondition', () {
    test('equals() creates EqualsCondition', () {
      final field = DateTimeFieldCondition('createdAt');
      final now = DateTime.now();
      final condition = field.equals(now);

      expect(condition, isA<EqualsCondition>());
      expect(condition.toSurrealQL(db), contains('createdAt'));
      expect(condition.toSurrealQL(db), contains('='));
    });

    test('before() creates LessThanCondition', () {
      final field = DateTimeFieldCondition('createdAt');
      final date = DateTime(2024, 1, 1);
      final condition = field.before(date);

      expect(condition, isA<LessThanCondition>());
      expect(condition.toSurrealQL(db), contains('createdAt'));
      expect(condition.toSurrealQL(db), contains('<'));
    });

    test('after() creates GreaterThanCondition', () {
      final field = DateTimeFieldCondition('createdAt');
      final date = DateTime(2024, 1, 1);
      final condition = field.after(date);

      expect(condition, isA<GreaterThanCondition>());
      expect(condition.toSurrealQL(db), contains('createdAt'));
      expect(condition.toSurrealQL(db), contains('>'));
    });

    test('between() creates BetweenCondition', () {
      final field = DateTimeFieldCondition('createdAt');
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      final condition = field.between(start, end);

      expect(condition, isA<BetweenCondition>());
      expect(condition.toSurrealQL(db), contains('createdAt'));
      expect(condition.toSurrealQL(db), contains('>='));
      expect(condition.toSurrealQL(db), contains('AND'));
      expect(condition.toSurrealQL(db), contains('<='));
    });
  });

  group('Field Condition Combinations', () {
    test('can combine string conditions with AND operator', () {
      final name = StringFieldCondition('name');
      final email = StringFieldCondition('email');

      final condition = name.equals('Alice') & email.contains('@example.com');

      expect(condition, isA<AndCondition>());
      final sql = condition.toSurrealQL(db);
      expect(sql, contains('AND'));
      expect(sql, contains('name'));
      expect(sql, contains('email'));
    });

    test('can combine number conditions with OR operator', () {
      final age = NumberFieldCondition<int>('age');

      final condition = age.lessThan(18) | age.greaterThan(65);

      expect(condition, isA<OrCondition>());
      final sql = condition.toSurrealQL(db);
      expect(sql, contains('OR'));
      expect(sql, contains('age'));
      expect(sql, contains('<'));
      expect(sql, contains('>'));
    });

    test('can create complex nested conditions', () {
      final age = NumberFieldCondition<int>('age');
      final verified = BoolFieldCondition('verified');
      final status = StringFieldCondition('status');

      final condition = (age.between(18, 65) | verified.isTrue()) &
          status.equals('active');

      expect(condition, isA<AndCondition>());
      final sql = condition.toSurrealQL(db);
      expect(sql, contains('AND'));
      expect(sql, contains('OR'));
      expect(sql, contains('age'));
      expect(sql, contains('verified'));
      expect(sql, contains('status'));
    });
  });

  group('Nested Object Property Access', () {
    test('supports nested field paths', () {
      final latField = NumberFieldCondition<double>('location.lat');
      final lonField = NumberFieldCondition<double>('location.lon');

      final latCondition = latField.between(40.0, 41.0);
      final lonCondition = lonField.between(-74.0, -73.0);
      final combined = latCondition & lonCondition;

      final sql = combined.toSurrealQL(db);
      expect(sql, contains('location.lat'));
      expect(sql, contains('location.lon'));
      expect(sql, contains('AND'));
    });

    test('supports multiple levels of nesting', () {
      final field = StringFieldCondition('metadata.user.preferences.theme');
      final condition = field.equals('dark');

      expect(condition.toSurrealQL(db), contains('metadata.user.preferences.theme'));
    });
  });

  group('Condition Reduce Pattern', () {
    test('can combine multiple conditions with reduce and AND', () {
      final conditions = [
        StringFieldCondition('status').equals('active'),
        BoolFieldCondition('verified').isTrue(),
        NumberFieldCondition<int>('age').greaterThan(18),
      ];

      final combined = conditions.reduce((a, b) => a & b);

      expect(combined, isA<AndCondition>());
      final sql = combined.toSurrealQL(db);
      expect(sql, contains('status'));
      expect(sql, contains('verified'));
      expect(sql, contains('age'));
      expect('AND'.allMatches(sql).length, equals(2));
    });

    test('can combine multiple conditions with reduce and OR', () {
      final roles = ['admin', 'moderator', 'owner'];
      final conditions = roles
          .map((role) => StringFieldCondition('role').equals(role))
          .toList();

      final combined = conditions.reduce((a, b) => a | b);

      expect(combined, isA<OrCondition>());
      final sql = combined.toSurrealQL(db);
      expect(sql, contains('role'));
      expect('OR'.allMatches(sql).length, equals(2));
    });
  });
}
