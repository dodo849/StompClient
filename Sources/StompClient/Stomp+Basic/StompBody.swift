//
//  StompBody.swift
//
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

public enum StompBody {
    case data(Data)
    case string(String)
    case json(Encodable, encoder: JSONEncoder? = nil)
    
    var contentType: String {
        switch(self) {
        case .data:
            return "application/octet-stream"
        case .string:
            return "text/plain"
        case .json:
            return "application/json"
        }
    }
}
