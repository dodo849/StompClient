//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

public enum RquestBodyType {
    
    /// A request with no additional data.
    case requestPlain
    
    /// A requests body set with data.
    case requestData(Data)
    
    /// A request body set with `Encodable` type
    case requestJSONEncodable(Encodable)
    
    /// A request body set with `Encodable` type and custom encoder
    case requestCustomJSONEncodable(Encodable, encoder: JSONEncoder)
    
    /// A requests body set with encoded parameters.
    case requestParameters([String: Any], encoding: ParameterEncoding)
}

extension RquestBodyType {
    func toStompBody() -> StompBody {
        switch self {
        case .requestPlain:
            return .string("")
        case .requestData(let data):
            return .data(data)
        case .requestJSONEncodable(let encodable):
            return .json(encodable)
        case .requestCustomJSONEncodable(let encodable, let encoder):
            return .json(encodable, encoder: encoder)
        case .requestParameters(let parameters, let encoder):
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
