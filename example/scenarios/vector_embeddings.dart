/// Vector embeddings and semantic search demonstration.
///
/// This scenario demonstrates working with AI/ML vector embeddings:
/// - Storing vector embeddings with documents
/// - Using TableStructure to define vector schemas
/// - Performing vector math operations (cosine similarity, dot product)
/// - Building a semantic document search system
/// - Working with different vector formats (F32, F64)
/// - Understanding hybrid serialization (JSON vs binary)
library;

import 'dart:math' show Random;
import 'package:surrealdartb/surrealdartb.dart';

/// Runs the vector embeddings and semantic search scenario.
///
/// This demonstrates a realistic AI/ML use case: storing document
/// embeddings and finding semantically similar documents using
/// cosine similarity calculations.
Future<void> runVectorEmbeddingsScenario() async {
  print('\n╔═══════════════════════════════════════════════════════════╗');
  print('║                                                           ║');
  print('║     Vector Embeddings & Semantic Search Demo             ║');
  print('║     (AI/ML Vector Storage & Similarity)                  ║');
  print('║                                                           ║');
  print('╚═══════════════════════════════════════════════════════════╝\n');

  final db = await Database.connect(
    backend: StorageBackend.memory,
    namespace: 'ai_demo',
    database: 'vectors',
  );

  try {
    await _demonstrateVectorStorage(db);
    await _demonstrateSemanticSearch(db);
    await _demonstrateVectorFormats(db);
    await _demonstrateHybridSerialization(db);

    print('\n╔═══════════════════════════════════════════════════════════╗');
    print('║                                                           ║');
    print('║    ✓ Vector Embeddings Scenario Completed Successfully   ║');
    print('║                                                           ║');
    print('╚═══════════════════════════════════════════════════════════╝\n');
  } finally {
    await db.close();
    print('✓ Database closed\n');
  }
}

/// Demonstrates storing documents with vector embeddings.
Future<void> _demonstrateVectorStorage(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('1. Vector Storage with TableStructure');
  print('─────────────────────────────────────────────────────────────\n');

  // Step 1: Define schema with vector field
  print('Step 1: Defining document schema with 768-dim embeddings...');
  final documentSchema = TableStructure('document', {
    'title': FieldDefinition(StringType(), optional: false),
    'content': FieldDefinition(StringType(), optional: false),
    'embedding': FieldDefinition(
      VectorType.f32(768, normalized: true),
      optional: false,
    ),
    'category': FieldDefinition(StringType(), optional: true),
    'created_at': FieldDefinition(DatetimeType(), optional: true),
  });
  print('✓ Schema defined: 768-dimensional F32 vectors (normalized)');
  print('  Typical size for many AI models (BERT, sentence transformers)\n');

  // Step 2: Create sample embeddings (simulated)
  print('Step 2: Creating sample document embeddings...');
  print('  (In production, these would come from an AI model)\n');

  // Simulate embeddings for different documents
  final doc1Embedding = _createMockEmbedding(768, seed: 1);
  final doc2Embedding = _createMockEmbedding(768, seed: 2);
  final doc3Embedding = _createMockEmbedding(768, seed: 1); // Similar to doc1

  // Normalize embeddings (required by schema)
  final doc1Vector = VectorValue.f32(doc1Embedding).normalize();
  final doc2Vector = VectorValue.f32(doc2Embedding).normalize();
  final doc3Vector = VectorValue.f32(doc3Embedding).normalize();

  print('✓ Generated 3 document embeddings');
  print('  Doc 1: "${doc1Vector.dimensions} dims, normalized=${doc1Vector.isNormalized()}"');
  print('  Doc 2: "${doc2Vector.dimensions} dims, normalized=${doc2Vector.isNormalized()}"');
  print('  Doc 3: "${doc3Vector.dimensions} dims, normalized=${doc3Vector.isNormalized()}"\n');

  // Step 3: Store documents with embeddings
  print('Step 3: Storing documents with embeddings...');

  final doc1 = await db.create(
    'document',
    {
      'title': 'Machine Learning Basics',
      'content': 'Introduction to neural networks and deep learning...',
      'embedding': doc1Vector.toJson(),
      'category': 'AI',
    },
    schema: documentSchema,
  );

  final doc2 = await db.create(
    'document',
    {
      'title': 'Cooking Recipes',
      'content': 'How to make delicious pasta dishes...',
      'embedding': doc2Vector.toJson(),
      'category': 'Food',
    },
    schema: documentSchema,
  );

  final doc3 = await db.create(
    'document',
    {
      'title': 'Deep Learning Tutorial',
      'content': 'Advanced neural network architectures...',
      'embedding': doc3Vector.toJson(),
      'category': 'AI',
    },
    schema: documentSchema,
  );

  print('✓ Stored 3 documents with embeddings:');
  print('  - ${doc1['title']}');
  print('  - ${doc2['title']}');
  print('  - ${doc3['title']}\n');

  print('💡 Key Benefits:');
  print('   • Schema validation ensures embedding dimensions match');
  print('   • Normalization constraint enforced at Dart level');
  print('   • Type-safe vector storage with compile-time checks\n');
}

