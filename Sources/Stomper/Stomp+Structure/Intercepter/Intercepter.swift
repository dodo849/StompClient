//
//  Intercepter.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

public protocol Intercepter {
    func intercept<E: EntryType>(_ entry: E) -> E
}
