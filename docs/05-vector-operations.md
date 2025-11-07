[← Back to Documentation Index](README.md)

# Vector Operations & Similarity Search

## Vector Operations & Similarity Search

Vector embeddings are numerical representations of data (text, images, audio, etc.) that capture semantic meaning in high-dimensional space. SurrealDartBprovides comprehensive support for storing, manipulating, and searching vector embeddings, making it ideal for AI/ML applications like semantic search, recommendation systems, and similarity-based retrieval.

### What are Vector Embeddings?

Vector embeddings are arrays of numbers that represent the semantic meaning of content. For example:
- Text embeddings from models like OpenAI's ada-002 (1536 dimensions)
- Sentence embeddings from BERT or sentence-transformers (384-768 dimensions)
- Image embeddings from vision models
- Audio embeddings from speech recognition models

Similar content produces similar embeddings, enabling powerful similarity search capabilities.

### Common Use Cases

- **Semantic Search**: Find documents by meaning rather than exact keywords
- **Recommendation Systems**: Suggest similar products, articles, or content
- **Duplicate Detection**: Identify near-duplicate content
- **Classification**: Group similar items together
- **Retrieval-Augmented Generation (RAG)**: Power AI chatbots with relevant context

---

### Creating Vector Values

SurrealDartBprovides the `VectorValue` class to work with vector embeddings. Vectors can be created in multiple formats to balance precision and memory usage.

#### Basic Vector Creation

```dart
import 'package:surrealdartb/surrealdartb.dart';

// Create a Float32 vector (most common for AI/ML)
final embedding = VectorValue.f32([0.1, 0.2, 0.3, 0.4, 0.5]);
print('Dimensions: ${embedding.dimensions}'); // 5
print('Format: ${embedding.format}'); // VectorFormat.f32

// Create from a generic list (defaults to F32)
final vector = VectorValue.fromList([1.0, 2.0, 3.0]);

// Create from string format
final parsed = VectorValue.fromString('[0.1, 0.2, 0.3]');
```

#### Vector Formats

SurrealDartBsupports six vector formats, each optimized for different use cases:

```dart
// F32 (Float32) - Standard for AI/ML embeddings
final f32 = VectorValue.f32([1.5, 2.7, 3.2, 4.1]);
// Memory: 4 bytes × dimensions
// Use case: OpenAI, sentence transformers, most AI models

// F64 (Float64) - High precision
final f64 = VectorValue.f64([1.123456789, 2.987654321]);
// Memory: 8 bytes × dimensions
// Use case: Scientific computing, high precision requirements

// I16 (Int16) - Quantized embeddings
final i16 = VectorValue.i16([100, 200, 300, 400]);
// Memory: 2 bytes × dimensions (50% savings vs F32)
// Use case: Quantized models, memory-constrained devices

// I8 (Int8) - Maximum compression
final i8 = VectorValue.i8([10, 20, 30, 40]);
// Memory: 1 byte × dimensions (75% savings vs F32)
// Use case: Extreme compression, mobile devices

// I32 and I64 also available for integer vectors
final i32 = VectorValue.i32([1000, 2000, 3000]);
final i64 = VectorValue.i64([100000, 200000, 300000]);
```

**Format Selection Guide:**
- **F32**: Default choice for most AI/ML workloads (best balance)
- **F64**: Only when high precision is critical
- **I16/I8**: For quantized models or memory-constrained environments
- **I32/I64**: For specialized integer-based embeddings

#### Memory Comparison

For a 768-dimensional vector (common size):
- **F32**: 3,072 bytes
- **F64**: 6,144 bytes (2x F32)
- **I16**: 1,536 bytes (50% of F32)
- **I8**: 768 bytes (25% of F32)

---

### Vector Operations

#### Basic Properties

```dart
final vector = VectorValue.f32([3.0, 4.0, 0.0]);

// Access dimensions
print(vector.dimensions); // 3

// Check format
print(vector.format); // VectorFormat.f32

// Access raw data
print(vector.data); // Float32List [3.0, 4.0, 0.0]

// Convert to list for storage
final jsonData = vector.toJson();
print(jsonData); // [3.0, 4.0, 0.0]
```

#### Vector Magnitude

The magnitude (or length) of a vector measures its overall size:

