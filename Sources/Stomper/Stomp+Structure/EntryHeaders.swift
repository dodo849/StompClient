//
//  StompEntryHeaders.swift
//  
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public class EntryHeaders {
    var dict: [String: String]
    
    public init(_ headers: [String : String]) {
        self.dict = headers
    }
    
    func addHeaders(_ additionalHeaders: [String: String]) {
        for (key, value) in additionalHeaders {
            dict[key] = value
        }
    }
}
