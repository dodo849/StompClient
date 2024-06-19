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
    
    public func execute<E: EntryType>(
        _ entry: E,
        completion: @escaping (E) -> Void
    ) {
        let tokenHeader = ["Authorization": "Bearer \(token)"]
        entry.headers.addHeaders(tokenHeader)
        completion(entry)
    }
}