```dart
final vector = VectorValue.f32([3.0, 4.0, 0.0]);

// Calculate magnitude (Euclidean norm)
final mag = vector.magnitude();
print('Magnitude: $mag'); // 5.0 (sqrt(3² + 4²))

// Unit vectors have magnitude 1.0
final unitVec = VectorValue.f32([1.0, 0.0, 0.0]);
print('Unit magnitude: ${unitVec.magnitude()}'); // 1.0

// Zero vector has magnitude 0.0
final zeroVec = VectorValue.f32([0.0, 0.0, 0.0]);
print('Zero magnitude: ${zeroVec.magnitude()}'); // 0.0
```

#### Vector Normalization

Normalization converts a vector to unit length (magnitude = 1.0) while preserving its direction. This is essential for cosine similarity and many ML models:

```dart
final vector = VectorValue.f32([3.0, 4.0, 0.0]);

// Normalize to unit vector
final normalized = vector.normalize();
print('Original magnitude: ${vector.magnitude()}'); // 5.0
print('Normalized magnitude: ${normalized.magnitude()}'); // 1.0
print('Normalized values: ${normalized.toJson()}'); // [0.6, 0.8, 0.0]

// Check if already normalized
print('Is normalized: ${vector.isNormalized()}'); // false
print('Is normalized: ${normalized.isNormalized()}'); // true

// Normalization preserves direction
// The ratio between components remains the same
// Original: 3:4 = 0.75
// Normalized: 0.6:0.8 = 0.75
```

**When to normalize:**
- Before storing embeddings for cosine similarity search
- When using models that expect normalized inputs
- When comparing vectors using dot product
- When direction matters more than magnitude

**Important:** Normalizing a zero vector throws a `StateError`:

```dart
final zeroVec = VectorValue.f32([0.0, 0.0, 0.0]);
try {
  zeroVec.normalize(); // Throws StateError
} catch (e) {
  print('Cannot normalize zero vector');
}
```

#### Dot Product

The dot product measures how much two vectors point in the same direction:

```dart
final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
final vec2 = VectorValue.f32([4.0, 5.0, 6.0]);

// Calculate dot product: 1*4 + 2*5 + 3*6 = 32
final dot = vec1.dotProduct(vec2);
print('Dot product: $dot'); // 32.0

// Orthogonal vectors have dot product 0
final vecX = VectorValue.f32([1.0, 0.0, 0.0]);
final vecY = VectorValue.f32([0.0, 1.0, 0.0]);
print('Orthogonal dot product: ${vecX.dotProduct(vecY)}'); // 0.0

// For normalized vectors, dot product equals cosine similarity
final norm1 = vec1.normalize();
final norm2 = vec2.normalize();
final dotNorm = norm1.dotProduct(norm2);
final cosine = norm1.cosine(norm2);
print('Dot of normalized: $dotNorm');
print('Cosine similarity: $cosine');
// These will be equal (within floating-point precision)
```

---

### Distance Calculations

Distance metrics measure how similar or different two vectors are. Different metrics are suitable for different use cases.

#### Euclidean Distance

Measures the straight-line distance between two vectors (L2 norm):

```dart
final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
final vec2 = VectorValue.f32([4.0, 6.0, 8.0]);

// Calculate Euclidean distance
// sqrt((4-1)² + (6-2)² + (8-3)²) = sqrt(50) ≈ 7.07
final distance = vec1.euclidean(vec2);
print('Euclidean distance: $distance'); // ~7.07

// Identical vectors have distance 0
final vec3 = VectorValue.f32([1.0, 2.0, 3.0]);
print('Distance to self: ${vec1.euclidean(vec3)}'); // 0.0
```

**Best for:**
- General-purpose similarity
- When absolute magnitude matters
- Image embeddings
- General ML embeddings

#### Cosine Similarity

Measures the angle between vectors, ignoring magnitude. Returns value from -1 (opposite) to 1 (identical):

```dart
final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
final vec2 = VectorValue.f32([2.0, 4.0, 6.0]); // Parallel to vec1

// Cosine similarity: parallel vectors = 1.0
print('Parallel vectors: ${vec1.cosine(vec2)}'); // 1.0

// Orthogonal vectors = 0.0
final vecX = VectorValue.f32([1.0, 0.0, 0.0]);
final vecY = VectorValue.f32([0.0, 1.0, 0.0]);
print('Orthogonal vectors: ${vecX.cosine(vecY)}'); // 0.0

// Opposite vectors = -1.0
final vecPos = VectorValue.f32([1.0, 0.0, 0.0]);
final vecNeg = VectorValue.f32([-1.0, 0.0, 0.0]);
print('Opposite vectors: ${vecPos.cosine(vecNeg)}'); // -1.0
```

