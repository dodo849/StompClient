//
//  StompMessage.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

enum StompRequestCommand: String {
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

public enum StompBody {
    case data(Data)
    case string(String)
    case json(Encodable)
    
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

protocol StompRequestMessage {
    var command: StompRequestCommand { get }
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
            case .json(let json):
                let encoder = JSONEncoder()
                if let jsonData = try? encoder.encode(json) {
                    frame += String(data: jsonData, encoding: .utf8) ?? ""
                }
            }
        }
        
        frame += "\u{00}"
        return frame
    }
}

struct StompAnyMessage: StompRequestMessage {
    let command: StompRequestCommand
    let headers: [String: String]
    var body: StompBody? = nil
    
    init(
        command: StompRequestCommand,
        headers: [String: String],
        body: StompBody?
    ) {
        self.command = command
        self.headers = headers
        self.body = body
    }
}

struct StompConnectMessage: StompRequestMessage {
    let command: StompRequestCommand = .connect
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
    let command: StompRequestCommand = .subscribe
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
    let command: StompRequestCommand = .send
    let headers: [String: String]
    let body: StompBody?
    
    init(
        destination: String,
        body: StompBody
    ) {
        self.headers = [
            "destination": destination
        ]
        self.body = body
    }
    
    init(headers: [String: String]) {
        self.headers = headers
        self.body = nil
    }
}

struct StompDisconnectMessage: StompRequestMessage {
    let command: StompRequestCommand = .disconnect
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


// 🔽 not supported yet
struct StompNackMessage: StompRequestMessage {
    let command: StompRequestCommand = .nack
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
    let command: StompRequestCommand = .unsubscribe
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
    let command: StompRequestCommand = .begin
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
    let command: StompRequestCommand = .commit
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
    let command: StompRequestCommand = .abort
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
