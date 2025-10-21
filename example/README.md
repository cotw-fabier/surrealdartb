# SurrealDB Dart FFI Bindings - CLI Example

This directory contains an interactive command-line example demonstrating the core features of the SurrealDB Dart FFI bindings library.

## Overview

The CLI example provides an interactive menu-driven interface to explore three key scenarios:

1. **Connect and Verify** - Basic database connectivity and verification
2. **CRUD Operations** - Complete create, read, update, and delete workflow
3. **Storage Comparison** - Comparison between in-memory and persistent storage

## Requirements

- Dart SDK 3.0.0 or later
- macOS (primary development platform)
- SurrealDB Dart FFI bindings library (surrealdartb)

## Running the Example

From the project root directory, run:

```bash
dart run example/cli_example.dart
```

You'll be presented with an interactive menu where you can select which scenario to run.

## Scenarios

### 1. Connect and Verify Connectivity

**Purpose:** Demonstrates basic database connection and verification.

**What it does:**
- Connects to an in-memory database (mem://)
- Sets the namespace to "test" and database to "test"
- Executes an `INFO FOR DB` query to verify the connection
- Displays the query result
- Properly closes the database connection

**Expected output:**
```
=== Scenario 1: Connect and Verify ===

Step 1: Connecting to in-memory database...
✓ Successfully connected to database

Step 2: Verifying database context...
  Namespace: test
  Database: test

Step 3: Executing INFO FOR DB query...
✓ Query executed successfully (no schema defined yet)

=== Connect and Verify: SUCCESS ===
Database connection is working correctly!
```

**Key learning points:**
- How to create a database connection
- How to set namespace and database context
- How to execute basic queries
- Proper error handling and resource cleanup

---

### 2. CRUD Operations Demonstration

**Purpose:** Demonstrates complete lifecycle of data operations.

**What it does:**
- Connects to an in-memory database
- **Creates** a person record with name, age, email, and city
- **Reads** all person records using select
- **Updates** the person's age, email, and city
- Verifies the update with a filtered query
- **Deletes** the person record
- Verifies deletion by checking for remaining records
- Closes the database connection

**Expected output:**
```
=== Scenario 2: CRUD Operations ===

Step 1: Connecting to database...
✓ Connected successfully

Step 2: Creating a new person record...
✓ Record created:
  ID: person:xxxxxx
  Name: John Doe
  Age: 30
  Email: john.doe@example.com
  City: San Francisco

Step 3: Querying all person records...
✓ Found 1 record(s)
  - John Doe (30 years old)

Step 4: Updating person record...
✓ Record updated:
  ID: person:xxxxxx
  Name: John Doe
  Age: 31 (was 30)
  Email: john.updated@example.com (was john.doe@example.com)
  City: Los Angeles (was San Francisco)

Step 5: Verifying update with query...
✓ Query result for age > 30:
  - John Doe: 31 years old

Step 6: Deleting person record...
✓ Record deleted: person:xxxxxx

Step 7: Verifying deletion...
✓ Remaining records: 0
  All records have been deleted

=== CRUD Operations: SUCCESS ===
All operations completed successfully!
  ✓ Create
  ✓ Read (Select)
  ✓ Update
  ✓ Delete
```

**Key learning points:**
- Creating records with auto-generated IDs
- Querying all records from a table
- Using SurrealQL for filtered queries
- Updating specific records by ID
- Deleting records
- The complete data lifecycle

---

### 3. Storage Backend Comparison

**Purpose:** Demonstrates the difference between in-memory and persistent storage.

**What it does:**
- **Part 1: In-Memory Storage**
  - Connects to in-memory database (mem://)
  - Creates a product record
  - Closes the database
  - Reconnects to show data is lost

- **Part 2: RocksDB Persistent Storage**
  - Creates a temporary directory for RocksDB
  - Connects to RocksDB database with a file path
  - Creates a product record
  - Closes the database
  - Reconnects to the same path to show data persists
  - Updates the persisted record
  - Cleans up temporary files

**Expected output:**
```
=== Scenario 3: Storage Backend Comparison ===

--- Part 1: In-Memory Storage (mem://) ---

Connecting to in-memory database...
✓ Connected

Creating test record...
✓ Created: Laptop - $999.99
  Record ID: product:xxxxxx

Querying records...
✓ Found 1 product(s) in database

Closing database...
✓ Database closed

Reconnecting to verify data persistence...
✓ Reconnected

Querying records after reconnection...
✓ Found 0 product(s) in database
  ⚠ Data was lost (expected for in-memory storage)

Memory Backend Summary:
  • Fast and lightweight
  • Data stored in RAM only
  • All data lost when connection closes
  • Ideal for testing and temporary data

--- Part 2: RocksDB Persistent Storage ---

Using temporary database path: /tmp/surrealdartb_test_xxxxx/testdb

Connecting to RocksDB database...
✓ Connected

Creating test record...
✓ Created: Desktop - $1499.99
  Record ID: product:xxxxxx

Querying records...
✓ Found 1 product(s) in database

Closing database...
✓ Database closed

Reconnecting to the same database path...
✓ Reconnected

Querying records after reconnection...
✓ Found 1 product(s) in database
  ✓ Data persisted successfully!
    - Desktop: $1499.99 (15 in stock)

Updating persisted record...
✓ Updated stock from 15 to 20

RocksDB Backend Summary:
  • Data persists to disk
  • Survives database close and application restart
  • Stored in RocksDB files at specified path
  • Ideal for production and long-term storage

Cleaning up temporary files...
✓ Temporary files deleted

=== Storage Comparison: SUCCESS ===
Both storage backends are working correctly!
```

**Key learning points:**
- Difference between in-memory and persistent storage
- When to use each storage backend
- How to specify file paths for RocksDB
- Data persistence across connections
- Proper cleanup of database files

## Error Handling

All scenarios include comprehensive error handling:

- **ConnectionException** - When database connection fails
- **QueryException** - When query execution fails
- **DatabaseException** - For general database errors

If a scenario fails, you'll see a detailed error message including:
- The scenario name
- The error message
- The full stack trace
- Guidance on what went wrong

## Code Organization

```
example/
├── cli_example.dart              # Main interactive CLI entry point
├── scenarios/
│   ├── connect_verify.dart       # Scenario 1: Basic connectivity
│   ├── crud_operations.dart      # Scenario 2: CRUD operations
│   └── storage_comparison.dart   # Scenario 3: Storage backends
└── README.md                     # This file
```

## Platform Support

This example has been tested on:
- ✅ macOS (Apple Silicon and Intel)

Other platforms are configured but not yet tested:
- ⏳ iOS
- ⏳ Android
- ⏳ Windows
- ⏳ Linux

## Troubleshooting

### Build Errors

If you encounter build errors, ensure you have:
1. Rust toolchain 1.90.0 installed
2. Run `dart pub get` to trigger native compilation
3. Verified the build completed without errors

### Connection Errors

If database connection fails:
1. Check that the native library compiled successfully
2. Verify you're using a supported storage backend (memory or rocksdb)
3. For RocksDB, ensure the path is writable

### RocksDB Path Errors

If RocksDB operations fail:
1. Ensure the path is absolute
2. Verify directory permissions allow writing
3. Check available disk space

## Learning More

For more information about the SurrealDB Dart FFI bindings:

- See the main library documentation in `lib/surrealdartb.dart`
- Review the API documentation for the `Database` class
- Check the specification in `agent-os/specs/2025-10-21-initial-ffi-bindings-setup/`

## Contributing

This example is part of the initial FFI bindings setup. Future enhancements may include:
- Additional scenarios demonstrating advanced features
- Performance benchmarking
- Multi-platform testing
- More complex query examples