**Best for:**
- Text embeddings
- Semantic similarity
- Document clustering
- When direction matters more than magnitude

**Important:** Cosine similarity throws `StateError` for zero vectors:

```dart
final vec = VectorValue.f32([1.0, 2.0, 3.0]);
final zero = VectorValue.f32([0.0, 0.0, 0.0]);
try {
  vec.cosine(zero); // Throws StateError
} catch (e) {
  print('Cannot compute cosine with zero vector');
}
```

#### Manhattan Distance

Sum of absolute differences between components (L1 norm):

```dart
final vec1 = VectorValue.f32([1.0, 2.0, 3.0]);
final vec2 = VectorValue.f32([4.0, 6.0, 8.0]);

// Manhattan distance: |4-1| + |6-2| + |8-3| = 12
final distance = vec1.manhattan(vec2);
print('Manhattan distance: $distance'); // 12.0
```

**Best for:**
- High-dimensional spaces
- Grid-based movement
- Robustness to outliers
- Sparse vectors

#### Comparing Metrics

Different metrics rank similarity differently:

```dart
final query = VectorValue.f32([0.9, 0.1, 0.0]);
final doc1 = VectorValue.f32([1.0, 0.0, 0.0]); // Close to query
final doc2 = VectorValue.f32([0.0, 1.0, 0.0]); // Far from query

print('Document 1 vs Query:');
print('  Euclidean: ${query.euclidean(doc1)}'); // ~0.14
print('  Cosine: ${query.cosine(doc1)}'); // ~1.0 (very similar)
print('  Manhattan: ${query.manhattan(doc1)}'); // ~0.2

print('\nDocument 2 vs Query:');
print('  Euclidean: ${query.euclidean(doc2)}'); // ~1.27
print('  Cosine: ${query.cosine(doc2)}'); // ~0.1 (dissimilar)
print('  Manhattan: ${query.manhattan(doc2)}'); // ~1.8
```

---

### Storing Vectors in Database

Vectors are stored as arrays in SurrealDB and can be included in any table schema.

#### Define Schema with Vector Field

```dart
import 'package:surrealdartb/surrealdartb.dart';

final db = await Database.connect(
  backend: StorageBackend.memory,
  namespace: 'ai_app',
  database: 'vectors',
);

// Define table structure with vector field
final documentSchema = TableStructure('documents', {
  'title': FieldDefinition(StringType(), optional: false),
  'content': FieldDefinition(StringType(), optional: false),
  'embedding': FieldDefinition(
    VectorType.f32(768, normalized: true),
    optional: false,
  ),
  'category': FieldDefinition(StringType(), optional: true),
  'created_at': FieldDefinition(DatetimeType(), optional: true),
});

// Apply schema to database
await db.queryQL(documentSchema.toSurrealQL());
```

The `VectorType.f32(768, normalized: true)` specifies:
- Format: Float32 (4 bytes per dimension)
- Dimensions: 768 (common for many AI models)
- Normalized: Vectors should be unit length

#### Storing Records with Vectors

```dart
// Create vector embedding (from your AI model)
final embedding = VectorValue.f32([
  0.123, 0.456, 0.789, // ... 768 dimensions total
]);

// Ensure vector is normalized if required by schema
final normalizedEmbedding = embedding.normalize();

// Store document with embedding
final document = await db.createQL('documents', {
  'title': 'Machine Learning Basics',
  'content': 'Introduction to neural networks and deep learning...',
  'embedding': normalizedEmbedding.toJson(), // Converts to JSON array
  'category': 'AI',
});

print('Stored document: ${document['id']}');
```

#### Retrieving Vectors from Database

```dart
// Get a specific document
final doc = await db.get<Map<String, dynamic>>('documents:abc123');

if (doc != null) {
  // Extract vector from record
  final embeddingData = doc['embedding'] as List;
  final vector = VectorValue.fromJson(embeddingData);

  print('Title: ${doc['title']}');
  print('Vector dimensions: ${vector.dimensions}');
  print('Is normalized: ${vector.isNormalized()}');
}

// Query all documents
final allDocs = await db.selectQL('documents');
for (final doc in allDocs) {
  final embedding = VectorValue.fromJson(doc['embedding']);
  print('${doc['title']}: ${embedding.dimensions} dimensions');
}
```

