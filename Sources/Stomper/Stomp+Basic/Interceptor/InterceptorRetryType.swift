//
//  InterceptorRetry.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public enum InterceptorRetryType {
    case retry(count: Int = 1)
    case delayedRetry(count: Int = 1, delay: TimeInterval)
    case doNotRetry
    case doNotRetryWithError(Error)
}

extension InterceptorRetryType {
    var retryRequired: Bool {
        switch self {
        case .retry, .delayedRetry: return true
        default: return false
        }
    }

    var delay: TimeInterval? {
        switch self {
        case let .delayedRetry(_, delay): return delay
        default: return nil
        }
    }

    var error: Error? {
        guard case let .doNotRetryWithError(error) = self else { return nil }
        return error
    }
}