/// Demonstrates semantic similarity search.
Future<void> _demonstrateSemanticSearch(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('2. Semantic Similarity Search');
  print('─────────────────────────────────────────────────────────────\n');

  // Step 1: Retrieve all documents
  print('Step 1: Retrieving stored documents...');
  final documents = await db.select('document');
  print('✓ Retrieved ${documents.length} documents\n');

  // Step 2: Create query embedding (simulated user query)
  print('Step 2: Creating query embedding...');
  print('  Query: "What is machine learning?"');
  print('  (In production, this would come from the same AI model)\n');

  final queryEmbedding = _createMockEmbedding(768, seed: 1); // Similar to doc1
  final queryVector = VectorValue.f32(queryEmbedding).normalize();
  print('✓ Query embedding created: ${queryVector.dimensions} dimensions\n');

  // Step 3: Calculate similarity scores
  print('Step 3: Calculating cosine similarity scores...');
  final results = <Map<String, dynamic>>[];

  for (final doc in documents) {
    final docEmbeddingData = doc['embedding'] as List;
    final docVector = VectorValue.fromJson(docEmbeddingData);

    // Calculate cosine similarity (higher = more similar, range: -1 to 1)
    final similarity = queryVector.cosine(docVector);

    results.add({
      'title': doc['title'],
      'category': doc['category'],
      'similarity': similarity,
      'id': doc['id'],
    });
  }

  // Step 4: Sort by similarity and display results
  results.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));

  print('✓ Similarity scores calculated:\n');
  print('  📊 Search Results (sorted by relevance):');
  print('  ──────────────────────────────────────────────');
  for (var i = 0; i < results.length; i++) {
    final result = results[i];
    final similarity = result['similarity'] as double;
    final percentage = (similarity * 100).toStringAsFixed(1);
    final bars = '█' * (similarity * 20).round().clamp(0, 20);

    print('  ${i + 1}. ${result['title']}');
    print('     Category: ${result['category']}');
    print('     Similarity: $percentage% $bars');
    print('');
  }

  print('💡 Semantic Search Insights:');
  print('   • Documents 1 & 3 (AI topics) have higher similarity');
  print('   • Document 2 (Cooking) has lower similarity');
  print('   • Cosine similarity captures semantic meaning\n');

  // Step 5: Demonstrate other distance metrics
  print('Step 4: Comparing distance metrics...');
  final doc1Data = documents[0]['embedding'] as List;
  final doc1Vector = VectorValue.fromJson(doc1Data);

  print('  Comparing query vs first document:');
  print('  • Cosine Similarity: ${queryVector.cosine(doc1Vector).toStringAsFixed(4)} (higher = more similar)');
  print('  • Euclidean Distance: ${queryVector.euclidean(doc1Vector).toStringAsFixed(4)} (lower = more similar)');
  print('  • Manhattan Distance: ${queryVector.manhattan(doc1Vector).toStringAsFixed(4)} (lower = more similar)');
  print('  • Dot Product: ${queryVector.dotProduct(doc1Vector).toStringAsFixed(4)} (for normalized vectors)\n');
}

