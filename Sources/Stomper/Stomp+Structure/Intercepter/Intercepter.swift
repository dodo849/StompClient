//
//  Intercepter.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public protocol Intercepter {
    func execute<E: EntryType>(
        _ entry: E,
        completion: @escaping (E) -> Void
    )
    
//    func retry<E: EntryType>(
//        _ entry: E,
//        dueTo error: Error,
//        completion: @escaping (EntryRetry) -> Void
//    )
}

public enum EntryRetry {
    case retry(count: Int, interval: TimeInterval)
    case none
}