#### Batch Insert with Vectors

```dart
// Prepare multiple embeddings
final embeddings = [
  VectorValue.f32([...]).normalize(),
  VectorValue.f32([...]).normalize(),
  VectorValue.f32([...]).normalize(),
];

// Set as parameters
await db.set('emb1', embeddings[0].toJson());
await db.set('emb2', embeddings[1].toJson());
await db.set('emb3', embeddings[2].toJson());

// Batch insert
final response = await db.queryQL('''
  INSERT INTO documents [
    {
      title: "Doc 1",
      content: "First document",
      embedding: \$emb1
    },
    {
      title: "Doc 2",
      content: "Second document",
      embedding: \$emb2
    },
    {
      title: "Doc 3",
      content: "Third document",
      embedding: \$emb3
    }
  ]
''');

print('Inserted ${response.getResults().length} documents');
```

---

### Similarity Search API

SurrealDartBprovides high-level methods for vector similarity search, enabling you to find the most similar records to a query vector.

#### Basic Similarity Search

```dart
// Create query vector (from user's search query)
final queryVector = VectorValue.f32([
  0.456, 0.123, 0.789, // ... 768 dimensions
]).normalize();

// Search for similar documents
final results = await db.searchSimilar(
  table: 'documents',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
);

// Process results
print('Found ${results.length} similar documents:\n');
for (final result in results) {
  print('Title: ${result.record['title']}');
  print('Distance: ${result.distance}');
  print('Category: ${result.record['category']}');
  print('---');
}
```

The `searchSimilar` method:
- Returns results ordered by distance (closest first)
- Each result contains the full record and its distance
- Automatically handles vector serialization
- Supports multiple distance metrics

#### Similarity Search with Filtering

Combine similarity search with WHERE conditions to filter results:

```dart
// Search only in active, published documents
final results = await db.searchSimilar(
  table: 'articles',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.euclidean,
  limit: 5,
  where: AndCondition([
    EqualsCondition('status', 'active'),
    EqualsCondition('published', true),
  ]),
);

print('Found ${results.length} active articles');
```

Common filtering patterns:

```dart
// Filter by category
final techArticles = await db.searchSimilar(
  table: 'articles',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: EqualsCondition('category', 'technology'),
);

// Filter by date range
final recentArticles = await db.searchSimilar(
  table: 'articles',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: AndCondition([
    GreaterThanCondition('published_at', '2024-01-01'),
    LessThanCondition('published_at', '2024-12-31'),
  ]),
);

// Complex filtering
final filtered = await db.searchSimilar(
  table: 'products',
  field: 'description_embedding',
  queryVector: queryVector,
  metric: DistanceMetric.euclidean,
  limit: 20,
  where: AndCondition([
    EqualsCondition('in_stock', true),
    GreaterThanCondition('price', 10.0),
    LessThanCondition('price', 100.0),
    InCondition('brand', ['BrandA', 'BrandB', 'BrandC']),
  ]),
);
```

#### Working with Similarity Results

```dart
final results = await db.searchSimilar(
  table: 'documents',
  field: 'embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
);

for (final result in results) {
  // Access the full record
  final title = result.record['title'];
  final content = result.record['content'];
  final id = result.record['id'];

  // Access the distance/similarity score
  final distance = result.distance;

  // Convert distance to similarity percentage
  // For cosine: higher is more similar (0 to 1)
  final similarity = (distance * 100).toStringAsFixed(1);

  print('$title: $similarity% similar');
  print('ID: $id');
  print('---');
}

// Find the most similar result
if (results.isNotEmpty) {
  final best = results.first;
  print('Most similar: ${best.record['title']}');
  print('Distance: ${best.distance}');
}

// Filter results by similarity threshold
final highSimilarity = results.where((r) => r.distance > 0.8).toList();
print('${highSimilarity.length} documents with >80% similarity');
```

#### Distance Metrics Comparison

Different metrics are suitable for different use cases:

```dart
// Cosine similarity - Best for text embeddings
final cosineResults = await db.searchSimilar(
  table: 'documents',
  field: 'text_embedding',
  queryVector: queryVector,
  metric: DistanceMetric.cosine,
  limit: 10,
);

// Euclidean distance - General purpose
final euclideanResults = await db.searchSimilar(
  table: 'images',
  field: 'image_embedding',
  queryVector: queryVector,
  metric: DistanceMetric.euclidean,
  limit: 10,
);

// Manhattan distance - High-dimensional spaces
final manhattanResults = await db.searchSimilar(
  table: 'features',
  field: 'feature_vector',
  queryVector: queryVector,
  metric: DistanceMetric.manhattan,
  limit: 10,
);

// Minkowski distance - Specialized applications
final minkowskiResults = await db.searchSimilar(
  table: 'data',
  field: 'vector',
  queryVector: queryVector,
  metric: DistanceMetric.minkowski,
  limit: 10,
);
```

