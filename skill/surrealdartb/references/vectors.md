# Vector/AI Features

**Primary File:** `lib/src/types/vector_value.dart`

## VectorValue Types

Six vector formats for different precision/compression needs.

### Constructors

```dart
VectorValue.f32(List<double> values)   // Float32 - standard AI embeddings
VectorValue.f64(List<double> values)   // Float64 - high precision
VectorValue.i8(List<int> values)       // Int8 - 75% compression
VectorValue.i16(List<int> values)      // Int16 - 50% compression
VectorValue.i32(List<int> values)      // Int32 - integer vectors
VectorValue.i64(List<int> values)      // Int64 - large integers
```

**Example:**
```dart
// OpenAI embedding (1536 dimensions)
final vec = VectorValue.f32(openaiEmbedding);

// Quantized for storage savings
final compressed = VectorValue.i8(quantizedValues);
```

### Format Selection Guide

| Format | Use Case | Storage | Precision |
|--------|----------|---------|-----------|
| F32 | Standard AI/ML embeddings (OpenAI, Cohere) | 4 bytes/dim | High |
| F64 | Scientific computing, high precision | 8 bytes/dim | Highest |
| I8 | Extreme compression (quantized) | 1 byte/dim | Low |
| I16 | Balanced compression | 2 bytes/dim | Medium |
| I32 | Integer-based vectors | 4 bytes/dim | Integer |
| I64 | Large integer values | 8 bytes/dim | Integer |

## Vector Operations

### Distance Calculations

```dart
double euclidean(VectorValue other)    // L2 norm - general purpose
double cosine(VectorValue other)       // Angle - text embeddings (best for semantic)
double manhattan(VectorValue other)    // L1 norm - high-dim, outlier-robust
double dotProduct(VectorValue other)   // Dot product
```

**Example:**
```dart
final similarity = vec1.cosine(vec2);  // 0.0 to 1.0 (higher = more similar)
final distance = vec1.euclidean(vec2); // Lower = more similar
```

### Vector Math

```dart
double magnitude()              // Vector magnitude/norm
VectorValue normalize()         // Unit vector (magnitude = 1)
bool isNormalized()            // Check if already normalized
```

**Example:**
```dart
final unit = vec.normalize();
assert(unit.isNormalized());
```

## Serialization

### Hybrid Serialization Strategy

**Automatic selection based on dimensions:**
- ≤100 dims: JSON (human-readable, debugging)
- >100 dims: Binary (2.92x faster, less memory)

### Methods

```dart
dynamic toJson()                    // Auto JSON/binary
Uint8List toBytes()                 // Force binary
static VectorValue fromJson(data)   // Deserialize
static VectorValue fromBytes(data)  // From binary
```

**Example:**
```dart
// Store in database
await db.createQL('docs', {
  'embedding': vec.toJson(),  // Auto-optimized
});

// Retrieve and deserialize
final result = await db.get('docs:123');
final retrieved = VectorValue.fromJson(result['embedding']);
```

## Vector Indexing

**File:** `lib/src/vector/index_type.dart`

### Index Types

```dart
IndexType.hnsw     // Hierarchical Navigable Small World (>100K vectors)
IndexType.mtree    // M-Tree (1K-100K vectors)
IndexType.flat     // Brute-force (< 1K vectors, exact results)
IndexType.auto     // Auto-select based on dataset size
```

### Create Vector Index

**Method:** `Database.createVectorIndex()`

```dart
Future<void> createVectorIndex({
  required String table,
  required String field,
  required int dimensions,
  required IndexType indexType,
  required DistanceMetric metric,
  int? hnswM,        // HNSW: connections per node (default: 16)
  int? hnswEfc,      // HNSW: construction quality (default: 150)
  int? mtreeCapacity, // M-Tree: node capacity (default: 40)
})
```

**Example:**
```dart
// Create HNSW index for semantic search
await db.createVectorIndex(
  table: 'documents',
  field: 'embedding',
  dimensions: 384,
  indexType: IndexType.hnsw,
  metric: DistanceMetric.cosine,
  hnswM: 16,
  hnswEfc: 150,
);
```

### Index Management

```dart
Future<bool> hasVectorIndex(String table, String field)
Future<void> dropVectorIndex(String table, String field)
```

**Example:**
```dart
if (await db.hasVectorIndex('documents', 'embedding')) {
  await db.dropVectorIndex('documents', 'embedding');
}
```

### Index Parameters

**HNSW Parameters:**
- `hnswM` (default: 16) - Connections per node (higher = better recall, more memory)
- `hnswEfc` (default: 150) - Construction quality (higher = better quality, slower build)

**M-Tree Parameters:**
- `mtreeCapacity` (default: 40) - Node capacity (affects tree balance)

## Distance Metrics

**File:** `lib/src/vector/distance_metric.dart`

```dart
DistanceMetric.euclidean   // L2 norm - general purpose
DistanceMetric.cosine      // Angle - text embeddings (recommended for semantic search)
DistanceMetric.manhattan   // L1 norm - high-dimensional, outlier-robust
DistanceMetric.minkowski   // Generalized distance
```

**Metric Selection:**
- **Cosine:** Text embeddings, semantic search (OpenAI, sentence-transformers)
- **Euclidean:** Image embeddings, general ML
- **Manhattan:** High-dimensional data, robust to outliers

## Similarity Search

### Single Query

**Method:** `Database.searchSimilar()`

```dart
Future<List<SimilarityResult>> searchSimilar({
  required String table,
  required String field,
  required VectorValue queryVector,
  required DistanceMetric metric,
  required int limit,
  WhereCondition? where,  // Optional filtering
})
```

