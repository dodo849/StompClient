//
//  TokenInterceptor.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public struct TokenInterceptor: Interceptor {
    let token: String
    
    public init(token: String) {
        self.token = token
    }
    
    public func execute<E>(
        entry: E,
        completion: @escaping (E) -> Void
    ) where E: EntryType{
        let tokenHeader = ["Authorization": "Bearer \(token)"]
        entry.headers.addHeaders(tokenHeader)
        completion(entry)
    }
    
    public func retry<E>(
        entry: E,
        error: any Error,
        completion: @escaping (E, InterceptorRetryType) -> Void
    ) where E: EntryType {
        completion(entry, .doNotRetry)
    }
}
