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
        case .connectFailed(_):
            return "" // TODO:
        case .decodeFailed(_):
            return "" // TODO:
        case .responseTypeMismatch(_):
            return "" // TODO:
        case .receiveErrorFrame(_):
            return "" // TODO:
        }
    }
}
