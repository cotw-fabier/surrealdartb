# Vector Data Types & Storage Migration Guide

This guide helps developers adopt vector data types in the SurrealDB Dart SDK, covering migration from manual array handling to the new `VectorValue` API and schema definition capabilities.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Migrating from Manual Arrays](#migrating-from-manual-arrays)
3. [Adding Vectors to Existing Tables](#adding-vectors-to-existing-tables)
4. [Schema Definition Best Practices](#schema-definition-best-practices)
5. [Performance Optimization Tips](#performance-optimization-tips)
6. [Common Migration Scenarios](#common-migration-scenarios)
7. [Troubleshooting](#troubleshooting)

---

## Quick Start

### Before: Manual Array Handling

```dart
// Old approach - storing raw arrays
final embedding = [0.1, 0.2, 0.3, 0.4];

await db.create('documents', {
  'title': 'My Document',
  'embedding': embedding, // Just a plain List
});

// Retrieving required manual validation
final doc = await db.get<Map<String, dynamic>>('documents:abc');
final retrievedEmbedding = doc!['embedding'] as List;

// Manual dimension checking
if (retrievedEmbedding.length != 4) {
  throw Exception('Invalid embedding dimension');
}
```

### After: VectorValue API

```dart
// New approach - type-safe vector handling
final embedding = VectorValue.fromList([0.1, 0.2, 0.3, 0.4]);

await db.create('documents', {
  'title': 'My Document',
  'embedding': embedding.toJson(),
});

// Retrieving with automatic validation
final doc = await db.get<Map<String, dynamic>>('documents:abc');
final retrievedEmbedding = VectorValue.fromJson(doc!['embedding']);

// Built-in properties and operations
print('Dimensions: ${retrievedEmbedding.dimensions}'); // 4
print('Magnitude: ${retrievedEmbedding.magnitude()}'); // 0.5477...
print('Is normalized: ${retrievedEmbedding.isNormalized()}'); // false
```

**Benefits:**
- Type safety with format specification (F32, F64, I8, I16, I32, I64)
- Automatic dimension tracking
- Built-in validation helpers
- Vector math operations (dot product, normalization, distance metrics)
- Optimized serialization (hybrid JSON/binary based on dimensions)

---

## Migrating from Manual Arrays

### Step 1: Replace Array Creation

**Before:**
```dart
// Manual array creation
final embedding = List<double>.filled(768, 0.0);
for (var i = 0; i < 768; i++) {
  embedding[i] = calculateEmbedding(i);
}
```

**After:**
```dart
// Create with VectorValue
final values = List<double>.filled(768, 0.0);
for (var i = 0; i < 768; i++) {
  values[i] = calculateEmbedding(i);
}
final embedding = VectorValue.fromList(values); // Defaults to F32
```

### Step 2: Update Storage Logic

**Before:**
```dart
await db.create('embeddings', {
  'text': text,
  'vector': rawArray,
  'dimensions': rawArray.length, // Manual tracking
});
```

**After:**
```dart
await db.create('embeddings', {
  'text': text,
  'vector': embedding.toJson(), // Automatic serialization
  // No need to track dimensions - it's in VectorValue
});
```

### Step 3: Update Retrieval Logic

**Before:**
```dart
final doc = await db.get<Map<String, dynamic>>('embeddings:abc');
final vector = doc!['vector'] as List;

// Manual validation
if (vector.length != expectedDimensions) {
  throw Exception('Dimension mismatch');
}

final floatVector = vector.map((v) => v as double).toList();
```

**After:**
```dart
final doc = await db.get<Map<String, dynamic>>('embeddings:abc');
final vector = VectorValue.fromJson(doc!['vector']);

// Automatic validation
if (!vector.validateDimensions(expectedDimensions)) {
  throw ValidationException(
    'Expected $expectedDimensions dimensions, got ${vector.dimensions}',
  );
}
```

### Step 4: Migrate Math Operations

**Before:**
```dart
// Manual dot product calculation
double dotProduct(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('Dimension mismatch');
  }

  double sum = 0.0;
  for (var i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

// Manual normalization
List<double> normalize(List<double> vector) {
  double magnitude = 0.0;
  for (var v in vector) {
    magnitude += v * v;
  }
  magnitude = sqrt(magnitude);

  return vector.map((v) => v / magnitude).toList();
}
```

**After:**
```dart
// Built-in operations
final vec1 = VectorValue.fromList([3.0, 4.0, 0.0]);
final vec2 = VectorValue.fromList([1.0, 0.0, 0.0]);

final dot = vec1.dotProduct(vec2); // 3.0
final normalized = vec1.normalize(); // Unit vector
final magnitude = vec1.magnitude(); // 5.0

// Distance calculations
final euclidean = vec1.euclidean(vec2);
final manhattan = vec1.manhattan(vec2);
final cosine = vec1.cosine(vec2);
```

---

## Adding Vectors to Existing Tables

### Scenario: Adding Embeddings to Existing Documents Table

Suppose you have an existing `documents` table and want to add vector embeddings.

#### Step 1: Update Your Schema Definition (Optional)

Create a `TableStructure` to validate the new schema:

```dart
final documentsSchema = TableStructure('documents', {
  // Existing fields
  'title': FieldDefinition(StringType()),
  'content': FieldDefinition(StringType()),
  'created_at': FieldDefinition(DatetimeType()),

  // New vector field
  'embedding': FieldDefinition(
    VectorType.f32(1536, normalized: true), // OpenAI ada-002 dimensions
    optional: true, // Make it optional for backward compatibility
  ),
});
```

#### Step 2: Backfill Existing Records

```dart
// Fetch all documents without embeddings
final docs = await db.select('documents');

for (final doc in docs) {
  if (doc['embedding'] == null) {
    // Generate embedding for existing content
    final embedding = await generateEmbedding(doc['content']);
    final vectorValue = VectorValue.fromList(embedding);

    // Ensure it's normalized if required
    final normalizedVector = vectorValue.isNormalized()
        ? vectorValue
        : vectorValue.normalize();

    // Update the record
    await db.update(
      doc['id'] as String,
      {'embedding': normalizedVector.toJson()},
      schema: documentsSchema, // Optional validation
    );
  }
}
```

#### Step 3: Update Insert Logic for New Records

```dart
// New document creation with embedding
Future<Map<String, dynamic>> createDocument(
  String title,
  String content,
) async {
  // Generate embedding
  final embedding = await generateEmbedding(content);
  final vectorValue = VectorValue.fromList(embedding).normalize();

  // Create with validation
  return await db.create(
    'documents',
    {
      'title': title,
      'content': content,
      'embedding': vectorValue.toJson(),
      'created_at': DateTime.now().toIso8601String(),
    },
    schema: documentsSchema,
  );
}
```

---

## Schema Definition Best Practices

### 1. Define Schemas Early

Define your table schemas as constants for reusability:

```dart
// lib/schemas/documents_schema.dart
final documentsSchema = TableStructure('documents', {
  'title': FieldDefinition(StringType()),
  'content': FieldDefinition(StringType()),
  'embedding': FieldDefinition(
    VectorType.f32(1536, normalized: true),
  ),
  'metadata': FieldDefinition(
    ObjectType(schema: {
      'author': FieldDefinition(StringType()),
      'tags': FieldDefinition(ArrayType(StringType()), optional: true),
    }),
    optional: true,
  ),
});
```

### 2. Use Vector Type Specifications

Choose the appropriate vector format based on your use case:

```dart
// F32 - Primary choice for most embedding models (OpenAI, Mistral, etc.)
VectorType.f32(1536) // Most common, good precision/performance balance

// F64 - High precision (rarely needed for embeddings)
VectorType.f64(768) // Double precision, larger memory footprint

// Integer formats - Quantized embeddings (memory efficient)
VectorType.i8(128)  // 8-bit quantized, very memory efficient
VectorType.i16(256) // 16-bit quantized, balance of precision/memory
```

### 3. Specify Normalization Requirements

If your similarity search requires normalized vectors:

```dart
final schema = TableStructure('embeddings', {
  'vector': FieldDefinition(
    VectorType.f32(768, normalized: true), // Enforce normalization
  ),
});

// Validation will fail if vector is not normalized
try {
  await db.create(
    'embeddings',
    {'vector': nonNormalizedVector.toJson()},
    schema: schema,
  );
} catch (e) {
  if (e is ValidationException) {
    print('Vector must be normalized: ${e.message}');
    // Fix: normalize before insert
    final normalized = nonNormalizedVector.normalize();
    await db.create(
      'embeddings',
      {'vector': normalized.toJson()},
      schema: schema,
    );
  }
}
```

### 4. Use Dual Validation Strategically

**Use Dart-side validation when:**
- Working with vectors (dimension/normalization checks)
- Complex nested schemas
- You want immediate validation feedback
- Development/testing phase

```dart
// Dart-side validation
await db.create('documents', data, schema: documentsSchema);
```

**Skip validation when:**
- High-throughput batch inserts
- Production performance optimization
- Simple data that SurrealDB validates

```dart
// SurrealDB-only validation
await db.create('documents', data); // No schema parameter
```

---

## Performance Optimization Tips

### 1. Leverage Hybrid Serialization

The SDK automatically optimizes serialization based on vector dimensions:

```dart
// Small vectors (≤100 dimensions) use JSON - human-readable, easier debugging
final smallVector = VectorValue.fromList(List.filled(50, 1.0));
// Automatically uses JSON

// Large vectors (>100 dimensions) use binary - faster, more efficient
final largeVector = VectorValue.fromList(List.filled(768, 1.0));
// Automatically uses binary serialization

// Customize threshold if needed
VectorValue.serializationThreshold = 150; // Use binary for >150 dimensions
```

### 2. Batch Vector Operations

For inserting many vectors, use batch operations:

```dart
// Prepare vectors
final vectors = documents.map((doc) =>
  VectorValue.fromList(doc.embedding)
).toList();

// Set as parameters
for (var i = 0; i < vectors.length; i++) {
  await db.set('vec$i', vectors[i].toJson());
}

// Batch insert
final query = '''
  INSERT INTO embeddings [
    ${List.generate(vectors.length, (i) =>
      '{ title: \$title$i, vector: \$vec$i }'
    ).join(',\n    ')}
  ]
''';

await db.query(query);
```

### 3. Use Appropriate Vector Formats

Choose the smallest format that meets your precision needs:

```dart
// F32 (4 bytes/dimension) - Standard choice
VectorValue.f32(List.filled(768, 0.1)); // 768 * 4 = 3KB

// I16 (2 bytes/dimension) - Quantized, 50% memory savings
VectorValue.i16(List.filled(768, 100)); // 768 * 2 = 1.5KB

// I8 (1 byte/dimension) - Highly quantized, 75% memory savings
VectorValue.i8(List.filled(768, 10)); // 768 * 1 = 768 bytes
```

### 4. Pre-normalize Vectors

If normalization is required, do it once when creating vectors:

```dart
// Bad: Normalize on every insert
for (final doc in documents) {
  final vector = VectorValue.fromList(doc.embedding).normalize();
  await db.create('embeddings', {'vector': vector.toJson()});
}

// Good: Normalize once during embedding generation
for (final doc in documents) {
  final embedding = await generateEmbedding(doc.content); // Already normalized
  final vector = VectorValue.fromList(embedding);
  await db.create('embeddings', {'vector': vector.toJson()});
}
```

### 5. Skip Validation in Production Batch Inserts

For high-throughput scenarios:

```dart
// Development: Use validation
await db.create('embeddings', data, schema: embeddingsSchema);

// Production batch insert: Skip validation for speed
await db.create('embeddings', data); // No schema parameter
```

---

## Common Migration Scenarios

### Scenario 1: Semantic Search Application

**Before:**
```dart
class SearchService {
  Future<List<String>> search(String query, int limit) async {
    final queryEmbedding = await generateEmbedding(query);

    // Fetch all documents
    final docs = await db.select('documents');

    // Manual cosine similarity calculation
    final scored = docs.map((doc) {
      final docEmbedding = doc['embedding'] as List<double>;
      final similarity = cosineSimilarity(queryEmbedding, docEmbedding);
      return {'doc': doc, 'score': similarity};
    }).toList();

    scored.sort((a, b) => b['score'].compareTo(a['score']));
    return scored.take(limit).map((s) => s['doc']['title']).toList();
  }
}
```

**After:**
```dart
class SearchService {
  Future<List<String>> search(String query, int limit) async {
    final queryVector = VectorValue.fromList(
      await generateEmbedding(query)
    ).normalize();

    // Fetch all documents
    final docs = await db.select('documents');

    // Use built-in cosine similarity
    final scored = docs.map((doc) {
      final docVector = VectorValue.fromJson(doc['embedding']);
      final similarity = queryVector.cosine(docVector);
      return {'doc': doc, 'score': similarity};
    }).toList();

    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return scored.take(limit).map((s) => s['doc']['title'] as String).toList();
  }
}
```

### Scenario 2: Multi-Modal Embeddings

**Before:**
```dart
// Separate manual handling for text and image embeddings
await db.create('items', {
  'text_embedding': textEmbedding,
  'image_embedding': imageEmbedding,
  'text_dimensions': textEmbedding.length,
  'image_dimensions': imageEmbedding.length,
});
```

**After:**
```dart
// Type-safe multi-modal embeddings
final textVec = VectorValue.fromList(textEmbedding); // 384 dimensions
final imageVec = VectorValue.fromList(imageEmbedding); // 512 dimensions

await db.create('items', {
  'text_embedding': textVec.toJson(),
  'image_embedding': imageVec.toJson(),
  // Dimensions tracked automatically
});
```

### Scenario 3: Embedding Model Update

**Before:**
```dart
// Manual migration when changing embedding models
// Old model: 768 dimensions → New model: 1536 dimensions

final docs = await db.select('documents');
for (final doc in docs) {
  final oldEmbedding = doc['embedding'] as List;
  if (oldEmbedding.length == 768) {
    final newEmbedding = await generateNewEmbedding(doc['content']);
    await db.update(doc['id'], {'embedding': newEmbedding});
  }
}
```

**After:**
```dart
// Type-safe migration with automatic dimension validation
final schema1536 = TableStructure('documents', {
  'embedding': FieldDefinition(VectorType.f32(1536)),
});

final docs = await db.select('documents');
for (final doc in docs) {
  final currentVec = VectorValue.fromJson(doc['embedding']);

  if (currentVec.dimensions == 768) {
    // Regenerate with new model
    final newEmbedding = await generateNewEmbedding(doc['content']);
    final newVec = VectorValue.fromList(newEmbedding);

    try {
      await db.update(
        doc['id'] as String,
        {'embedding': newVec.toJson()},
        schema: schema1536, // Validates 1536 dimensions
      );
    } catch (e) {
      if (e is ValidationException) {
        print('Migration failed for ${doc['id']}: ${e.message}');
      }
    }
  }
}
```

---

## Troubleshooting

### Issue: Dimension Mismatch Errors

**Problem:**
```dart
// ValidationException: Vector has 768 dimensions, expected 1536
```

**Solution:**
```dart
// Check actual dimensions
final vector = VectorValue.fromJson(data['embedding']);
print('Actual dimensions: ${vector.dimensions}');

// Ensure embedding generation matches schema
final schema = TableStructure('embeddings', {
  'vector': FieldDefinition(VectorType.f32(1536)), // Match your model
});
```

### Issue: Normalization Failures

**Problem:**
```dart
// ValidationException: Vector must be normalized (magnitude 1.0)
```

**Solution:**
```dart
// Always normalize when required
final vector = VectorValue.fromList(rawEmbedding);

if (!vector.isNormalized()) {
  final normalized = vector.normalize();
  await db.create('embeddings', {'vector': normalized.toJson()});
}

// Or normalize during embedding generation
final normalized = VectorValue.fromList(rawEmbedding).normalize();
```

### Issue: Performance Degradation with Large Batches

**Problem:**
Slow batch inserts with many vectors.

**Solution:**
```dart
// 1. Use batch operations
// 2. Skip Dart-side validation
// 3. Ensure binary serialization for large vectors

const batchSize = 100;
for (var i = 0; i < vectors.length; i += batchSize) {
  final batch = vectors.skip(i).take(batchSize).toList();

  // Set parameters
  for (var j = 0; j < batch.length; j++) {
    await db.set('vec$j', batch[j].toJson());
  }

  // Batch insert (no schema validation)
  await db.query('''
    INSERT INTO embeddings [
      ${List.generate(batch.length, (j) => '{ vector: \$vec$j }').join(', ')}
    ]
  ''');
}
```

### Issue: Memory Issues with Very Large Vectors

**Problem:**
High memory usage when working with large-dimensional vectors.

**Solution:**
```dart
// 1. Use integer quantization
final quantized = VectorValue.i8(
  floatVector.map((v) => (v * 127).toInt()).toList()
);

// 2. Process in batches
// 3. Ensure binary serialization is enabled
VectorValue.serializationThreshold = 100; // Default is 100
```

### Issue: Type Conversion Errors

**Problem:**
```dart
// ArgumentError: VectorValue JSON must be a List
```

**Solution:**
```dart
// Ensure data is in correct format
final data = await db.get<Map<String, dynamic>>('embeddings:abc');

// Check type before conversion
if (data?['vector'] is List) {
  final vector = VectorValue.fromJson(data!['vector']);
} else {
  print('Invalid vector data type: ${data?['vector'].runtimeType}');
}
```

---

## Next Steps

1. **Review Your Codebase**: Identify all locations where embeddings are currently handled
2. **Update Schemas**: Define `TableStructure` schemas for tables with vectors
3. **Migrate Incrementally**: Start with new code, then backfill existing data
4. **Test Thoroughly**: Verify dimension compatibility and normalization
5. **Monitor Performance**: Compare before/after metrics for batch operations

For more information:
- [VectorValue API Documentation](../../../lib/src/types/vector_value.dart)
- [TableStructure API Documentation](../../../lib/src/schema/table_structure.dart)
- [Database API Documentation](../../../lib/src/database.dart)
- [Spec Document](../spec.md)
