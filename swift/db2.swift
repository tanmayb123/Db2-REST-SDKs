import Foundation

public class Db2REST {
    public struct AuthSettings: Codable {
        var hostname: String
        var database: String
        var dbPort: Int
        var restPort: Int
        var sslDb2: Bool
        var sslRest: Bool
        var password: String
        var username: String
        var expiryTime: String
        
        var urlProtocol: String {
            sslRest ? "https" : "http"
        }

        public init(hostname: String, database: String, dbPort: Int,
                    restPort: Int, sslDb2: Bool, sslRest: Bool,
                    password: String, username: String, expiryTime: String) {
            self.hostname = hostname
            self.database = database
            self.dbPort = dbPort
            self.restPort = restPort
            self.sslDb2 = sslDb2
            self.sslRest = sslRest
            self.password = password
            self.username = username
            self.expiryTime = expiryTime
        }
    }
    
    private struct Auth: Codable {
        var token: String
    }
    
    private struct QueryResponse<T: Codable>: Codable {
        var jobStatus: Int
        var jobStatusDescription: String?
        var resultSet: [T]?
        var rowCount: Int
        
        func export() -> Response<T> {
            return Response(status: Status.from(jobStatus), results: resultSet)
        }
    }
    
    public enum Status {
        case failed
        case new
        case running
        case dataAvailable
        case completed
        case stopping
        
        static func from(_ n: Int) -> Self {
            return [.failed, .new, .running, .dataAvailable, .completed, .stopping][n]
        }
    }
    
    public struct Response<T> {
        var status: Status
        var results: [T]?
    }
    
    private struct JobResponse: Codable {
        var id: String
    }
    
    public actor Job<T: Codable> {
        enum JobError: Error {
            case failure(String?)
            case cancelled
        }
        
        private var executing = false
        private var stopped = false
        private var pageRequest: URLRequest!
        private var stopRequest: URLRequest!
        
        deinit {
            if !stopped {
                let request = stopRequest
                Task {
                    try? await Job.stopJob(stopRequest: request!)
                }
            }
        }
        
        private static func stopJob(stopRequest: URLRequest) async throws {
            let (result, response) = try await URLSession.shared.data(for: stopRequest)
            guard (response as? HTTPURLResponse)?.statusCode == 204 else {
                throw RequestError.invalidResponse(String(data: result, encoding: .utf8)!)
            }
        }
       
        init(jobID: String, authSettings: AuthSettings, authToken: String) async throws {
            guard let nextPageURL = URL(string: "\(authSettings.urlProtocol)://\(authSettings.hostname):\(authSettings.restPort)/v1/services/\(jobID)") else {
                throw RequestError.invalidURL
            }
            pageRequest = URLRequest(url: nextPageURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
            pageRequest.httpMethod = "POST"
            pageRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            pageRequest.addValue(authToken, forHTTPHeaderField: "authorization")
            
            guard let stopURL = URL(string: "http://\(authSettings.hostname):\(authSettings.restPort)/v1/services/stop/\(jobID)") else {
                throw RequestError.invalidURL
            }
            stopRequest = URLRequest(url: stopURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
            stopRequest.httpMethod = "PUT"
            stopRequest.addValue(authToken, forHTTPHeaderField: "authorization")
        }
        
        private func nextRawPage(limit: Int) async throws -> QueryResponse<T>? {
            pageRequest.httpBody = try JSONSerialization.data(withJSONObject: ["limit": limit], options: .init())
            let (result, response) = try await URLSession.shared.data(for: pageRequest)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            guard statusCode == 200 else {
                if statusCode == 404 {
                    return nil
                }
                throw RequestError.invalidResponse(String(data: result, encoding: .utf8)!)
            }
            return try JSONDecoder().decode(QueryResponse<T>.self, from: result)
        }
        
        private func stopJob() async throws {
            defer {
                stopped = true
            }
            try await Job.stopJob(stopRequest: stopRequest)
        }
        
        func nextPage(limit: Int) async throws -> Response<T>? {
            if executing {
                return nil
            }
            executing = true
            defer {
                executing = false
            }
            do {
                while let page = try await nextRawPage(limit: limit) {
                    if page.jobStatus == 0 {
                        return Response(status: .failed, results: nil)
                    }
                    if page.jobStatus == 1 || page.jobStatus == 2 {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        continue
                    }
                    return page.export()
                }
            } catch let error {
                Task {
                    try await stopJob()
                }
                throw error
            }
            return nil
        }
    }

    enum AuthenticationError: Error {
        case noAuthToken
    }
    
    enum RequestError: Error {
        case invalidURL
        case invalidResponse(String)
    }

    public let authSettings: AuthSettings
    private var authToken: String!
    private var authTokenError: Error!
    
    public init(authSettings: AuthSettings) async throws {
        self.authSettings = authSettings
        authToken = try await getDb2AuthToken()
        if authToken == nil {
            throw AuthenticationError.noAuthToken
        }
    }
    
    private func getDb2AuthToken() async throws -> String {
        guard let authUrl = URL(string: "\(authSettings.urlProtocol)://\(authSettings.hostname):\(authSettings.restPort)/v1/auth") else {
            throw RequestError.invalidURL
        }

        let body: [String: Any] = [
            "dbParms": [
                "dbHost": authSettings.hostname,
                "dbName": authSettings.database,
                "dbPort": authSettings.dbPort,
                "isSSLConnection": authSettings.sslDb2,
                "password": authSettings.password,
                "username": authSettings.username
            ],
            "expiryTime": authSettings.expiryTime
        ]
        
        print(String(data: try! JSONSerialization.data(withJSONObject: body, options: .prettyPrinted), encoding: .utf8)!)

        var request = URLRequest(url: authUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .init())
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (result, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            print(String(data: result, encoding: .utf8)!)
            throw RequestError.invalidResponse(String(data: result, encoding: .utf8)!)
        }
        return try JSONDecoder().decode(Auth.self, from: result).token
    }
    
    private func runQuery(service: String, version: String, parameters: [String: Any], sync: Bool) async throws -> Data {
        guard let uploadUrl = URL(string: "\(authSettings.urlProtocol)://\(authSettings.hostname):\(authSettings.restPort)/v1/services/\(service)/\(version)") else {
            throw RequestError.invalidURL
        }

        let body: [String: Any] = [
            "parameters": parameters,
            "sync": sync
        ]

        var request = URLRequest(url: uploadUrl, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .init())
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authToken, forHTTPHeaderField: "authorization")
        
        let (result, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard statusCode == 200 || statusCode == 202 else { throw RequestError.invalidResponse(String(data: result, encoding: .utf8)!) }
        return result
    }

    private func runSQL(statement: String, parameters: [String: Any], isQuery: Bool, sync: Bool) async throws -> Data {
        guard let url = URL(string: "\(authSettings.urlProtocol)://\(authSettings.hostname):\(authSettings.restPort)/v1/services/execsql") else {
            throw RequestError.invalidURL
        }

        let body: [String: Any] = [
            "sqlStatement": statement,
            "parameters": parameters,
            "isQuery": isQuery,
            "sync": sync
        ]

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .init())
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authToken, forHTTPHeaderField: "authorization")

        let (result, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        guard statusCode == 200 || statusCode == 202 else { throw RequestError.invalidResponse(String(data: result, encoding: .utf8)!) }
        return result
    }
    
    func runSyncJob<T: Codable>(service: String, version: String, parameters: [String: Any]) async throws -> Response<T>? {
        let result = try await runQuery(service: service, version: version, parameters: parameters, sync: true)
        return try JSONDecoder().decode(QueryResponse<T>.self, from: result).export()
    }

    func runSyncSQL<T: Codable>(statement: String, parameters: [String: Any]) async throws -> Response<T>? {
        let result = try await runSQL(statement: statement, parameters: parameters, isQuery: true, sync: true)
        return try JSONDecoder().decode(QueryResponse<T>.self, from: result).export()
    }
    
    func runSyncJob(service: String, version: String, parameters: [String: Any]) async throws {
        _ = try await runQuery(service: service, version: version, parameters: parameters, sync: true)
    }

    func runSyncSQL(statement: String, parameters: [String: Any]) async throws {
        _ = try await runSQL(statement: statement, parameters: parameters, isQuery: false, sync: true)
    }
    
    func runAsyncJob<T>(service: String, version: String, parameters: [String: Any]) async throws -> Job<T> {
        let result = try await runQuery(service: service, version: version, parameters: parameters, sync: false)
        let jobId = try JSONDecoder().decode(JobResponse.self, from: result).id
        return try await Job<T>(jobID: jobId, authSettings: authSettings, authToken: authToken)
    }

    func runAsyncSQL<T>(statement: String, parameters: [String: Any]) async throws -> Job<T> {
        let result = try await runSQL(statement: statement, parameters: parameters, isQuery: true, sync: false)
        let jobId = try JSONDecoder().decode(JobResponse.self, from: result).id
        return try await Job(jobID: jobId, authSettings: authSettings, authToken: authToken)
    }
}

protocol Swiftifiable {
    associatedtype SwiftifiedType
    
