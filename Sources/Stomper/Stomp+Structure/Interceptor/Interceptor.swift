//
//  Intercepter.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public protocol Interceptor: Executor & Retrier {}

public protocol Executor {
    func execute<E>(
        entry: E,
        completion: @escaping (E) -> Void
    ) where E: EntryType

}

public protocol Retrier {
    func retry<E>(
        entry: E,
        error: Error,
        completion: @escaping (E, InterceptorRetryType) -> Void
    ) where E: EntryType
}
