//
//  StompProviderProtocol.swift
//
//
//  Created by DOYEON LEE on 6/15/24.
//

import Foundation

/// A object that processes requests based on specifications (aka Entry) and assists in data parsing.
public protocol StompProviderProtocol {
    associatedtype Entry: EntryType

    /**
     Sends a request using the specified entry and calls a completion handler when the request is complete.
     
     - Parameters:
        - of: The type of the response to the request. See details
        - entry: The entry containing request details.
        - completion: See details
     
     ### Completion details
     The meaning of completion varies by command:
     - If the command is `connect`, completion indicates that a`CONNECTED` frame has been received from the server.
     - If the command is `subscribe`, completion indicates receiving a `MESSAGE` frame from the server or an error.
     - If the command is `send`, completion indicates receiving a `RECEIPT` frame from the server or an error.
     - For other commands, completion indicates callbacks for the `RECEIPT` frame if there is a receipt-id header.
     
     ### Response type details
     - If the command is `connect`, the response type can only be `String`.
     - For others, the response type can `String`, `Data`, `Decodable` or `StompReceiveMessage`. 
       Use `String`, `Data`, or `Decodable` based on your server specifications to receive only the body.
       Or use `StompReceiveMessage` to receive the full information.
     */
    func request<Response>(
        of: Response.Type,
        entry: Entry,
        _ completion: @escaping (Result<Response, any Error>) -> Void
    )
    
    /**
     Enables logging for the socket level log.
     
     - Note: Use logging during debugging phases only.
     */
    func enableLogging() -> Self 
    
    /** 
     Set the interceptors for the StompProvider.
     */
    func intercepted(_ intercepter: Interceptor) -> Self
    
    /**
     Disconnects the STOMP connection.
     
     This will terminate the socket connection and reset all completions.
     */
    func disconnect()

}