    func convert() -> SwiftifiedType
}

extension Optional: Swiftifiable where Wrapped: Swiftifiable {
    func convert() -> Wrapped.SwiftifiedType? {
        self == nil ? nil : self.convert()
    }
}

extension Db2REST.Response: Swiftifiable where T: Swiftifiable {
    func convert() -> Db2REST.Response<T.SwiftifiedType> {
        Db2REST.Response(status: status, results: results == nil ? nil : results!.map { $0.convert() })
    }
}

extension Db2REST.Job: Swiftifiable where T: Swiftifiable {
    nonisolated func convert() -> SwiftifiedJob<T> {
        SwiftifiedJob(job: self)
    }
}

actor SwiftifiedJob<T: Codable> where T: Swiftifiable {
    private let job: Db2REST.Job<T>
    
    init(job: Db2REST.Job<T>) {
        self.job = job
    }
    
    func nextPage(limit: Int) async throws -> Db2REST.Response<T.SwiftifiedType>? {
        try await job.nextPage(limit: limit)?.convert()
    }
}

struct Db2NativeUtils {
    @inlinable
    static func convert(_ x: Int) -> Int32 {
        return Int32(x)
    }
    
    @inlinable
    static func convert(_ x: Int32) -> Int {
        return Int(x)
    }
    
    @inlinable
    static func convert(_ x: Int?) -> Int32? {
        return x == nil ? nil : Int32(x!)
    }
    
    @inlinable
    static func convert(_ x: Int32?) -> Int? {
        return x == nil ? nil : Int(x!)
    }
    
    @inlinable
    static func convert<T>(_ x: T) -> T {
        return x
    }
}

struct Nothing: Codable {}
