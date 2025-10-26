# RocksDB Backend Limitations

## Path Reuse After Close

### Issue

When using the RocksDB storage backend, a database path **cannot be reliably reused immediately after closing** the database connection. Attempting to reconnect to the same path will result in a file lock error:

```
IO error: lock hold by current process... LOCK: No locks available
```

### Root Cause

This limitation stems from SurrealDB's RocksDB backend architecture:

1. **Background Flush Thread**: When a RocksDB database is created, SurrealDB spawns a background thread that periodically flushes the Write-Ahead Log (WAL) to disk
2. **Persistent Reference**: This background thread holds an `Arc` reference to the database, keeping it alive
3. **Infinite Loop**: The thread runs in an infinite loop for the lifetime of the process
4. **Lock Not Released**: Because the database is never fully dropped (due to the background thread), the file lock is not released until process termination

### Workarounds

#### 1. Use Unique Paths (Recommended)

For applications that need multiple database instances in the same process:

```dart
// Create separate databases with unique paths
final db1 = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/data/db1',
  namespace: 'app',
  database: 'main',
);

await db1.close();

// Use a different path for the next instance
final db2 = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/data/db2',  // Different path
  namespace: 'app',
  database: 'main',
);
```

#### 2. Reuse After Process Restart

For applications that persist data across sessions:

```dart
// Session 1
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/data/myapp',
  namespace: 'app',
  database: 'main',
);

// ... use database ...

await db.close();
// Application exits

// Session 2 (new process)
final db = await Database.connect(
  backend: StorageBackend.rocksdb,
  path: '/data/myapp',  // Same path works after process restart
  namespace: 'app',
  database: 'main',
);
```

#### 3. Use In-Memory for Testing

For tests that need to create and destroy databases frequently:

```dart
// In-memory databases can be created/destroyed quickly
final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
);

await db.close();

// Can immediately create another in-memory instance
final db2 = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'test',
  database: 'test',
);
```

### Upstream Issue

This is a known limitation in SurrealDB's embedded database architecture. Related issues:

- [SurrealDB Issue #2399: Graceful shutdown support](https://github.com/surrealdb/surrealdb/issues/2399)
- [SurrealDB Node.js Issue #32: Disconnect method](https://github.com/surrealdb/surrealdb.node/issues/32)

### Mitigation Implemented

While we cannot fix the underlying SurrealDB limitation, we have implemented the following mitigations:

1. **Async Cleanup Delays**: Added delays in `db_close()` to give background tasks time to complete
2. **Graceful Shutdown**: Improved cleanup sequence to flush pending operations
3. **Documentation**: Clear guidance on path usage patterns
4. **Example Code**: Updated examples to demonstrate best practices

### Best Practices

For production applications:

- **Single Database Instance**: Design your application to use one RocksDB instance per process
- **Long-Lived Connections**: Keep database connections open for the application lifetime
- **Unique Paths**: If you need multiple instances, use distinct paths for each
- **Process Isolation**: Run separate processes if you need true database isolation

For testing:

- **In-Memory for Unit Tests**: Use `StorageBackend.memory` for fast, isolated tests
- **RocksDB for Integration Tests**: Use unique paths or run tests sequentially
- **Cleanup Between Runs**: Ensure test processes fully terminate before reruns

### Future Improvements

This limitation could be addressed in future versions of SurrealDB by:

1. Adding a proper `shutdown()` method to the Rust SDK
2. Using a cancellable background task instead of an infinite loop
3. Implementing reference counting with explicit cleanup
4. Providing a synchronous flush and close API

If you encounter issues with this limitation, please refer to the SurrealDB issue tracker or consider contributing a fix to the upstream project.
