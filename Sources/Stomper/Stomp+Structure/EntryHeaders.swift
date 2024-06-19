//
//  StompEntryHeaders.swift
//  
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

/// A headers used in EntryType.
public class EntryHeaders {
    var dict: [String: String]
    
    /// Initializes the EntryHeaders object with the provided headers dictionary.
    ///
    /// - Parameter headers: Initial headers dictionary.
    public init(_ headers: [String : String]) {
        self.dict = headers
    }
    
    /// Adds additional headers to the existing headers dictionary.
    ///
    /// - Warning: If a header with the same key already exists, it will be overwritten.
    ///
    /// - Parameter additionalHeaders: Additional headers to add.
    public func addHeaders(_ additionalHeaders: [String: String]) {
        for (key, value) in additionalHeaders {
            dict[key] = value
        }
    }
    
    /// Adds a single header to the existing headers dictionary.
    ///
    /// - Warning: If a header with the same key already exists, it will be overwritten.
    ///
    /// - Parameters:
    ///   - key: The key of the header to add.
    ///   - value: The value of the header to add.
    public func addHeader(key: String, value: String) {
        dict[key] = value
    }
}

extension EntryHeaders {
    /// Provides an empty `EntryHeaders` instance.
    ///
    /// Use this static property when no additional headers need to be specified.
    public static var empty: EntryHeaders {
        return EntryHeaders([:])
    }
}
