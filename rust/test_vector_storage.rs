use surrealdb::Surreal;
use surrealdb::engine::any::connect;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=================================================");
    println!("SurrealDB Vector Storage Methods Test");
    println!("=================================================\n");

    let db: Surreal<surrealdb::engine::any::Any> = connect("mem://").await?;
    db.use_ns("test").use_db("test").await?;

    println!("🧪 Test 1: Array type without explicit typing");
    db.query("DEFINE TABLE test1 SCHEMAFULL; DEFINE FIELD vec ON test1 TYPE array;").await?;
    db.query("CREATE test1:1 SET vec = [1.0, 2.0, 3.0];").await?;
    let r1 = db.query("SELECT * FROM test1;").await?;
    println!("   Result: {:?}\n", r1);

    println!("🧪 Test 2: Array<float> type");
    db.query("DEFINE TABLE test2 SCHEMAFULL; DEFINE FIELD vec ON test2 TYPE array<float>;").await?;
    db.query("CREATE test2:1 SET vec = [1.0, 2.0, 3.0];").await?;
    let r2 = db.query("SELECT * FROM test2;").await?;
    println!("   Result: {:?}\n", r2);

    println!("🧪 Test 3: Array<number> type");
    db.query("DEFINE TABLE test3 SCHEMAFULL; DEFINE FIELD vec ON test3 TYPE array<number>;").await?;
    db.query("CREATE test3:1 SET vec = [1.0, 2.0, 3.0];").await?;
    let r3 = db.query("SELECT * FROM test3;").await?;
    println!("   Result: {:?}\n", r3);

    println!("🧪 Test 4: SCHEMALESS table");
    db.query("DEFINE TABLE test4;").await?;
    db.query("CREATE test4:1 SET vec = [1.0, 2.0, 3.0];").await?;
    let r4 = db.query("SELECT * FROM test4;").await?;
    println!("   Result: {:?}\n", r4);

    println!("🧪 Test 5: Using CONTENT instead of SET");
    db.query("DEFINE TABLE test5; DEFINE FIELD vec ON test5 TYPE array;").await?;
    db.query(r#"CREATE test5:1 CONTENT { "vec": [1.0, 2.0, 3.0] };"#).await?;
    let r5 = db.query("SELECT * FROM test5;").await?;
    println!("   Result: {:?}\n", r5);

    println!("🧪 Test 6: Direct INSERT");
    db.query("DEFINE TABLE test6; DEFINE FIELD vec ON test6 TYPE array;").await?;
    db.query(r#"INSERT INTO test6 (vec) VALUES ([1.0, 2.0, 3.0]);"#).await?;
    let r6 = db.query("SELECT * FROM test6;").await?;
    println!("   Result: {:?}\n", r6);

    println!("\n🧪 Test 7: Try vector distance on schemaless table");
    let r7 = db.query("SELECT vec, vector::distance::euclidean(vec, [1.0, 2.0, 3.0]) AS dist FROM test4;").await?;
    println!("   Result: {:?}\n", r7);

    println!("\n🧪 Test 8: Try vector distance on array<float> table");
    let r8 = db.query("SELECT vec, vector::distance::euclidean(vec, [1.0, 2.0, 3.0]) AS dist FROM test2;").await?;
    println!("   Result: {:?}\n", r8);

    println!("\n🧪 Test 9: Test with explicit typing in query");
    db.query("CREATE test4:2 SET vec = <array<float>>[4.0, 5.0, 6.0];").await?;
    let r9 = db.query("SELECT * FROM test4:2;").await?;
    println!("   Result: {:?}\n", r9);

    println!("\n🧪 Test 10: Test vector index on array<float>");
    let r10 = db.query("DEFINE INDEX idx_test2 ON test2 FIELDS vec HNSW DIMENSION 3 DIST EUCLIDEAN;").await?;
    println!("   Result: {:?}\n", r10);

    Ok(())
}