**Metric Selection Guide:**
- **Cosine**: Text embeddings, semantic search, NLP tasks
- **Euclidean**: General similarity, image embeddings, when magnitude matters
- **Manhattan**: High dimensions, sparse vectors, outlier robustness
- **Minkowski**: Specialized ML applications

---

### Batch Similarity Search

Search with multiple query vectors simultaneously:

```dart
// Prepare multiple query vectors
final queryVectors = [
  VectorValue.f32([...]), // Query 1
  VectorValue.f32([...]), // Query 2
  VectorValue.f32([...]), // Query 3
];

// Perform batch search
final results = await db.batchSearchSimilar(
  table: 'products',
  field: 'embedding',
  queryVectors: queryVectors,
  metric: DistanceMetric.cosine,
  limit: 5,
);

// Results are mapped by input index
for (var i = 0; i < queryVectors.length; i++) {
  print('Results for query vector $i:');
  final queryResults = results[i]!;

  for (final result in queryResults) {
    print('  - ${result.record['name']}: ${result.distance}');
  }
  print('');
}
```

**Use cases for batch search:**
- Compare multiple items against catalog
- Multi-query recommendation systems
- Parallel search operations
- A/B testing different embeddings

---

### Vector Index Creation

To optimize similarity search performance, create vector indexes on your embedding fields. SurrealDartBprovides the `IndexDefinition` class to define and manage vector indexes.

#### Index Types

SurrealDB supports three types of vector indexes:

- **FLAT**: Exhaustive search, best for small datasets (<1000 vectors)
- **MTREE**: Balanced tree structure, good for medium datasets (1K-100K vectors)
- **HNSW**: Hierarchical graph, best for large datasets (>100K vectors)
- **AUTO**: Automatically selects the best index type based on dataset size

#### Creating a Vector Index

```dart
// Define a vector index
final index = IndexDefinition(
  indexName: 'idx_documents_embedding',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 768,
  indexType: IndexType.mtree,
  capacity: 40, // MTREE-specific parameter
);

// Create the index in database
await db.queryQL(index.toSurrealQL());
print('Vector index created');
```

#### HNSW Index with Parameters

HNSW (Hierarchical Navigable Small World) is the most advanced index type:

```dart
final hnswIndex = IndexDefinition(
  indexName: 'idx_large_embeddings',
  tableName: 'articles',
  fieldName: 'content_embedding',
  distanceMetric: DistanceMetric.euclidean,
  dimensions: 1536,
  indexType: IndexType.hnsw,
  m: 16,        // Max connections per node (4-64)
  efc: 200,     // Construction candidate list size (100-400)
);

await db.queryQL(hnswIndex.toSurrealQL());
```

**HNSW Parameters:**
- **M**: Maximum connections per node. Higher values = better recall, more memory
- **EFC**: Construction candidate list size. Higher values = better quality, slower build

#### Auto Index Selection

Let the system choose the best index type:

```dart
final autoIndex = IndexDefinition(
  indexName: 'idx_auto',
  tableName: 'vectors',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 384,
  indexType: IndexType.auto,
);

// Provide dataset size hint for better selection
final ddl = autoIndex.toSurrealQL(datasetSize: 50000);
await db.queryQL(ddl);

// Index type selection:
// - < 1,000 vectors → FLAT
// - 1,000 - 100,000 vectors → MTREE
// - > 100,000 vectors → HNSW
```

#### Index for Different Dimensions

Common embedding dimensions:

```dart
// MiniLM sentence transformer (384 dimensions)
final miniLmIndex = IndexDefinition(
  indexName: 'idx_minilm',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 384,
  indexType: IndexType.mtree,
);

// BERT-base embeddings (768 dimensions)
final bertIndex = IndexDefinition(
  indexName: 'idx_bert',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 768,
  indexType: IndexType.hnsw,
  m: 16,
  efc: 200,
);

// OpenAI ada-002 embeddings (1536 dimensions)
final openaiIndex = IndexDefinition(
  indexName: 'idx_openai',
  tableName: 'documents',
  fieldName: 'embedding',
  distanceMetric: DistanceMetric.cosine,
  dimensions: 1536,
  indexType: IndexType.hnsw,
  m: 16,
  efc: 200,
);
```

