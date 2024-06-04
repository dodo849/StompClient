//
//  StompError.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

public enum StompError: Error {
    case invalidCommand
    case invalidHeader
    case invalidBody
    case invalidURLHost
    case decodingError
}
