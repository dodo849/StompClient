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
    
    public func execute(
        message: StompRequestMessage,
        completion: @escaping (StompRequestMessage) -> Void
    ) {
        let tokenHeader = ["Authorization": "Bearer \(token)"]
        message.headers.addHeaders(tokenHeader)
        completion(message)
    }
    
    public func retry(
        message: StompRequestMessage,
        error: any Error,
        completion: @escaping (StompRequestMessage, InterceptorRetryType) -> Void
    ) {
        completion(message, .doNotRetry)
    }
}
