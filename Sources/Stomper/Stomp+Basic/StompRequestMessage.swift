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


//public protocol StompRequestMessage {
//    var command: StompRequestCommand { get }
//    var headers: StompHeaders { get }
//    var body: StompBody? { get }
//    
//    func toFrame() -> String
//}

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
//struct StompConnectMessage: StompRequestMessage {
//    let command: StompRequestCommand = .connect
//    let headers: StompHeaders
//    var body: StompBody? = nil
//    
//    init(
//        accecptVersion: String = "1.2",
//        host: String
//    ) {
//        let headers = [
//            "accept-version": accecptVersion,
//            "host": host
//        ]
//        self.headers = StompHeaders(headers)
//    }
//    
//    init(headers: [String: String]) {
//        self.headers = StompHeaders(headers)
//    }
//}
//
//struct StompSubscribeMessage: StompRequestMessage {
//    let command: StompRequestCommand = .subscribe
//    let headers: StompHeaders
//    let body: StompBody? = nil
//    
//    init(
//        id: String,
//        destination: String
//    ) {
//        let headers = [
//            "id" : id,
//            "destination": destination
//        ]
//        self.headers = StompHeaders(headers)
//    }
//    
//    init(headers: [String: String]) {
//        self.headers = StompHeaders(headers)
//    }
//}
//
//struct StompSendMessage: StompRequestMessage {
//    let command: StompRequestCommand = .send
//    let headers: StompHeaders
//    let body: StompBody?
//    
//    init(
//        destination: String,
//        body: StompBody?
//    ) {
//        let headers = {
//            if let body = body {
//                return [
//                    "destination": destination,
//                    "content-type": body.contentType,
//                    "content-length": "\(body.contentLength)"
//                ]
//            } else {
//                return ["destination": destination]
//            }
//        }()
//        self.headers = StompHeaders(headers)
//        self.body = body
//    }
//    
//    init(
//        headers: [String: String],
//        body: StompBody? = nil
//    ) {
//        self.headers = StompHeaders(headers)
//        self.body = body
//    }
//}
//
//struct StompDisconnectMessage: StompRequestMessage {
//    let command: StompRequestCommand = .disconnect
//    let headers: StompHeaders
//    let body: StompBody? = nil
//    
//    init(receipt: String? = nil) {
//        if let receipt = receipt {
//            self.headers = StompHeaders(["receipt": receipt])
//        } else {
//            self.headers = StompHeaders([:])
//        }
//    }
//    
//    init(headers: [String: String]) {
//        self.headers = StompHeaders(headers)
//    }
//}
//
//
//// 🔽 Not used yet
//struct StompNackMessage: StompRequestMessage {
//    let command: StompRequestCommand = .nack
//    let headers: StompHeaders
//    let body: StompBody? = nil
//    
//    init(id: String, transaction: String? = nil) {
//        var headers = ["id": id]
//        if let transaction = transaction {
//            headers["transaction"] = transaction
//        }
//        self.headers = StompHeaders(headers)
//    }
//    
//    init(headers: [String: String]) {
//        self.headers = StompHeaders(headers)
//    }
//}
//
//struct StompUnsubscribeMessage: StompRequestMessage {
//    let command: StompRequestCommand = .unsubscribe
//    let headers: StompHeaders
//    let body: StompBody? = nil
//    
//    init(id: String) {
//        let headers = [
//            "id": id
//        ]
//        self.headers = StompHeaders(headers)
//    }
//    
//    init(headers: [String: String]) {
//        self.headers = StompHeaders(headers)
//    }
//}
//
//struct StompBeginMessage: StompRequestMessage {
//    let command: StompRequestCommand = .begin
//    let headers: StompHeaders
//    let body: StompBody? = nil
//    
//    init(transaction: String) {
//        let headers = [
//            "transaction": transaction
//        ]
//        self.headers = StompHeaders(headers)
//    }
//    
//    init(headers: [String: String]) {
//        self.headers = StompHeaders(headers)
//    }
//}
//
//struct StompCommitMessage: StompRequestMessage {
//    let command: StompRequestCommand = .commit
//    let headers: StompHeaders
//    let body: StompBody? = nil
//    
//    init(transaction: String) {
//        let headers = [
//            "transaction": transaction
//        ]
//        self.headers = StompHeaders(headers)
//    }
//    
//    init(headers: [String: String]) {
//        self.headers = StompHeaders(headers)
//    }
//}
//
//struct StompAbortMessage: StompRequestMessage {
//    let command: StompRequestCommand = .abort
//    let headers: StompHeaders
//    let body: StompBody? = nil
//    
//    init(transaction: String) {
//        let headers = [
//            "transaction": transaction
//        ]
//        self.headers = StompHeaders(headers)
//    }
//    
//    init(headers: [String: String]) {
//        self.headers = StompHeaders(headers)
//    }
//}