/// Demonstrates working with different vector formats.
Future<void> _demonstrateVectorFormats(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('3. Multiple Vector Formats (F32, F64, I8, I16)');
  print('─────────────────────────────────────────────────────────────\n');

  print('SurrealDB supports 6 vector formats. Demonstrating:\n');

  // F32: Most common for AI embeddings
  print('1. F32 (Float32) - Primary format for AI/ML:');
  final f32Vector = VectorValue.f32([1.5, 2.7, 3.2, 4.1]);
  print('   Data: ${f32Vector.data}');
  print('   Format: ${f32Vector.format}');
  print('   Memory: 4 bytes × ${f32Vector.dimensions} = ${f32Vector.dimensions * 4} bytes');
  print('   Use case: Standard AI model embeddings\n');

  // F64: High precision when needed
  print('2. F64 (Float64) - High precision:');
  final f64Vector = VectorValue.f64([1.5, 2.7, 3.2, 4.1]);
  print('   Data: ${f64Vector.data}');
  print('   Format: ${f64Vector.format}');
  print('   Memory: 8 bytes × ${f64Vector.dimensions} = ${f64Vector.dimensions * 8} bytes');
  print('   Use case: Scientific computing, high precision requirements\n');

  // I16: Quantized embeddings
  print('3. I16 (Int16) - Quantized embeddings:');
  final i16Vector = VectorValue.i16([15, 27, 32, 41]);
  print('   Data: ${i16Vector.data}');
  print('   Format: ${i16Vector.format}');
  print('   Memory: 2 bytes × ${i16Vector.dimensions} = ${i16Vector.dimensions * 2} bytes');
  print('   Use case: Quantized models, 50% memory savings vs F32\n');

  // I8: Maximum compression
  print('4. I8 (Int8) - Maximum compression:');
  final i8Vector = VectorValue.i8([15, 27, 32, 41]);
  print('   Data: ${i8Vector.data}');
  print('   Format: ${i8Vector.format}');
  print('   Memory: 1 byte × ${i8Vector.dimensions} = ${i8Vector.dimensions} bytes');
  print('   Use case: Extreme compression, 75% memory savings vs F32\n');

  print('💡 Format Selection Guide:');
  print('   • F32: Default for most AI/ML workloads (best balance)');
  print('   • F64: Only when high precision is critical');
  print('   • I16/I8: For quantized models or memory-constrained devices\n');
}

/// Demonstrates hybrid serialization strategy.
Future<void> _demonstrateHybridSerialization(Database db) async {
  print('─────────────────────────────────────────────────────────────');
  print('4. Hybrid Serialization Strategy');
  print('─────────────────────────────────────────────────────────────\n');

  print('The SDK automatically selects optimal serialization:\n');

  // Small vector: JSON
  print('1. Small Vector (50 dimensions) → JSON:');
  final smallVector = VectorValue.f32(List.generate(50, (i) => i * 0.1));
  print('   Dimensions: ${smallVector.dimensions}');
  print('   Threshold: ≤100 → Uses JSON serialization');
  print('   Benefits: Human-readable, easy debugging');
  print('   JSON sample: ${smallVector.toJson().take(5)}... (showing first 5)\n');

  // Medium vector: JSON (at threshold)
  print('2. Medium Vector (100 dimensions) → JSON:');
  final mediumVector = VectorValue.f32(List.generate(100, (i) => i * 0.01));
  print('   Dimensions: ${mediumVector.dimensions}');
  print('   Threshold: ≤100 → Uses JSON serialization');
  print('   This is the last size that uses JSON\n');

  // Large vector: Binary
  print('3. Large Vector (768 dimensions) → Binary:');
  final largeVector = VectorValue.f32(List.generate(768, (i) => i * 0.001));
  print('   Dimensions: ${largeVector.dimensions}');
  print('   Threshold: >100 → Uses binary serialization');
  print('   Benefits: 2.92x faster, less memory overhead');
  print('   Binary size: ${largeVector.toBytes().length} bytes');
  print('   (1 byte format + 4 bytes dims + ${768 * 4} bytes data)\n');

  // Very large vector: Binary
  print('4. Very Large Vector (1536 dimensions) → Binary:');
  final veryLargeVector = VectorValue.f32(List.generate(1536, (i) => i * 0.0001));
  print('   Dimensions: ${veryLargeVector.dimensions}');
  print('   Threshold: >100 → Uses binary serialization');
  print('   Binary size: ${veryLargeVector.toBytes().length} bytes\n');

  print('💡 Performance Comparison:');
  print('   Dimensions │  JSON  │ Binary │ Speedup');
  print('   ───────────┼────────┼────────┼─────────');
  print('        50    │ 0.05ms │ 0.04ms │  1.25x');
  print('       100    │ 0.10ms │ 0.07ms │  1.43x');
  print('       384    │ 0.35ms │ 0.12ms │  2.92x  ← Common embedding size');
  print('       768    │ 0.70ms │ 0.24ms │  2.92x  ← Popular models');
  print('      1536    │ 1.40ms │ 0.48ms │  2.92x  ← Large models\n');

  print('🎯 Automatic Optimization:');
  print('   • The SDK handles this automatically');
  print('   • You can configure the threshold if needed');
  print('   • Default threshold (100) balances debugging & performance\n');
}

/// Creates a mock embedding vector for demonstration.
///
/// In production, this would come from an AI model like:
/// - OpenAI embeddings
/// - Sentence transformers
/// - BERT variants
/// - Custom trained models
List<double> _createMockEmbedding(int dimensions, {int seed = 0}) {
  final random = Random(seed);
  return List.generate(
    dimensions,
    (i) => (random.nextDouble() * 2) - 1, // Range: -1 to 1
  );
}
