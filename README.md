# SurrealDartB - Dart Wrapper For Embedded SurrealDB

SurrealDB is a powerful Rust based database with advanced workflows for all kinds of data storage. This project exists to provide a generalized wrapper for working with SurrealDB. We use Native_Assets which is slowly coming to fruition in Dart in order to embed SurrealDB and run it locally on device as a local Database.

## Why SurrealDB?

There are tons of excellent options for local databases in Dart and Flutter but very few of them offer the full monte when it comes to things like Vector indexing. SurrealDB offers a quick step up into those AI powered workflows. Since I wanted an on-device solution, I had to find a DB which would run on Device and then also find some way to get it functional in Dart.

Rust pairs handily with Dart. So the decision was made and here we are.

This project is likely overkill unless you are planning to store large amounts of data or you require vector storage. If you need a simple DB then I would recommend looking into hive_ce, sqlite3, or mimir which are all excellent choices.

But if you're hungry for serious data management or on-device AI workloads, then hopefully this package will help satisfy your desire.

## How this package functions

This is a simple wrapper around the RUST API for SurrealDB using the https://github.com/GregoryConrad/native_toolchain_rs package. We are aiming for a 1:1 against SurrealDB's Rust API which allows for local dart functions to setup, run, interact with, and close database connections. While the focus is on embedded databases, there isn't really any reason this cannot work with remote databases as well.
