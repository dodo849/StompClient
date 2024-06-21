//
//  StompProtocol.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

/// Client converting WebSocket requests to STOMP behavior
public protocol StompClientProtocol {
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
        - acceptVersion: The STOMP protocol version the client supports. Default is "1.2".
        - completion: A completion handler called when the connection is established or if an error occurs.
     */
    func connect(
        headers: [String: String],
        _ connectCompletion: @escaping (Result<Void, Error>) -> Void
    )
    
    /**
     Sends a message to a specific topic.
     
     - Parameters:
        - topic: The topic to which the message is sent.
        - body: The body of the message to be sent.
        - receiptID: An identifier for the receipt. The server will acknowledge the processing of this frame with a RECEIPT frame.
        - completion: A completion handler called when the receipt for the message is received or if an error occurs.
     */
    func send(
        headers: [String: String],
        body: StompBody?,
        _ receiptCompletion: @escaping (Result<StompReceiveMessage, Error>) -> Void
    )
    
    /**
     Subscribes to a specific topic.
     
     - Parameters:
        - topic: The topic to subscribe to.
        - id: An optional subscription ID. Default is new UUID.
        - receiveCompletion: A completion handler called when a message is received or if an error occurs.
     */
    func subscribe(
        headers: [String: String],
        _ receiveCompletion: @escaping (Result<StompReceiveMessage, Never>) -> Void
    )
    
    /**
     Unsubscribes from a specific topic.
     
     - Parameters:
        - topic: The topic to unsubscribe from.
        - completion: A completion handler called when the unsubscription is successful or if an error occurs.
     */
    func unsubscribe(
        headers: [String: String]
    )
    
    /**
     Disconnects from the STOMP server.
     
     올바르게 종료되면 클로저가 실행되고 websocket connect가 종료됨.
     */
    func disconnect(
        headers: [String: String],
        _ receiptCompletion: @escaping (Result<Void, Error>) -> Void
    )
    
    func enableLogging()
    
    func setRetirier(_ retrier: Retrier)
}
