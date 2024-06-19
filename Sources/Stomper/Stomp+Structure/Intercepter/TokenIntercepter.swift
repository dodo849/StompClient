//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public struct TokenIntercepter: Intercepter {
    let token: String
    
    public init(token: String) {
        self.token = token
    }
    
    public func intercept<E: EntryType>(_ entry: E) -> E {
        let tokenHeader = ["Authorization": "Bearer \(token)"]
        entry.headers.addHeaders(tokenHeader)
        return entry
    }
}
