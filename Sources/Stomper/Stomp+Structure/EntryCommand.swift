//
//  StompCommand.swift
//
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

/**
 A collection of STOMP commands that include the mandatory headers  for each command.
 This follows the STOMP protocol version 1.2.
 For more details, refer to the specification at: https://stomp.github.io/stomp-specification-1.2.html
 */
public enum EntryCommand {
    /// If `acceptVersion` is nil, they will be filled automatically.
    case connect(
        acceptVersion: String? = "1.2",
        host: String,
        login: String? = nil,
        passcode: String? = nil,
        heartBeat: String? = nil
    )
    
    /// - Note: This is a server-side frame. It is not recommended for the client to directly send this command to the server
    case connected(
        version: String,
        session: String? = nil,
        server: String? = nil,
        heartBeat: String? = nil
    )
    
    /// If `contentType`,`contentLength` or `receipt`  is nil, they will be filled automatically.
    case send(
        transaction: String? = nil,
        contentType: String? = nil,
        contentLength: Int? = nil,
        receipt: String? = nil
    )
    
    case subscribe(
        id: String? = nil,
        ack: String? = nil
    )
    
    case unsubscribe(
        id: String
    )
    
    case ack(
        id: String,
        transaction: String? = nil
    )
    
    case nack(
        id: String,
        transaction: String? = nil
    )
    
    case begin(
        transaction: String
    )
    
    case commit(
        transaction: String
    )
    
    case abort(
        transaction: String
    )
    
    case disconnect(
        receipt: String? = nil
    )
    
    /// - Note: This is a server-side frame. It is not recommended for the client to directly send this command to the server
    case message(
        messageId: String,
        subscription: String,
        ack: String? = nil,
        contentType: String? = nil,
        contentLength: Int? = nil
    )

    /// - Note: This is a server-side frame. It is not recommended for the client to directly send this command to the server
    case receipt(
        receiptId: String
    )

    /// - Note: This is a server-side frame. It is not recommended for the client to directly send this command to the server
    case error(
        message: String? = nil,
        receiptId: String? = nil,
        contentType: String? = nil,
        contentLength: Int? = nil
    )
}
