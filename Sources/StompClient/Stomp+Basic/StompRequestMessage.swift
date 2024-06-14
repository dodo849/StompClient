//
//  StompMessage.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

public enum StompCommandType: String {
    case connect = "CONNECT"
    case connected = "CONNECTED"
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


protocol StompRequestMessage {
    var command: StompCommandType { get }
    var headers: [String: String] { get }
    var body: StompBody? { get }
    
    func toFrame() -> String
}

extension StompRequestMessage {
    public func toFrame() -> String {
        var frame = "\(command.rawValue)\n"
        
        var updatedHeaders = headers
        
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

public struct StompAnyMessage: StompRequestMessage {
    let command: StompCommandType
    let headers: [String: String]
    var body: StompBody? = nil
    
    init(
        command: StompCommandType,
        headers: [String: String],
        body: StompBody?
    ) {
        self.command = command
        self.headers = headers
        self.body = body
    }
}

struct StompConnectMessage: StompRequestMessage {
    let command: StompCommandType = .connect
    let headers: [String: String]
    var body: StompBody? = nil
    
    init(
        accecptVersion: String = "1.2",
        host: String
    ) {
        self.headers = [
            "accept-version": accecptVersion,
            "host": host
        ]
    }
    
    init(headers: [String: String]) {
        self.headers = headers
    }
}

struct StompSubscribeMessage: StompRequestMessage {
    let command: StompCommandType = .subscribe
    let headers: [String: String]
    let body: StompBody? = nil
    
    init(
        id: String,
        destination: String
    ) {
        self.headers = [
            "id" : id,
            "destination": destination
        ]
    }
    
    init(headers: [String: String]) {
        self.headers = headers
    }
}

struct StompSendMessage: StompRequestMessage {
    let command: StompCommandType = .send
    let headers: [String: String]
    let body: StompBody?
    
    init(
        destination: String,
        body: StompBody?
    ) {
        self.headers = {
            if let body = body {
                return [
                    "destination": destination,
                    "content-type": body.contentType,
                    "content-length": "\(body.contentLength)"
                ]
            } else {
                return ["destination": destination]
            }
        }()
        self.body = body
    }
    
    init(
        headers: [String: String],
        body: StompBody? = nil
    ) {
        self.headers = headers
        self.body = body
    }
}

struct StompDisconnectMessage: StompRequestMessage {
    let command: StompCommandType = .disconnect
    let headers: [String: String]
    let body: StompBody? = nil
    
    init(receipt: String? = nil) {
        if let receipt = receipt {
            self.headers = ["receipt": receipt]
        } else {
            self.headers = [:]
        }
    }
    
    init(headers: [String: String]) {
        self.headers = headers
    }
}


// 🔽 Not used yet
struct StompNackMessage: StompRequestMessage {
    let command: StompCommandType = .nack
    let headers: [String: String]
    let body: StompBody? = nil
    
    init(id: String, transaction: String? = nil) {
        var headers = ["id": id]
        if let transaction = transaction {
            headers["transaction"] = transaction
        }
        self.headers = headers
    }
    
    init(headers: [String: String]) {
        self.headers = headers
    }
}

struct StompUnsubscribeMessage: StompRequestMessage {
    let command: StompCommandType = .unsubscribe
    let headers: [String: String]
    let body: StompBody? = nil
    
    init(id: String) {
        self.headers = [
            "id": id
        ]
    }
    
    init(headers: [String: String]) {
        self.headers = headers
    }
}

struct StompBeginMessage: StompRequestMessage {
    let command: StompCommandType = .begin
    let headers: [String: String]
    let body: StompBody? = nil
    
    init(transaction: String) {
        self.headers = [
            "transaction": transaction
        ]
    }
    
    init(headers: [String: String]) {
        self.headers = headers
    }
}

struct StompCommitMessage: StompRequestMessage {
    let command: StompCommandType = .commit
    let headers: [String: String]
    let body: StompBody? = nil
    
    init(transaction: String) {
        self.headers = [
            "transaction": transaction
        ]
    }
    
    init(headers: [String: String]) {
        self.headers = headers
    }
}

struct StompAbortMessage: StompRequestMessage {
    let command: StompCommandType = .abort
    let headers: [String: String]
    let body: StompBody? = nil
    
    init(transaction: String) {
        self.headers = [
            "transaction": transaction
        ]
    }
    
    init(headers: [String: String]) {
        self.headers = headers
    }
}
