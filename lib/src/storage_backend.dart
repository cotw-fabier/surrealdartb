/// Storage backend types for SurrealDB.
///
/// This library defines the available storage backends that can be used
/// when creating a database connection.
library;

/// Available storage backend types for SurrealDB.
///
/// This enum defines the different storage options available in the
/// initial FFI bindings implementation. Each backend has different
/// characteristics and use cases.
enum StorageBackend {
  /// In-memory storage backend.
  ///
  /// This backend stores all data in memory and does not persist
  /// data to disk. All data is lost when the database is closed.
  ///
  /// Use cases:
  /// - Testing and development
  /// - Temporary data storage
  /// - High-performance scenarios where persistence is not needed
  ///
  /// Endpoint format: "mem://"
  memory,

  /// RocksDB persistent storage backend.
  ///
  /// This backend stores data in RocksDB files on disk. Data persists
  /// across database connections and application restarts.
  ///
  /// Use cases:
  /// - Production applications
  /// - Local data persistence
  /// - Embedded database scenarios
  ///
  /// Endpoint format: "file:///path/to/database"
  ///
  /// Note: Requires a valid file path to be specified.
  rocksdb,
}

/// Extension methods for StorageBackend.
extension StorageBackendExt on StorageBackend {
  /// Converts the storage backend to a database endpoint string.
  ///
  /// For [StorageBackend.memory], returns "mem://".
  /// For [StorageBackend.rocksdb], returns the provided path formatted
  /// as a file URL.
  ///
  /// Parameters:
  /// - [path] - Required for rocksdb backend, ignored for memory backend.
  ///
  /// Throws [ArgumentError] if path is null for rocksdb backend.
  ///
  /// Example:
  /// ```dart
  /// final memEndpoint = StorageBackend.memory.toEndpoint();
  /// // Returns: "mem://"
  ///
  /// final fileEndpoint = StorageBackend.rocksdb.toEndpoint('/data/mydb');
  /// // Returns: "file:///data/mydb"
  /// ```
  String toEndpoint([String? path]) {
    switch (this) {
      case StorageBackend.memory:
        return 'mem://';
      case StorageBackend.rocksdb:
        if (path == null || path.isEmpty) {
          throw ArgumentError.value(
            path,
            'path',
            'Path is required for RocksDB backend',
          );
        }
        // Ensure path starts with /
        final normalizedPath = path.startsWith('/') ? path : '/$path';
        return 'file://$normalizedPath';
    }
  }

  /// Returns a human-readable name for the storage backend.
  ///
  /// Example:
  /// ```dart
  /// print(StorageBackend.memory.displayName); // "In-Memory"
  /// print(StorageBackend.rocksdb.displayName); // "RocksDB"
  /// ```
  String get displayName {
    switch (this) {
      case StorageBackend.memory:
        return 'In-Memory';
      case StorageBackend.rocksdb:
        return 'RocksDB';
    }
  }

  /// Returns true if this backend requires a file path.
  ///
  /// Example:
  /// ```dart
  /// if (backend.requiresPath) {
  ///   // Prompt user for path
  /// }
  /// ```
  bool get requiresPath {
    switch (this) {
      case StorageBackend.memory:
        return false;
      case StorageBackend.rocksdb:
        return true;
    }
  }

  /// Returns true if this backend persists data across restarts.
  ///
  /// Example:
  /// ```dart
  /// if (!backend.isPersistent) {
  ///   print('Warning: Data will be lost on close');
  /// }
  /// ```
  bool get isPersistent {
    switch (this) {
      case StorageBackend.memory:
        return false;
      case StorageBackend.rocksdb:
        return true;
    }
  }
}
