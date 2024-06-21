//
//  StompError.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

public enum StompError: LocalizedError {
    case invalidCommand(String?)
}
