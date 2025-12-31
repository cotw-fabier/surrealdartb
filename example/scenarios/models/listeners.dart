/// Example Listeners model for testing model generation.
///
/// This model matches the pattern from a dependent project to verify
/// that the generator works correctly.
library;

import 'package:surrealdartb/surrealdartb.dart';

part 'listeners.surreal.dart';

@SurrealTable('listeners')
class Listeners {
  @SurrealId()
  String? id;

  @SurrealField(type: StringType())
  final String name;

  @SurrealField(type: StringType(), indexed: true)
  final String threadId;

  @SurrealField(type: StringType())
  final String type;

  Listeners({
    this.id,
    required this.name,
    required this.threadId,
    required this.type,
  });

  @override
  String toString() => 'Listeners(id: $id, name: $name, threadId: $threadId, type: $type)';
}
