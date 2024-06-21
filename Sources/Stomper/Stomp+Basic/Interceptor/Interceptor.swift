//
//  Intercepter.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public protocol Interceptor: Executor & Retrier {}

/// The `Executor` protocol defines a method that is executed before sending a message to the server.
public protocol Executor {
    /**
     Executes a given message before it is sent to the server.
     
     - Parameters:
        - message: The `StompRequestMessage` provided before sending the request to the server.
        - completion: The request continues with the message passed to the completion handler.
          
     - Warning: You must call the `completion` closure to proceed with sending the message.
     */
    func execute(
        message: StompRequestMessage,
        completion: @escaping (StompRequestMessage) -> Void
    )
}

/// The `Retrier` protocol defines a method that is executed when an error is received.
public protocol Retrier {
    /**
     Retries sending a message after an error is received.
     
     - Parameters:
        - message: The `StompRequestMessage` failed request.
        - error: The `Error` frame from the server.
        - completion: The request will be retried with a message passed to the completion handler.
     
     - Warning: You must call the `completion` closure to proceed with sending the message.
     */
    func retry(
        message: StompRequestMessage,
        errorMessage: StompReceiveMessage,
        completion: @escaping (StompRequestMessage, InterceptorRetryType) -> Void
    )
}
