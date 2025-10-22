/// Notification types for SurrealDB live queries.
///
/// This library defines the notification structure used by live queries
/// to report database changes in real-time.
library;

/// The action type for a live query notification.
///
/// Indicates what type of change occurred on the subscribed records.
enum NotificationAction {
  /// A new record was created
  create,

  /// An existing record was updated
  update,

  /// A record was deleted
  delete,
}

/// A notification from a live query subscription.
///
/// Live queries emit notifications whenever subscribed data changes.
/// Each notification contains the query ID, the action type, and the
/// affected data.
///
/// Example:
/// ```dart
/// final stream = await db.select('person').live<Map<String, dynamic>>();
/// stream.listen((notification) {
///   print('Query: ${notification.queryId}');
///   print('Action: ${notification.action}');
///   print('Data: ${notification.data}');
/// });
/// ```
class Notification<T> {
  /// Creates a notification with the given parameters.
  ///
  /// [queryId] - The unique identifier for the live query
  /// [action] - The type of change that occurred
  /// [data] - The affected data
  Notification(this.queryId, this.action, this.data);

  /// Creates a notification from a JSON object.
  ///
  /// [json] - The JSON object containing notification data
  /// [deserializer] - A function to deserialize the data field to type T
  ///
  /// The JSON object should have the following structure:
  /// ```json
  /// {
  ///   "queryId": "uuid-string",
  ///   "action": "create" | "update" | "delete",
  ///   "data": <any>
  /// }
  /// ```
  factory Notification.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) deserializer,
  ) {
    final queryIdRaw = json['queryId'];
    if (queryIdRaw is! String) {
      throw ArgumentError('queryId must be a string');
    }

    final actionRaw = json['action'];
    if (actionRaw is! String) {
      throw ArgumentError('action must be a string');
    }

    final action = switch (actionRaw.toLowerCase()) {
      'create' => NotificationAction.create,
      'update' => NotificationAction.update,
      'delete' => NotificationAction.delete,
      _ => throw ArgumentError('Invalid notification action: $actionRaw'),
    };

    final data = deserializer(json['data']);

    return Notification(queryIdRaw, action, data);
  }

  /// The unique identifier for the live query that generated this notification.
  final String queryId;

  /// The type of change that occurred (create, update, or delete).
  final NotificationAction action;

  /// The data associated with this notification.
  ///
  /// The type of this data depends on the generic type parameter T.
  /// For example, if the live query is for `Map<String, dynamic>`,
  /// this will be a Map containing the record data.
  final T data;

  /// Serializes the notification to JSON.
  ///
  /// Note: This does not attempt to serialize the data field, as the
  /// serialization strategy depends on the generic type T.
  Map<String, dynamic> toJson() => {
        'queryId': queryId,
        'action': action.name,
        'data': data,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Notification<T> &&
          runtimeType == other.runtimeType &&
          queryId == other.queryId &&
          action == other.action &&
          data == other.data;

  @override
  int get hashCode => Object.hash(queryId, action, data);

  @override
  String toString() =>
      'Notification<$T>(queryId: $queryId, action: ${action.name}, data: $data)';
}