**Example:**
```dart
final results = await db.searchSimilar(
  table: 'documents',
  field: 'embedding',
  queryVector: queryVec,
  metric: DistanceMetric.cosine,
  limit: 10,
);

for (final result in results) {
  print('${result.record['title']}: ${result.distance}');
}
```

### Batch Query

**Method:** `Database.batchSearchSimilar()`

```dart
Future<Map<int, List<SimilarityResult>>> batchSearchSimilar({
  required String table,
  required String field,
  required List<VectorValue> queryVectors,
  required DistanceMetric metric,
  required int limit,
})
```

**Example:**
```dart
final batchResults = await db.batchSearchSimilar(
  table: 'documents',
  field: 'embedding',
  queryVectors: [vec1, vec2, vec3],
  metric: DistanceMetric.cosine,
  limit: 5,
);

// Access by index
final resultsForVec1 = batchResults[0];
```

### With Filtering

```dart
final filtered = await db.searchSimilar(
  table: 'products',
  field: 'embedding',
  queryVector: queryVec,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: EqualsCondition('category', 'electronics'),
);
```

## SimilarityResult

**File:** `lib/src/vector/similarity_result.dart`

```dart
class SimilarityResult {
  final Map<String, dynamic> record;  // Full record data
  final double distance;              // Distance score
}
```

**Lower distance = more similar** (except for dot product)

## Vector Schema Definition

### In TableStructure

```dart
'embedding': FieldDefinition(
  VectorType(VectorFormat.f32, 384),
  optional: false,
)
```

### In DDL (SCHEMAFULL Tables)

**CRITICAL:** Use `array<float>` or `array<number>`, NOT `vector<F32,384>`

```dart
await db.queryQL('''
  DEFINE TABLE documents SCHEMAFULL;
  DEFINE FIELD title ON documents TYPE string;
  DEFINE FIELD embedding ON documents TYPE array<float>;
''');
```

## Complete Semantic Search Example

```dart
// 1. Create table with vector field
await db.queryQL('''
  DEFINE TABLE articles SCHEMAFULL;
  DEFINE FIELD title ON articles TYPE string;
  DEFINE FIELD content ON articles TYPE string;
  DEFINE FIELD embedding ON articles TYPE array<float>;
''');

// 2. Create vector index
await db.createVectorIndex(
  table: 'articles',
  field: 'embedding',
  dimensions: 384,
  indexType: IndexType.hnsw,
  metric: DistanceMetric.cosine,
);

// 3. Store documents with embeddings
final vec = VectorValue.f32(await generateEmbedding(text));
await db.createQL('articles', {
  'title': 'AI Introduction',
  'content': text,
  'embedding': vec.toJson(),
});

// 4. Search similar documents
final query = VectorValue.f32(await generateEmbedding(searchText));
final results = await db.searchSimilar(
  table: 'articles',
  field: 'embedding',
  queryVector: query,
  metric: DistanceMetric.cosine,
  limit: 5,
);

// 5. Process results
for (final result in results) {
  print('${result.record['title']} (similarity: ${1 - result.distance})');
}
```

## Common Patterns

### Store and Search Workflow

```dart
// Generate embedding (use your preferred model)
List<double> generateEmbedding(String text) async {
  // Call OpenAI, Cohere, sentence-transformers, etc.
  return embedding;
}

// Store with vector
final vec = VectorValue.f32(await generateEmbedding(document));
await db.createQL('docs', {
  'text': document,
  'embedding': vec.toJson(),
});

// Search
final queryVec = VectorValue.f32(await generateEmbedding(query));
final similar = await db.searchSimilar(
  table: 'docs',
  field: 'embedding',
  queryVector: queryVec,
  metric: DistanceMetric.cosine,
  limit: 10,
);
```

### Filtered Semantic Search

```dart
// Search within category
final results = await db.searchSimilar(
  table: 'products',
  field: 'embedding',
  queryVector: queryVec,
  metric: DistanceMetric.cosine,
  limit: 10,
  where: EqualsCondition('category', 'electronics') &
         GreaterThanCondition('price', 100),
);
```

### Multi-Format Support

```dart
// Store both precision and compressed
await db.createQL('vectors', {
  'vec_high': VectorValue.f32(values).toJson(),
  'vec_compressed': VectorValue.i8(quantized).toJson(),
});
```

## Performance Optimization

### Index Selection

- **< 1K vectors:** Use `IndexType.flat` (exact, no overhead)
- **1K-100K:** Use `IndexType.mtree` (balanced)
- **> 100K:** Use `IndexType.hnsw` (best for large scale)

### Serialization

- Vectors >100 dims automatically use binary (2.92x faster)
- Normalize vectors for cosine similarity before storing
- Batch operations when possible

### Query Optimization

```dart
// Batch queries more efficient than sequential
final results = await db.batchSearchSimilar(/*...*/);

// Use filtering to reduce search space
final filtered = await db.searchSimilar(where: condition, /*...*/);
```

## Gotchas

1. **DDL Syntax:** Use `array<float>` in SCHEMAFULL tables, NOT `vector<F32,384>`
2. **Normalization:** Cosine similarity benefits from normalized vectors
3. **Dimensions:** Must match between VectorType definition and actual data
4. **Index Creation:** Create index AFTER table has data for better performance
5. **Distance Interpretation:** Lower = more similar (except dot product where higher = more similar)
6. **Format Compatibility:** Cannot compare vectors of different formats directly
7. **Embedding Generation:** Not included - use external service (OpenAI, Cohere, etc.)
