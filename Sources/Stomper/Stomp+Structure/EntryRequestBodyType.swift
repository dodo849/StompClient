//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

public enum EntryRequestBodyType {
    
    /// A request with no additional data.
    case none
    
    /// A requests body set with string.
    case withPlain(String)
    
    /// A requests body set with data.
    case withData(Data)
    
    /// A request body set with `Encodable` type
    case withJSON(Encodable)
    
    /// A request body set with `Encodable` type and custom encoder
    case withCustomJSONE(Encodable, encoder: JSONEncoder)
    
    /// A requests body set with encoded parameters.
    case withParameters([String: Any], encoding: ParameterEncoding)
}

extension EntryRequestBodyType {
    func toStompBody() -> StompBody {
        switch self {
        case .none:
            return .string("")
        case .withPlain(let string):
            return .string(string)
        case .withData(let data):
            return .data(data)
        case .withJSON(let encodable):
            return .json(encodable)
        case .withCustomJSONE(let encodable, let encoder):
            return .json(encodable, encoder: encoder)
        case .withParameters(let parameters, let encoder):
            if let jsonData = try? encoder.encode(with: parameters) {
                return .data(jsonData)
            } else {
                print("Error encoding parameters: \(parameters)")
                return .string("")
            }
        }
    }
}

public protocol ParameterEncoding {
    func encode(with parameters: [String: Any]) throws -> Data
}
