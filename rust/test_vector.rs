use surrealdb::Surreal;
use surrealdb::engine::any::connect;
use surrealdb::sql::Value;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=================================================");
    println!("SurrealDB Vector Function Support Test");
    println!("=================================================\n");

    // Connect to in-memory database
    println!("📡 Connecting to mem://");
    let db: Surreal<surrealdb::engine::any::Any> = connect("mem://").await?;

    println!("📂 Using namespace 'test' and database 'test'");
    db.use_ns("test").use_db("test").await?;

    // Get version info
    println!("\n🔍 Checking SurrealDB version...");
    let version_result = db.query("SELECT * FROM $version").await?;
    println!("   Version info: {:?}\n", version_result);

    // Create table with array field for vectors
    println!("📋 Creating test table with vector fields...");
    db.query("DEFINE TABLE vectors SCHEMAFULL;").await?;
    db.query("DEFINE FIELD vec ON vectors TYPE array;").await?;
    db.query("DEFINE FIELD name ON vectors TYPE string;").await?;
    println!("   ✅ Table created\n");

    // Insert test vectors
    println!("📝 Inserting test vectors...");
    db.query("CREATE vectors:1 SET name = 'vec1', vec = [1.0, 0.0, 0.0];").await?;
    db.query("CREATE vectors:2 SET name = 'vec2', vec = [0.0, 1.0, 0.0];").await?;
    db.query("CREATE vectors:3 SET name = 'vec3', vec = [0.9, 0.1, 0.0];").await?;
    db.query("CREATE vectors:4 SET name = 'vec4', vec = [0.5, 0.5, 0.5];").await?;
    println!("   ✅ 4 test vectors inserted\n");

    // Verify data was inserted
    println!("🔍 Verifying inserted data...");
    let check = db.query("SELECT * FROM vectors;").await?;
    println!("   Records: {:?}\n", check);

    // Define query vector for testing
    let query_vec = "[1.0, 0.0, 0.0]";
    println!("🎯 Query vector: {}\n", query_vec);

    println!("=================================================");
    println!("Testing Vector Distance Functions");
    println!("=================================================\n");

    // Test euclidean distance
    test_function(
        &db,
        "vector::distance::euclidean",
        &format!("SELECT name, vec, vector::distance::euclidean(vec, {}) AS distance FROM vectors ORDER BY distance", query_vec),
    ).await;

    // Test manhattan distance
    test_function(
        &db,
        "vector::distance::manhattan",
        &format!("SELECT name, vec, vector::distance::manhattan(vec, {}) AS distance FROM vectors ORDER BY distance", query_vec),
    ).await;

    // Test minkowski distance
    test_function(
        &db,
        "vector::distance::minkowski",
        &format!("SELECT name, vec, vector::distance::minkowski(vec, {}, 3) AS distance FROM vectors ORDER BY distance", query_vec),
    ).await;

    // Test chebyshev distance
    test_function(
        &db,
        "vector::distance::chebyshev",
        &format!("SELECT name, vec, vector::distance::chebyshev(vec, {}) AS distance FROM vectors ORDER BY distance", query_vec),
    ).await;

    // Test hamming distance
    test_function(
        &db,
        "vector::distance::hamming",
        &format!("SELECT name, vec, vector::distance::hamming(vec, {}) AS distance FROM vectors ORDER BY distance", query_vec),
    ).await;

    println!("\n=================================================");
    println!("Testing Vector Similarity Functions");
    println!("=================================================\n");

    // Test cosine similarity
    test_function(
        &db,
        "vector::similarity::cosine",
        &format!("SELECT name, vec, vector::similarity::cosine(vec, {}) AS similarity FROM vectors ORDER BY similarity DESC", query_vec),
    ).await;

    // Test jaccard similarity
    test_function(
        &db,
        "vector::similarity::jaccard",
        &format!("SELECT name, vec, vector::similarity::jaccard(vec, {}) AS similarity FROM vectors ORDER BY similarity DESC", query_vec),
    ).await;

    // Test pearson similarity
    test_function(
        &db,
        "vector::similarity::pearson",
        &format!("SELECT name, vec, vector::similarity::pearson(vec, {}) AS similarity FROM vectors ORDER BY similarity DESC", query_vec),
    ).await;

    println!("\n=================================================");
    println!("Testing KNN Operator");
    println!("=================================================\n");

    // Test KNN operator with euclidean
    test_function(
        &db,
        "KNN operator <|limit, EUCLIDEAN|>",
        &format!("SELECT name, vec, vector::distance::knn() AS distance FROM vectors WHERE vec <|2, EUCLIDEAN|> {} ORDER BY distance", query_vec),
    ).await;

    // Test KNN operator with cosine
    test_function(
        &db,
        "KNN operator <|limit, COSINE|>",
        &format!("SELECT name, vec, vector::distance::knn() AS distance FROM vectors WHERE vec <|2, COSINE|> {} ORDER BY distance", query_vec),
    ).await;

    println!("\n=================================================");
    println!("Testing Vector Index Creation");
    println!("=================================================\n");

    // Test HNSW index
    test_function(
        &db,
        "HNSW index creation",
        "DEFINE INDEX hnsw_idx ON vectors FIELDS vec HNSW DIMENSION 3 DIST EUCLIDEAN;",
    ).await;

    // Test M-Tree index
    test_function(
        &db,
        "M-Tree index creation",
        "DEFINE INDEX mtree_idx ON vectors FIELDS vec MTREE DIMENSION 3 DIST COSINE;",
    ).await;

    println!("\n=================================================");
    println!("Summary");
    println!("=================================================\n");
    println!("Test completed! Review the results above to see which");
    println!("vector functions are supported in this SurrealDB version.\n");

    Ok(())
}

async fn test_function(db: &Surreal<surrealdb::engine::any::Any>, name: &str, query: &str) {
    println!("🧪 Testing: {}", name);
    println!("   Query: {}", query);

    match db.query(query).await {
        Ok(mut result) => {
            // Try to extract the result
            match result.take::<Vec<Value>>(0) {
                Ok(values) => {
                    println!("   ✅ SUCCESS");
                    if !values.is_empty() {
                        println!("   📊 Results:");
                        for (i, value) in values.iter().take(3).enumerate() {
                            println!("      {}. {:?}", i + 1, value);
                        }
                        if values.len() > 3 {
                            println!("      ... and {} more", values.len() - 3);
                        }
                    } else {
                        println!("   ⚠️  Query succeeded but returned no results");
                    }
                }
                Err(e) => {
                    println!("   ⚠️  Query succeeded but couldn't parse results: {}", e);
                }
            }
        }
        Err(e) => {
            println!("   ❌ FAILED");
            println!("   Error: {}", e);
        }
    }
    println!();
}
