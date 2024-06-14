//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

extension StompCommand {
    var name: String {
        switch self {
        case .connect: "CONNECT"
        case .connected: "CONNECTED"
        case .send: "SEND"
        case .subscribe: "SUBSCRIBE"
        case .unsubscribe: "UNSUBSCRIBE"
        case .ack: "ACK"
        case .nack: "NACK"
        case .begin: "BEGIN"
        case .commit: "COMMIT"
        case .abort: "ABORT"
        case .disconnect: "DISCONNECT"
        case .message: "MESSAGE"
        case .receipt: "RECEIPT"
        case .error: "ERROR"
        }
    }
}
