# Rust SDK

Simply include `db2.rs` in your project to get access to Db2 REST functionality. Example:

```Rust
use std::collections::HashMap;
use std::error::Error;
use serde::Deserialize;
use tokio::time::Duration;
use crate::db2::{AuthSettings, Db2REST, NoParameters, Response, Job};

mod db2;

#[derive(Deserialize)]
struct Movie {
    id: i32,
    title: String,
}

async fn example() -> Result<(), Box<dyn Error>> {
    // Instantiate the structure containing all the authentication settings for your database & Db2 REST
    let settings = AuthSettings{
        ...
    };
    let db2 = Db2REST::connect(settings).await?; // Make the connection to Db2 REST & Db2

    // Run a "query" type service synchronously with {"query": "toy story"} as a parameter.
    let search_movies: Response<Movie> = db2.run_sync_query_service("FindMovies", "1.0", HashMap::from([("query", "toy story")])).await?;
    // Run a "query" type SQL command synchronously with no parameters.
    let all_movies: Response<Movie> = db2.run_sync_query_sql("SELECT * FROM MOVIES", NoParameters{}).await?;

    // Run a "statement" type service synchronously with a Movie as a parameter.
    db2.run_sync_statement_service("InsertMovie", "1.0", Movie{
        id: 30,
        title: "The Movie".to_string(),
    }).await?;
    // Run a "statement" type SQL command synchronously with {"id": 30} as a parameter.
    db2.run_sync_statement_sql("DELETE FROM MOVIES WHERE ID = ?", HashMap::from([("id", 30)])).await?;

    // Two ways of instantiating the same asynchronous job (one using a service, one using SQL).
    // Both take no parameters.
    let all_movies_job_1: Job<Movie> = db2.run_async_service("GetAllMovies", "1.0", NoParameters{}).await?;
    let all_movies_job_2: Job<Movie> = db2.run_async_sql("SELECT * FROM MOVIES", NoParameters{}).await?;
    // Loop through the pages of the job while more results exist, refreshing for the next page
    // every 500 milliseconds.
    while let Some(movies_page) = all_movies_job.next_page(10, Duration::from_millis(500)).await? {
        // Use movies_page
    }
    // If you stopped the loop early, use stop_job() to stop the job on the Db2 REST end.
    all_movies_job.stop_job().await?;

    Ok(())
}
```
