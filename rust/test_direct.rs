use surrealdb::Surreal;
use surrealdb::engine::any::connect;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Connecting to mem://");
    let db: Surreal<surrealdb::engine::any::Any> = connect("mem://").await?;
    
    println!("Using namespace and database");
    db.use_ns("test").use_db("test").await?;
    
    println!("Executing query: INFO FOR DB");
    let result = db.query("INFO FOR DB;").await?;
    
    println!("Query result: {:?}", result);
    
    Ok(())
}
