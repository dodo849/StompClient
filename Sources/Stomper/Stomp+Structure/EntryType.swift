//
//  Endpoint.swift
//
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

/// Specification for STOMP communication
public protocol EntryType {
    /// WebSocket server URL (ws or wss)
    static var baseURL: URL { get }
    
    /// Path to send the request to, such as a topic or destination
    var path: String? { get }
    
    /// STOMP command
    var command: EntryCommand { get }
    
    /// Request body, which can be JSON, String, or Data
    var body: EntryRequestBodyType { get }
    
    /// Additional headers beyond those specified by STOMP
    var headers: EntryHeaders? { get }
}

extension EntryType {
    var destinationHeader: [String: String] {
        if let path = path {
            return ["destination": path]
        } else {
            return [:]
        }
    }
}
