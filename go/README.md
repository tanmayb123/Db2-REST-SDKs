# Go SDK

Simply include `db2.go` in your project to get access to Db2 REST functionality. Example:

```Go
package main

import (
	"time"
)

type Movie struct {
	ID    int    `json:"id"`
	Title string `json:"title"`
}

func example() {
    // Instantiate the structure containing all the authentication settings for your database & Db2 REST
	settings := AuthSettings{
        ...
    }
	db2, err := Connect(settings) // Make the connection to Db2 REST & Db2
	if err != nil {
		panic(err)
	}

    // Run a "query" type service synchronously with {"query": "toy story"} as a parameter.
	searchMovies, err := RunSyncQueryService[map[string]interface{}, Movie](&db2, "FindMovies", "1.0", map[string]interface{}{"query": "toy story"})
	if err != nil {
		panic(err)
	}
    // Run a "query" type SQL command synchronously with no parameters.
	allMovies, err := RunSyncQuerySQL[interface{}, Movie](&db2, "SELECT * FROM MOVIES", nil)
	if err != nil {
		panic(err)
	}

    // Run a "statement" type service synchronously with a Movie as a parameter.
	err = RunSyncStatementService[Movie](&db2, "InsertMovie", "1.0", Movie{
		ID:    30,
		Title: "The Movie",
	})
	if err != nil {
		panic(err)
	}
    // Run a "statement" type SQL command synchronously with {"id": 30} as a parameter.
	err = RunSyncStatementSQL[map[string]interface{}](&db2, "DELETE FROM MOVIES WHERE ID = ?", map[string]interface{}{"id": 30})
	if err != nil {
		panic(err)
	}

    // Two ways of instantiating the same asynchronous job (one using a service, one using SQL).
    // Both take no parameters.
	allMoviesJob1, err := RunAsyncService[interface{}, Movie](&db2, "GetAllMovies", "1.0", nil)
	if err != nil {
		panic(err)
	}
	allMoviesJob2, err := RunAsyncSQL[interface{}, Movie](&db2, "SELECT * FROM MOVIES", nil)
	if err != nil {
		panic(err)
	}
    // Loop through the pages of the job while more results exist, refreshing for the next page
    // every 500 milliseconds.
	for {
		moviesPage, err := allMoviesJob.NextPage(10, time.Millisecond*500)
		if err != nil {
			panic(err)
		}
		if moviesPage == nil {
			break
		}
        // Use moviesPage
	}
    // If you stopped the loop early, use stop_job() to stop the job on the Db2 REST end.
    allMoviesJob.StopJob()
}
```