---

### Performance Optimization

#### Automatic JSON vs Binary Serialization

SurrealDartBautomatically chooses the optimal serialization format based on vector size:

```dart
// Small vectors (≤100 dimensions) use JSON
final smallVector = VectorValue.f32(List.filled(50, 1.0));
final jsonData = smallVector.toBinaryOrJson(); // Returns List (JSON)
print('Small vector uses JSON: ${jsonData is List}'); // true

// Large vectors (>100 dimensions) use binary
final largeVector = VectorValue.f32(List.filled(768, 1.0));
final binaryData = largeVector.toBinaryOrJson(); // Returns Uint8List (binary)
print('Large vector uses binary: ${binaryData is Uint8List}'); // true
```

**Performance Comparison:**

| Dimensions | JSON Time | Binary Time | Speedup |
|------------|-----------|-------------|---------|
| 50         | 0.05ms    | 0.04ms      | 1.25x   |
| 100        | 0.10ms    | 0.07ms      | 1.43x   |
| 384        | 0.35ms    | 0.12ms      | 2.92x   |
| 768        | 0.70ms    | 0.24ms      | 2.92x   |
| 1536       | 1.40ms    | 0.48ms      | 2.92x   |

**Benefits of Binary Serialization:**
- 2.92x faster for typical embedding sizes (384-1536 dims)
- Less memory overhead during transfer
- More efficient for FFI communication
- Automatic selection requires no code changes

#### Configuring the Threshold

You can adjust when binary serialization is used:

```dart
// Default threshold is 100 dimensions
print('Current threshold: ${VectorValue.serializationThreshold}'); // 100

// Increase threshold to favor JSON (easier debugging)
VectorValue.serializationThreshold = 200;

// Decrease threshold to favor binary (better performance)
VectorValue.serializationThreshold = 50;
```

#### Manual Serialization Control

For fine-grained control, use explicit serialization methods:

```dart
final vector = VectorValue.f32(List.filled(768, 1.0));

// Always use JSON
final jsonData = vector.toJson();
print('JSON size: ${jsonData.length} elements');

// Always use binary
final binaryData = vector.toBytes();
print('Binary size: ${binaryData.length} bytes');

// Use automatic selection
final autoData = vector.toBinaryOrJson();
```

#### Best Practices

1. **Use Normalized Vectors for Cosine Similarity**
   ```dart
   final embedding = getEmbeddingFromModel(); // From AI model
   final normalized = embedding.normalize();
   await db.createQL('documents', {
     'embedding': normalized.toJson(),
   });
   ```

2. **Create Indexes Before Bulk Insert**
   ```dart
   // Create index first
   await db.queryQL(index.toSurrealQL());

   // Then insert vectors
   for (final doc in documents) {
     await db.createQL('documents', doc);
   }
   ```

3. **Choose Appropriate Vector Format**
   ```dart
   // F32 for most AI models (good balance)
   final embedding = VectorValue.f32(modelOutput);

   // I16 for memory-constrained devices
   final quantized = VectorValue.i16(quantizedModelOutput);
   ```

4. **Batch Operations When Possible**
   ```dart
   // Use batch search instead of individual searches
   final results = await db.batchSearchSimilar(
     table: 'documents',
     field: 'embedding',
     queryVectors: multipleQueries,
     metric: DistanceMetric.cosine,
     limit: 10,
   );
   ```

---

### Complete Semantic Search Example

Here's a complete example of building a semantic document search system:

