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
    var command: StompCommand { get }
    
    /// Request body, which can be JSON, String, or Data
    var body: RequestBodyType { get }
    
    /// Additional headers beyond those specified by STOMP
    var headers: [String: String] { get set }
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

extension EntryType {
    /// Mutating function for Interceptor to add headers
    mutating func addHeader(_ additionalHeader: [String: String]) {
        for (key, value) in additionalHeader {
            headers[key] = value
        }
    }
}
