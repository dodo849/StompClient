//
//  EntryType.swift
//
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

/** Specification for STOMP communication
  
  This protocol defines the requirements for entries used in STOMP (Simple Text Oriented Messaging Protocol) communication. Implementing this protocol allows for the intuitive definition of different types of requests for STOMP connection.
 
 ### Example
 
 ```swift
 enum ChatEntry {
     case connect
     case subscribeChat
     case sendChat(ChatMessage)
     case disconnect
 }

 extension ChatEntry: EntryType {
     static var baseURL: URL {
         URL(string: "wws://localhost:8080")!
     }
     
     var topic: String? {
         switch self {
         case .subscribeChat:
             return "/sub/chat"
         case .sendMessage:
             return "/pub/chat"
         default:
             return nil
         }
     }
     
     var command: EntryCommand {
         switch self {
         case .connect:
             return .connect()
         case .subscribeChat:
             return .subscribe()
         case .sendMessage:
             return .send()
         case .disconnect:
             return .disconnect()
         }
     }
     
     var body: EntryRequestBodyType {
         switch self {
         case .sendMessage(let message):
             return .withJSON(message)
         default:
             return .none
         }
     }
     
     var additionalHeaders: [String : String] {
         return [:]
     }
 }
 ```

 */
public protocol EntryType {
    /// WebSocket server URL (ws or wss)
    static var baseURL: URL { get }
    
    ///The path of the target to which you want to subscribe or publish the message, corresponding to the `destination` header of the STOMP.
    var topic: String? { get }
    
    /// STOMP command and native headers
    var command: EntryCommand { get }
    
    /// Request body, which can be JSON, String, or Data
    var body: EntryRequestBodyType { get }
    
    /// Additional headers beyond those specified by STOMP
    ///
    /// Note - The required and native headers are specified the `StompCommand` enum.
    var additionalHeaders: [String: String] { get }
}

extension EntryType {
    /// Convert the
    var destinationHeader: [String: String] {
        if let topic = topic {
            return ["destination": topic]
        } else {
            return [:]
        }
    }
}
