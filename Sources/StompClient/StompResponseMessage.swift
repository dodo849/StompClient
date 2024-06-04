//
//  StompResponseMessage.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

public enum StompResponseCommand: String {
    case message = "MESSAGE"
    case receipt = "RECEIPT"
    case error = "ERROR"
}

public struct StompReceiveMessage {
    let command: StompResponseCommand
    let headers: [String: String]
    let body: Data?
}

extension StompReceiveMessage {
    func decode(
        using encoding: String.Encoding = .utf8
    ) -> String? {
        guard let data = body else {
            return nil
        }
        
        return String(data: data, encoding: encoding)
    }
    
    func decode<D: Decodable>(
        _ type: D.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> D? {
        guard let data = body else {
            return nil
        }
        
        let decodedBody = try decoder.decode(D.self, from: data)
        return decodedBody
    }
}
