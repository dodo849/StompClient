//
//  Endpoint.swift
//
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

public protocol EntryType {

    static var baseURL: URL { get }
    
    var path: String? { get }
    
    var command: StompCommand { get }

    var body: RequestBodyType { get }
}

extension EntryType {
    var destinationHeader: [String: String] {
        if let path = path {
            return ["destination": path]
        } else {
            return [:]
        }
    }
}
