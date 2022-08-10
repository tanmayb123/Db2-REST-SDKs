# Swift SDK & Codegen

This section consists of both a wrapper & native codegen utility.

## SDK

Simply include `db2.swfit` in your project to get access to Db2 REST functionality. Example:

```Swift
import Foundation

struct Movie {
    var id: Int
    var title: String
}

func example() async throws {
    // Instantiate the structure containing all the authentication settings for your database & Db2 REST
    let settings = Db2REST.AuthSettings(...)
    let db2 = try await Db2REST(authSettings: settings) // Make the connection to Db2 REST & Db2

    // Run a "query" type service synchronously with {"query": "toy story"} as a parameter.
    let searchMovies: Db2REST.Response<Movie>? = try await db2.runSyncJob(
        service: "FindMovies",
        version: "1.0",
        parameters: ["query": "toy story"]
    )
    // Run a "query" type SQL command synchronously with no parameters.
    let allMovies: Db2REST.Response<Movie>? = try await db2.runSyncSQL(
        statement: "SELECT * FROM MOVIES",
        parameters: [:]
    )

    // Run a "statement" type service synchronously with a Movie as a parameter.
    try await db2.runSyncJob(
        service: "InsertMovie",
        version: "1.0",
        parameters: [
            "id": 30,
            "title": "The Movie"
        ]
    )
    // Run a "statement" type SQL command synchronously with {"id": 30} as a parameter.
    try await db2.runSyncSQL(
        statement: "DELETE FROM MOVIES WHERE ID = ?",
        parameters: ["id": 30]
    )

    // Two ways of instantiating the same asynchronous job (one using a service, one using SQL).
    // Both take no parameters.
    let allMoviesJob1: Db2REST.Job<Movie> = try await db2.runAsyncJob(
        service: "GetAllMovies",
        version: "1.0",
        parameters: [:]
    )
    let allMoviesJob2: Db2REST.Job<Movie> = try await db2.runAsyncSQL(
        statement: "SELECT * FROM MOVIES",
        parameters: [:]
    )

    // Loop through the pages of the job while more results exist
    while let moviesPage = try await allMoviesJob.nextPage(limit: 10) {
        // Use moviesPage
    }

    // The jobs are automatically stopped when their reference count hits 0 (i.e. when the object is deinitialized)
}
```

## Codegen

To leverage codegen functionality, simply:

1. Modify the `autogen.py` script's `REST_CONNECTION` global to match your database's authentication details.
1. Run `autogen.py`. This will generate a file named `codegen.json`, which contains information on your Db2 REST services.
1. Compile the `Db2RESTNative-CodeGen-Swift` Xcode project through Xcode.
1. Run the command line utility compiled through Xcode passing it the path to the `codegen.json` file. For example, `./Db2RESTNative-CodeGen-Swift /Users/tanmaybakshi/db2rest/codegen.json`.
1. Done! The utility will output functions for each of your Db2 REST services that use language native types and functionality.
