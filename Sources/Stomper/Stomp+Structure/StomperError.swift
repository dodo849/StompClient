//
//  StomperError.swift
//
//
//  Created by DOYEON LEE on 6/20/24.
//

import Foundation

public enum StomperError: LocalizedError {
    case clientNotInitialized
    
    public var helpAnchor: String? {
        switch self {
        case .clientNotInitialized:
            return "The socket client has not been initialized correctly. Please create a new instance of the provider."
        }
    }
}