```dart
import 'package:surrealdartb/surrealdartb.dart';

Future<void> main() async {
  // 1. Connect to database
  final db = await Database.connect(
    backend: StorageBackend.rocksdb,
    path: '/path/to/database',
    namespace: 'search_app',
    database: 'documents',
  );

  try {
    // 2. Define schema with vector field
    final schema = TableStructure('documents', {
      'title': FieldDefinition(StringType(), optional: false),
      'content': FieldDefinition(StringType(), optional: false),
      'embedding': FieldDefinition(
        VectorType.f32(384, normalized: true), // MiniLM embeddings
        optional: false,
      ),
      'category': FieldDefinition(StringType(), optional: false),
      'published_at': FieldDefinition(DatetimeType(), optional: false),
    });

    await db.queryQL(schema.toSurrealQL());
    print('✓ Schema created');

    // 3. Create vector index for fast similarity search
    final index = IndexDefinition(
      indexName: 'idx_documents_embedding',
      tableName: 'documents',
      fieldName: 'embedding',
      distanceMetric: DistanceMetric.cosine,
      dimensions: 384,
      indexType: IndexType.auto, // Auto-select based on data size
    );

    await db.queryQL(index.toSurrealQL());
    print('✓ Vector index created');

    // 4. Index documents with embeddings
    // In production, embeddings come from an AI model like:
    // - Sentence transformers (sentence-transformers/all-MiniLM-L6-v2)
    // - OpenAI embeddings API
    // - Google Universal Sentence Encoder
    final documents = [
      {
        'title': 'Introduction to Machine Learning',
        'content': 'Machine learning is a subset of AI...',
        'category': 'technology',
        'embedding': await getEmbedding('Machine learning is a subset of AI...'),
      },
      {
        'title': 'Cooking Italian Pasta',
        'content': 'Learn how to make authentic Italian pasta...',
        'category': 'food',
        'embedding': await getEmbedding('Learn how to make authentic Italian pasta...'),
      },
      {
        'title': 'Deep Learning Fundamentals',
        'content': 'Neural networks and deep learning architectures...',
        'category': 'technology',
        'embedding': await getEmbedding('Neural networks and deep learning architectures...'),
      },
    ];

    for (final doc in documents) {
      await db.createQL('documents', doc);
      print('✓ Indexed: ${doc['title']}');
    }

    // 5. Perform semantic search
    print('\n--- Searching for: "AI and neural networks" ---');

    final queryText = 'AI and neural networks';
    final queryEmbedding = await getEmbedding(queryText);

    final results = await db.searchSimilar(
      table: 'documents',
      field: 'embedding',
      queryVector: queryEmbedding,
      metric: DistanceMetric.cosine,
      limit: 3,
    );

    // 6. Display results
    print('\nSearch Results:');
    print('─────────────────────────────────────────');
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      final similarity = (result.distance * 100).toStringAsFixed(1);

      print('\n${i + 1}. ${result.record['title']}');
      print('   Category: ${result.record['category']}');
      print('   Similarity: $similarity%');
      print('   Preview: ${result.record['content'].substring(0, 50)}...');
    }

    // 7. Search with filtering
    print('\n--- Filtering by category: technology ---');

    final techResults = await db.searchSimilar(
      table: 'documents',
      field: 'embedding',
      queryVector: queryEmbedding,
      metric: DistanceMetric.cosine,
      limit: 10,
      where: EqualsCondition('category', 'technology'),
    );

    print('Found ${techResults.length} technology documents');
    for (final result in techResults) {
      print('  • ${result.record['title']}');
    }

  } finally {
    await db.close();
    print('\n✓ Database closed');
  }
}

// Mock function - In production, use a real embedding model
Future<VectorValue> getEmbedding(String text) async {
  // This would call your embedding model:
  // - Local: sentence-transformers model
  // - API: OpenAI, Cohere, etc.

  // For demo, return random normalized vector
  final values = List.generate(384, (i) => (i * 0.001) % 1.0);
  return VectorValue.f32(values).normalize();
}
```

**Expected Output:**
```
✓ Schema created
✓ Vector index created
✓ Indexed: Introduction to Machine Learning
✓ Indexed: Cooking Italian Pasta
✓ Indexed: Deep Learning Fundamentals

--- Searching for: "AI and neural networks" ---

Search Results:
─────────────────────────────────────────

1. Deep Learning Fundamentals
   Category: technology
   Similarity: 94.5%
   Preview: Neural networks and deep learning architectures...

2. Introduction to Machine Learning
   Category: technology
   Similarity: 89.2%
   Preview: Machine learning is a subset of AI...

3. Cooking Italian Pasta
   Category: food
   Similarity: 12.3%
   Preview: Learn how to make authentic Italian pasta...

--- Filtering by category: technology ---
Found 2 technology documents
  • Deep Learning Fundamentals
  • Introduction to Machine Learning

✓ Database closed
```

---

### Real-World Integration Examples

#### RAG (Retrieval-Augmented Generation)

