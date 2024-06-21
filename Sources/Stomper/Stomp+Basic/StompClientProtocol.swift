//
//  StompProtocol.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

/// Client converting WebSocket requests to STOMP behavior
public protocol StompClientProtocol: AnyObject {
    /**
     Sends a generic STOMP message.
     
     - Parameters:
        - message: The STOMP message to be sent.
        - completion: A completion handler called when the message is sent or if an error occurs.
     */
    func sendAnyMessage(
        message: StompRequestMessage,
        _ completion: @escaping (Result<StompReceiveMessage, any Error>) -> Void
    )
    
    /**
     Connects to the STOMP server and sends a CONNECT frame.
     
     - Parameters:
        - headers: The headers to include in the CONNECT frame.
        - connectCompletion: A completion handler called when the connection is established or if an error occurs.
     */
    func connect(
        headers: [String: String],
        _ connectCompletion: @escaping (Result<Void, Error>) -> Void
    )
    
    /**
     Sends a message to a specific topic.
     
     - Parameters:
        - headers: The headers to include in the message frame.
        - body: The body of the message to be sent.
        - receiptCompletion: A completion handler called when the receipt for the message is received or if an error occurs.
     */
    func send(
        headers: [String: String],
        body: StompBody?,
        _ receiptCompletion: @escaping (Result<StompReceiveMessage, Error>) -> Void
    )
    
    /**
     Subscribes to a specific topic.
     
     - Parameters:
        - headers: The headers to include in the SUBSCRIBE frame.
        - receiveCompletion: A completion handler called when a message is received or if an error occurs.
     */
    func subscribe(
        headers: [String: String],
        _ receiveCompletion: @escaping (Result<StompReceiveMessage, Error>) -> Void
    )
    
    /**
     Unsubscribes from a specific topic.
     
     - Parameters:
        - headers: The headers to include in the UNSUBSCRIBE frame.
     */
    func unsubscribe(
        headers: [String: String]
    )
    
    /**
     Disconnects from the STOMP server.
     
     - Parameters:
        - headers: The headers to include in the DISCONNECT frame.
        - receiptCompletion: A completion handler called when the disconnection is successful or if an error occurs.
     */
    func disconnect(
        headers: [String: String],
        _ receiptCompletion: @escaping (Result<Void, Error>) -> Void
    )
    
    /**
     Enables logging for the STOMP client. Default is disabled.
     */
    func enableLogging()
    
    /**
     Sets the retrier for the STOMP client.
     
     - Parameters:
        - retrier: The retrier to handle retry logic.
     */
    func setRetrier(_ retrier: Retrier)
}
