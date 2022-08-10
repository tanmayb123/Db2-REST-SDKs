# Python SDK

Simply include `db2.py` in your project to get access to Db2 REST functionality. Example:

```Python
import asyncio
import json
from datetime import datetime, timedelta

from db2 import AuthSettings, Db2REST, Job

async def example():
    # Instantiate the class containing all the authentication settings for your database & Db2 REST
    settings = AuthSettings(
        ...
    )
    db2 = await Db2REST.connect(settings) # Make the connection to Db2 REST & Db2

    # Run a "query" type service synchronously with {"query": "toy story"} as a parameter.
    search_movies = await db2.run_sync_query_service("FindMovies", "1.0", {"query": "toy story"})
    # Run a "query" type SQL command synchronously with no parameters.
    all_movies = await db2.run_sync_query_sql("SELECT * FROM MOVIES", {})

    # Run a "statement" type service synchronously with {"id": 30, "title": "The Movie"} as a parameter.
    await db2.run_sync_statement_service("InsertMovie", "1.0", {
        "id": 30,
        "title": "The Movie",
    })
    # Run a "statement" type SQL command synchronously with {"id": 30} as a parameter.
    await db2.run_sync_statement_sql("DELETE FROM MOVIES WHERE ID = ?", {"id": 30})

    # Two ways of instantiating the same asynchronous job (one using a service, one using SQL).
    # Both take no parameters.
    all_movies_job_1 = await db2.run_async_service("GetAllMovies", "1.0", {})
    all_movies_job_2 = await db2.run_async_sql("SELECT * FROM MOVIES", {})
    # Loop through the pages of the job while more results exist, refreshing for the next page
    # every 500 milliseconds.
    while True:
        movies_page = await all_movies_job.next_page(10, 0.5)
        if movies_page is None:
            break
        # Use movies_page
    # If you stopped the loop early, use stop_job() to stop the job on the Db2 REST end.
    all_movies_job.stop_job()
```
