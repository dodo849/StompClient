//
//  StompProviderProtocol.swift
//
//
//  Created by DOYEON LEE on 6/15/24.
//

import Foundation

public protocol StompProviderProtocol {
    associatedtype Entry: EntryType

    /**
     Sends a request using the specified entry and calls a completion handler when the request is complete.
     
     - Parameters:
        - entry: The entry containing request details.
        - completion: See details
     
     ### Completion Details
     The meaning of completion varies by command:
     - If the command is `connect`, completion indicates any error that occurs during receiving server frame.
     - If the command is `subscribe`, completion indicates receiving a MESSAGE frame from the server or an error.
     - If the command is `send`, completion indicates receiving a RECEIPT frame from the server or an error.
     - For other commands, completion indicates callbacks for the Receipt frame if there is a receipt-id header.
     */
    func request<Response>(
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
    func intercept(_ intercepters: [Intercepter]) -> Self
}
