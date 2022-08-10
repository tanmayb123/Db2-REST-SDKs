//
//  URLSession+Linux+Async.swift
//  Db2RESTNative-CodeGen-Swift
//
//  Created by Tanmay Bakshi on 2022-01-18.
//

#if os(Linux)
import FoundationNetworking

extension URLSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.dataTask(with: request) { data, response, error in
                guard let data = data, let response = response else {
                    continuation.resume(throwing: error!)
                }
                
                continuation.resume(returning: (data, response))
            }
        }
    }
}
#endif
