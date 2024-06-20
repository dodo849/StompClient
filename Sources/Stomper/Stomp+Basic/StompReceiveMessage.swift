//
//  StompResponseMessage.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

public enum StompReceiveCommand: String {
    case connected = "CONNECTED"
    case message = "MESSAGE"
    case receipt = "RECEIPT"
    case error = "ERROR"
}

public struct StompReceiveMessage {
    let command: StompReceiveCommand
    let headers: [String: String]
    let body: Data?
}

extension StompReceiveMessage {
    public func decode(
        using encoding: String.Encoding = .utf8
    ) -> String? {
        guard let data = body else {
            return nil
        }
        
        return String(data: data, encoding: encoding)
    }
    
    public func decode<D: Decodable>(
        _ type: D.Type,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> D? {
        guard let data = body else {
            return nil
        }
        
        let decodedBody = try decoder.decode(D.self, from: data)
        return decodedBody
    }
    
    static func convertFromFrame(
        _ frame: String
    ) throws -> StompReceiveMessage {
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false)
        
        guard let commandString = lines.first,
              let command = StompReceiveCommand(rawValue: String(commandString)) else {
            throw StompError.invalidCommand("\(lines.first ?? "") is invalid command")
        }
        
        let splitIndex = lines.firstIndex(where: { $0.isEmpty }) ?? lines.endIndex
        let headerLines = lines.prefix(upTo: splitIndex)
        let bodyLines = lines.suffix(from: splitIndex).dropFirst()
        
        let headers = headerLines.reduce(into: [String: String]()) { result, line in
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                result[String(parts[0])] = String(parts[1])
            }
        }
        
        let body = bodyLines
            .map { $0.replacingOccurrences(of: "\0", with: "") }
            .joined(separator: "")
        
        let stompBody: Data? = body.data(using: .utf8)
        
        let stompResponse = StompReceiveMessage(
            command: command,
            headers: headers,
            body: stompBody
        )
        
        return stompResponse
    }
    
}
