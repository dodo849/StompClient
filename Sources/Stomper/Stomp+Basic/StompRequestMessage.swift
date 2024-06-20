//
//  StompMessage.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

public enum StompRequestCommand: String {
    case connect = "CONNECT"
    case subscribe = "SUBSCRIBE"
    case send = "SEND"
    case disconnect = "DISCONNECT"
    case unsubscribe = "UNSUBSCRIBE"
    case ack = "ACK"
    case nack = "NACK"
    case begin = "BEGIN"
    case commit = "COMMIT"
    case abort = "ABORT"
}


public struct StompRequestMessage {
    public let command: StompRequestCommand
    public let headers: StompHeaders
    public var body: StompBody? = nil
    
    init(
        command: StompRequestCommand,
        headers: [String: String],
        body: StompBody? = nil
    ) {
        self.command = command
        self.headers = StompHeaders(headers)
        self.body = body
    }
}

extension StompRequestMessage {
    public func toFrame() -> String {
        var frame = "\(command.rawValue)\n"
        
        var updatedHeaders = headers.dict
        
        if let body = body {
            updatedHeaders["content-type"] = body.contentType
        }
        
        for (key, value) in updatedHeaders {
            frame += "\(key):\(value)\n"
        }
        
        frame += "\n"
        
        if let body = body {
            switch body {
            case .data(let data):
                frame += String(data: data, encoding: .utf8) ?? ""
            case .string(let string):
                frame += string
            case .json(let json, let encoder):
                let jsonEncoder = encoder ?? JSONEncoder()
                if let jsonData = try? jsonEncoder.encode(json) {
                    frame += String(data: jsonData, encoding: .utf8) ?? ""
                }
            }
        }
        
        frame += "\u{00}"
        return frame
    }
}