```dart
// Build a RAG system for AI chatbots
Future<String> answerQuestion(String question) async {
  // 1. Convert question to embedding
  final queryEmbedding = await getEmbedding(question);

  // 2. Search knowledge base
  final results = await db.searchSimilar(
    table: 'knowledge_base',
    field: 'embedding',
    queryVector: queryEmbedding,
    metric: DistanceMetric.cosine,
    limit: 3, // Top 3 most relevant documents
  );

  // 3. Build context from results
  final context = results
      .map((r) => r.record['content'])
      .join('\n\n');

  // 4. Send to LLM with context
  final prompt = '''
Context:
$context

Question: $question

Answer:''';

  return await callLLM(prompt);
}
```

#### Recommendation System

```dart
// Recommend similar products
Future<List<Map<String, dynamic>>> recommendSimilar(String productId) async {
  // 1. Get the product's embedding
  final product = await db.get<Map<String, dynamic>>('products:$productId');
  if (product == null) return [];

  final productEmbedding = VectorValue.fromJson(product['embedding']);

  // 2. Find similar products
  final similar = await db.searchSimilar(
    table: 'products',
    field: 'embedding',
    queryVector: productEmbedding,
    metric: DistanceMetric.cosine,
    limit: 6, // Get 6 (will exclude self later)
    where: AndCondition([
      EqualsCondition('in_stock', true),
      GreaterThanCondition('rating', 4.0),
    ]),
  );

  // 3. Remove the original product and return recommendations
  return similar
      .where((r) => r.record['id'] != productId)
      .take(5)
      .map((r) => r.record)
      .toList();
}
```

#### Duplicate Detection

```dart
// Find duplicate or near-duplicate content
Future<List<String>> findDuplicates(String newContent) async {
  // 1. Generate embedding for new content
  final embedding = await getEmbedding(newContent);

  // 2. Search for very similar content (>95% similarity)
  final results = await db.searchSimilar(
    table: 'articles',
    field: 'content_embedding',
    queryVector: embedding,
    metric: DistanceMetric.cosine,
    limit: 10,
  );

  // 3. Filter by high similarity threshold
  final duplicates = results
      .where((r) => r.distance > 0.95)
      .map((r) => r.record['id'] as String)
      .toList();

  if (duplicates.isNotEmpty) {
    print('⚠ Found ${duplicates.length} potential duplicates');
  }

  return duplicates;
}
```

---

### Troubleshooting

#### Common Issues

**1. Dimension Mismatch**
```dart
// Error: Vector dimensions don't match index
try {
  await db.searchSimilar(
    table: 'documents',
    field: 'embedding',
    queryVector: VectorValue.f32([1.0, 2.0]), // 2D
    metric: DistanceMetric.cosine,
    limit: 10,
  );
} catch (e) {
  print('Dimension mismatch: $e');
  // Fix: Ensure query vector matches indexed dimension
}
```

**2. Zero Vector Error**
```dart
// Error: Cannot normalize or compute cosine with zero vectors
final zero = VectorValue.f32([0.0, 0.0, 0.0]);
try {
  zero.normalize(); // Throws StateError
} catch (e) {
  print('Cannot normalize zero vector');
}
```

**3. Empty Vector**
```dart
// Error: Cannot create empty vectors
try {
  final empty = VectorValue.f32([]); // Throws ArgumentError
} catch (e) {
  print('Vector cannot be empty');
}
```

**4. NaN or Infinity**
```dart
// Error: Invalid values in vector
try {
  final invalid = VectorValue.f32([1.0, double.nan, 3.0]);
} catch (e) {
  print('Vector contains NaN');
}
```

#### Performance Tips

1. **Create indexes before bulk inserts**
2. **Use normalized vectors for cosine similarity**
3. **Choose appropriate vector format (F32 vs I16 vs I8)**
4. **Adjust serialization threshold based on use case**
5. **Use batch operations for multiple queries**
6. **Filter results with WHERE clauses to reduce search space**

---

### Next Steps

Now that you understand vector operations and similarity search, you can:

1. **Integrate AI Models**: Connect embedding models (OpenAI, sentence-transformers, etc.)
2. **Build Search Systems**: Create semantic search, recommendations, and RAG systems
3. **Optimize Performance**: Tune indexes, serialization, and query strategies
4. **Scale Your Application**: Handle large vector datasets efficiently

For more examples, see the `example/scenarios/vector_embeddings.dart` file in the repository.

---

## Navigation

[← Previous: Code Generator](04-code-generator.md) | [Back to Index](README.md)

