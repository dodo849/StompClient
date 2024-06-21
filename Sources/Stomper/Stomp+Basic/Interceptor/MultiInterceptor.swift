//
//  MultiInterceptor.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

struct MultiInterceptor: Interceptor {
    private let interceptors: [Interceptor]
    
    init(interceptors: [Interceptor]) {
        self.interceptors = interceptors
    }
    
    func execute(
        message: StompRequestMessage,
        completion: @escaping (StompRequestMessage) -> Void
    ) {
        let group = DispatchGroup()
        var allInterceptedMessage = message
        
        interceptors.forEach { interceptor in
            group.enter()
            interceptor.execute(message: allInterceptedMessage) { newMessage in
                allInterceptedMessage = newMessage
                group.leave()
            }
        }
        
        group.notify(queue: .global()) {
            completion(allInterceptedMessage)
        }
    }
    
    func retry(
        message: StompRequestMessage,
        error: any Error,
        completion: @escaping (StompRequestMessage, InterceptorRetryType) -> Void
    ) {
        let group = DispatchGroup()
        var shouldRetry = false
        var retryCount: Int = 0
        var retryDelay: TimeInterval = 0
        var finalError: Error? = nil
        var retryMessage: StompRequestMessage = message
        
        interceptors.forEach { interceptor in
            group.enter()
            interceptor.retry(message: message, error: error) { newMessage, retryType in
                retryMessage = newMessage
                
                switch retryType {
                case .retry:
                    shouldRetry = true
                case .delayedRetry(let count, let delay):
                    shouldRetry = true
                    retryCount = max(retryCount, count)
                    retryDelay = max(retryDelay, delay)
                case .doNotRetry:
                    break
                case .doNotRetryWithError(let error):
                    finalError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .global()) {
            if let finalError = finalError {
                completion(retryMessage, .doNotRetryWithError(finalError))
            } else if shouldRetry {
                if retryDelay > 0 {
                    completion(
                        retryMessage,
                        .delayedRetry(count: retryCount, delay: retryDelay)
                    )
                } else {
                    completion(retryMessage, .retry(count: retryCount))
                }
            } else {
                completion(retryMessage, .doNotRetry)
            }
        }
    }
}
