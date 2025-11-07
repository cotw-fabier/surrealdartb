# SurrealDartB Documentation

## Introduction

**SurrealDartB** is a high-performance Dart library that provides native FFI bindings to SurrealDB, an innovative multi-model database. This library enables you to leverage SurrealDB's powerful features directly in your Dart and Flutter applications with full type safety and async support.

Whether you're building a mobile app, web application, or server-side service, SurrealDartB offers a robust, type-safe interface to SurrealDB's advanced database capabilities.

## Key Features

- **Async Operations** - All database operations return Futures and execute asynchronously
- **Memory Safety** - Automatic memory management with no memory leaks
- **Storage Backends** - Support for in-memory (testing) and persistent (RocksDB) storage
- **Type Safety** - Full Dart null safety and strong typing
- **Error Handling** - Clear exception hierarchy for different error types
- **Schema Definition** - Define and validate database schemas in Dart
- **Code Generation** - Automatic generation of type-safe models and query builders
- **Vector Operations** - Built-in support for vector embeddings and similarity search
- **Flutter Integration** - Seamless integration with Flutter applications

## Quick Start

### Installation

Add SurrealDartB to your `pubspec.yaml`:

```yaml
dependencies:
  surrealdartb: ^0.0.4
```

Then run:

```bash
dart pub get
# or for Flutter
flutter pub get
```

### First Example

Here's a simple example to get you started:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> main() async {
  // Connect to an in-memory database
  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'my_namespace',
    database: 'my_database',
  );

  try {
    // Create a record
    final person = await db.createQL('person', {
      'name': 'Alice',
      'age': 30,
      'email': 'alice@example.com',
    });
    print('Created person: ${person['name']}');

    // Query records
    final people = await db.selectQL('person');
    print('Found ${people.length} person(s)');

    // Update a record
    final updated = await db.updateQL(person['id'], {
      'age': 31,
    });
    print('Updated age to: ${updated['age']}');

  } finally {
    // Always close the database
    await db.close();
  }
}
```

## Documentation Guide

This documentation is organized into five comprehensive sections, progressing from basic setup to advanced features:

### **[01. Getting Started & Database Initialization](01-getting-started.md)**

Learn the fundamentals of setting up and connecting to SurrealDB:

- Installation and setup
- Database initialization
- Storage backends (Memory & RocksDB)
- Flutter integration with `path_provider`
- Error handling patterns
- Database lifecycle management

**Start here if you're new to SurrealDartB**

---

### **[02. Basic QL Functions Usage](02-basic-operations.md)**

Master the core database operations:

- Introduction to QL methods
- CRUD operations (Create, Read, Update, Delete)
- Raw query execution with SurrealQL
- Parameter management
- Batch operations
- Info queries for database introspection

**Essential for everyday database operations**

---

### **[03. Table Structures & Schema Definition](03-schema-definition.md)**

Define and validate your database schema:

- Why use schemas?
- Field types (scalar, collection, special, vector)
- Optional fields and default values
- Indexed fields for performance
- Validation with ASSERT clauses
- Schema migrations (auto & manual)
- Best practices and common pitfalls

**Important for production applications**

---

### **[04. Type-Safe Data with Code Generator](04-code-generator.md)**

Generate type-safe models and query builders:

- Setting up build_runner
- Defining models with annotations (`@SurrealTable`, `@SurrealField`)
- Running the code generator
- Using generated code (serialization, validation)
- Type-safe query builders
- Working with relationships
- Troubleshooting

**Recommended for large-scale applications**

---

### **[05. Vector Operations & Similarity Search](05-vector-operations.md)**

Implement AI-powered similarity search:

- What are vector embeddings?
- Creating and manipulating vectors
- Distance calculations (Euclidean, Cosine, Manhattan)
- Storing vectors in the database
- Similarity search API
- Vector indexes (FLAT, MTREE, HNSW)
- Performance optimization
- Real-world examples (RAG, recommendations, duplicate detection)

**Essential for AI/ML applications**

---

## Getting Help

- **Issues**: Report bugs or request features on [GitHub Issues](https://github.com/yourusername/surrealdartb/issues)
- **SurrealDB Documentation**: [surrealdb.com/docs](https://surrealdb.com/docs)
- **Examples**: Check the `example/` directory in the repository

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.

## Acknowledgments

Built with [SurrealDB](https://surrealdb.com), a powerful multi-model database that combines the features of traditional databases with modern graph and document capabilities.

---

**Ready to dive in?** Start with [Getting Started & Database Initialization](01-getting-started.md) →
