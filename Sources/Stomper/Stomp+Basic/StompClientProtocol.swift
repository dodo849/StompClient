//
//  StompProtocol.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

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
        body: StompBody?,
        _ completion: @escaping ((any Error)?) -> Void
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
        _ completion: @escaping (Result<StompReceiveMessage, Error>) -> Void
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
        _ receiveCompletion: @escaping (Result<StompReceiveMessage, Error>) -> Void
    )
    
    /**
     Unsubscribes from a specific topic.
     
     - Parameters:
        - topic: The topic to unsubscribe from.
        - completion: A completion handler called when the unsubscription is successful or if an error occurs.
     */
    func unsubscribe(
        headers: [String: String],
        _ completion: @escaping ((any Error)?) -> Void
    )
    
    /**
     Disconnects from the STOMP server.
     */
    func disconnect()
}
