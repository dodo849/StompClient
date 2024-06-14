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
    
    var contentLength: Int {
        switch self {
        case .data(let data):
            return data.count
        case .string(let string):
            return string.utf8.count
        case .json(let encodable, let encoder):
            let encoderToUse = encoder ?? JSONEncoder()
            do {
                let jsonData = try encoderToUse.encode(encodable)
                return jsonData.count
            } catch {
                return 0
            }
        }
    }
}
