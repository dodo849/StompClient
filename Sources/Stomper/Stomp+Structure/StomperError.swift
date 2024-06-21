//
//  StomperError.swift
//
//
//  Created by DOYEON LEE on 6/20/24.
//

import Foundation

public enum StomperError: LocalizedError {
    case clientNotInitialized
    case connectFailed(StompReceiveMessage)
    case decodeFailed(String?)
    case responseTypeMismatch(String?)
    case receiveErrorFrame(StompReceiveMessage)
    
    public var helpAnchor: String? {
        switch self {
        case .clientNotInitialized:
            return """
                    The socket client has not been initialized correctly.
                    Please create a new instance of the provider.
                    """
        case .connectFailed(let message):
            return """
                    The connection attempt failed with the following message: \(message).
                    Please check the server status and your connection parameters.
                    """
        case .decodeFailed(let details):
            return """
                    Failed to decode the received message: \(details ?? "No details available").
                    Please check the message format and ensure it conforms to the expected structure.
                    """
        case .responseTypeMismatch(let details):
            return """
                    The response type does not match the expected type: \(details ?? "No details available").
                    Please ensure the correct response type is being used.
                    """
        case .receiveErrorFrame(let message):
            return """
                    An error frame was received: \(message).
                    """
        }
    }
}
