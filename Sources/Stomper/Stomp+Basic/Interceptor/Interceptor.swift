//
//  Intercepter.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public protocol Interceptor: Executor & Retrier {}

public protocol Executor {
    func execute(
        message: StompRequestMessage,
        completion: @escaping (StompRequestMessage) -> Void
    )
}

public protocol Retrier {
    func retry(
        message: StompRequestMessage,
        error: Error,
        completion: @escaping (StompRequestMessage, InterceptorRetryType) -> Void
    )
}
