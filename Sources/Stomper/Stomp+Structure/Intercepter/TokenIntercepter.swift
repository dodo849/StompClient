//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public struct TokenIntercepter: Intercepter {
    let token: String
    
    public func intercept<E: EntryType>(_ entry: E) -> E {
        var newEntry = entry
        newEntry.addHeader(["Authorization": "Bearer \(token)"])
        return newEntry
    }
}
