//
//  StompClient.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation
import OSLog

public final class StompClient: NSObject, StompProtocol {
    public typealias ReceiveCompletionType = (Result<StompReceiveMessage, Error>) -> Void
    
    fileprivate struct ReceiveCompletion {
        var completion: ReceiveCompletionType
        var subscriptionID: String
    }
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "StompClient"
    )
    
    private var websocketClient: WebSocketClient
    private var url: URL
    /// key: topic
    /// value: receive completion
    private var receiveCompletions: [String: [ReceiveCompletion]] = [:]
    /// An ID used to subscribe to the topic. [Topic: ID]
    private var idByTopic: [String: String] = [:]
    private var isSocketConnect: Bool = false
    
    public init(url: URL) {
        self.url = url
        self.websocketClient = WebSocketClient(url: url)
        super.init()
    }
    
    public func sendAnyMessage(
        message: StompAnyMessage,
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        socketConnectIfNeeded(completion) // 커넥트 받는거 확인하고 send 해야하나?
        websocketClient.sendMessage(message.toFrame(), completion)
    }
    
    public func connect(
        acceptVersion accecptVersion: String = "1.2",
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        socketConnectIfNeeded(completion)
        websocketClient.receiveMessage() { [weak self] result in
            switch result {
            case .failure(let error):
                completion(error)
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.executeReceiveCompletions(text)
                case .data(let data):
                    #warning("Not implemented yet")
                    self?.logger.info("Received data: \(data)")
                @unknown default:
                    fatalError()
                }
            }
        }
        
        guard let host = url.host
        else { completion(StompError.invalidURLHost); return }
        
        let connectMessage = StompConnectMessage(host: host)
        websocketClient.sendMessage(connectMessage.toFrame(), completion)
    }
    
    public func send(
        topic: String,
        body: StompBody?,
        completion: @escaping ((any Error)?) -> Void
    ) {
        let sendMessage = StompSendMessage(destination: topic, body: body)
        performSend(message: sendMessage, completion)
    }
    
    public func send(
        headers: [String: String],
        body: StompBody?,
        completion: @escaping ((any Error)?) -> Void
    ) {
        guard let topic = headers["destination"] else {
            completion(StompError.invalidHeader("Missing 'destination' header"))
            return
        }
        
        let sendMessage = StompSendMessage(
            headers: headers,
            body: body
        )
        
        performSend(message: sendMessage, completion)
    }
    
    
    private func performSend(
        message: StompSendMessage,
        _ completion: @escaping ((any Error)?) -> Void
    ){
        websocketClient.sendMessage(message.toFrame(), completion)
    }
    
    public func subscribe(
        headers inputHeaders: [String: String],
        _ receiveCompletion: @escaping ReceiveCompletionType
    ) {
        guard let topic = inputHeaders["destination"]
        else { logger.error("Missing 'destination' header"); return }
        
        var headers = inputHeaders
        let subscriptionID: String = {
            if let id = headers["id"] {
                return id
            } else {
                return UUID().uuidString
            }
        }()
        headers["id"] = subscriptionID
        
        let subscribeMessage = StompSubscribeMessage(
            headers: headers
        )
        
        performSubscribe(
            id: subscriptionID,
            topic: topic,
            message: subscribeMessage, 
            receiveCompletion
        )
    }
    
    public func subscribe(
        topic: String,
        id: String? = nil,
        _ receiveCompletion: @escaping ReceiveCompletionType
    ) {
        let subscriptionID: String = {
            if let id = id {
                return id
            } else {
                return UUID().uuidString
            }
        }()
        
        let subscribeMessage = StompSubscribeMessage(
            id: subscriptionID,
            destination: topic
        )
        
        performSubscribe(
            id: subscriptionID,
            topic: topic,
            message: subscribeMessage, 
            receiveCompletion
        )
    }
    
    
    private func performSubscribe(
        id: String,
        topic: String,
        message: StompSubscribeMessage,
        _ receiveCompletion: @escaping ReceiveCompletionType
    ) {
        websocketClient.sendMessage(message.toFrame(), { _ in })
        
        let newCompletion = ReceiveCompletion(
            completion: receiveCompletion,
            subscriptionID: id
        )
        
        if let _ = receiveCompletions[topic] {
            receiveCompletions[topic]?.append(newCompletion)
        } else {
            receiveCompletions[topic] = [newCompletion]
        }
    }
    
    public func unsubscribe(
        topic: String,
        completion: @escaping ((any Error)?) -> Void
    ) {
        if let id = idByTopic[topic] {
            let unsubscribeMessage = StompUnsubscribeMessage(id: id)
            performUnsubscribe(message: unsubscribeMessage, topic: topic, completion: completion)
        } else {
            completion(StompError.invalidTopic)
        }
    }

    public func unsubscribe(
        headers: [String: String],
        completion: @escaping ((any Error)?) -> Void
    ) {
        guard let id = headers["id"] else {
            completion(StompError.invalidHeader("Missing 'id' header"))
            return
        }
        
        guard let topic = headers["destination"] else {
            completion(StompError.invalidHeader("Missing 'destination' header"))
            return
        }
        
        let unsubscribeMessage = StompUnsubscribeMessage(headers: headers)
        performUnsubscribe(message: unsubscribeMessage, topic: topic, completion: completion)
    }

    private func performUnsubscribe(
        message: StompUnsubscribeMessage,
        topic: String,
        completion: @escaping ((any Error)?) -> Void
    ) {
        websocketClient.sendMessage(message.toFrame(), completion)
        receiveCompletions.removeValue(forKey: topic)
        idByTopic.removeValue(forKey: topic)
    }
    
    public func disconnect() {
        websocketClient.disconnect()
        receiveCompletions.removeAll()
    }
}
    
private extension StompClient {
    private func socketConnectIfNeeded(
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        if !isSocketConnect {
            websocketClient.connect() { [weak self] error in
                if let error = error {
                    completion(error)
                } else {
                    self?.isSocketConnect = true
                }
            }
        }
    }
    
    private func executeReceiveCompletions(
        _ text: String
    ) {
        let topic = self.parseTopic(text)
        
        if let topic = topic {
            let executeReceiveCompletions = self.receiveCompletions
                .filter { key, value in
                    key == topic
                }
            executeReceiveCompletions.forEach { _, receiveCompletions in
                let response = self.toResponseMessage(text)
                switch response {
                case .failure(let error):
                    receiveCompletions.forEach {
                        $0.completion(.failure(error))
                    }
                case .success(let responseMessage):
                    receiveCompletions.forEach {
                        $0.completion(.success(responseMessage))
                    }
                }
            }
        }
    }
    
    private func toResponseMessage(
        _ frame: String
    ) -> Result<StompReceiveMessage, StompError> {
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false)
        
        guard let commandString = lines.first,
              let command = StompResponseCommand(rawValue: String(commandString)) else {
            return .failure(.invalidCommand)
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
        
        return .success(stompResponse)
    }
    
    private func parseTopic(_ frame: String) -> String? {
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false)
        
        var headers: [String: String] = [:]
        
        let splitIndex = lines.firstIndex(where: { $0.isEmpty }) ?? lines.endIndex
        let headerLines = lines.prefix(upTo: splitIndex)
        
        headerLines.forEach { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers[String(parts[0])] = String(parts[1])
            }
        }
        
        return headers["destination"]
    }
}

public extension StompClient {
    func enableLogging() {
        self.websocketClient.enableLogging()
    }
}
