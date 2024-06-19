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
    
    func execute<E>(
        entry: E,
        completion: @escaping (E) -> Void
    ) where E: EntryType {
        let group = DispatchGroup()
        var allInterceptedEntry = entry
        
        interceptors.forEach { interceptor in
            group.enter()
            interceptor.execute(entry: allInterceptedEntry) { newEntry in
                allInterceptedEntry = newEntry
                group.leave()
            }
        }
        
        group.notify(queue: .global()) {
            completion(allInterceptedEntry)
        }
    }
    
    func retry<E>(
        entry: E,
        error: any Error,
        completion: @escaping (E, InterceptorRetryType) -> Void
    ) where E: EntryType {
        let group = DispatchGroup()
        var shouldRetry = false
        var retryDelay: TimeInterval = 0
        var finalError: Error? = nil
        var retryEntry: E = entry
        
        interceptors.forEach { interceptor in
            group.enter()
            interceptor.retry(entry: entry, error: error) { newEntry, result in
                retryEntry = newEntry
                
                switch result {
                case .retry:
                    shouldRetry = true
                case .delayedRetry(let delay):
                    shouldRetry = true
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
                completion(retryEntry, .doNotRetryWithError(finalError))
            } else if shouldRetry {
                if retryDelay > 0 {
                    completion(retryEntry, .delayedRetry(retryDelay))
                } else {
                    completion(retryEntry, .retry)
                }
            } else {
                completion(retryEntry, .doNotRetry)
            }
        }
    }
}
