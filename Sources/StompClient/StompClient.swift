//
//  StompClient.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation

public final class StompClient: NSObject, URLSessionDelegate, StompProtocol {
    fileprivate struct ReceiveCompletion {
        var completion: (Result<StompReceiveMessage, Error>) -> Void
        var subscriptionID: String
    }
    
    private var websocketClient: WebSocketClient
    private var url: URL
    /// key: topic
    /// value: receive completion
    private var receiveCompletions: [String: [ReceiveCompletion]] = [:]
    private var idByTopic: [String: String] = [:]
    
    public init(url: URL) {
        self.url = url
        self.websocketClient = WebSocketClient(url: url)
        super.init()
    }
    
    public func connect(
        acceptVersion accecptVersion: String = "1.2",
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        websocketClient.connect(completion)
        websocketClient.receiveMessage() { [weak self] result in
            switch result {
            case .failure(let error):
                completion(error)
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.executeReceiveCompletions(text)
                case .data(let data):
                    print("Received data: \(data)")
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
    
    public func send(
        topic: String,
        body: StompBody,
        completion: @escaping ((any Error)?) -> Void
    ) {
        let sendMessage = StompSendMessage(destination: topic, body: body)
        websocketClient.sendMessage(sendMessage.toFrame(), completion)
    }
    
    public func subscribe(
        topic: String,
        id: String? = nil,
        _ receiveCompletion: @escaping (Result<StompReceiveMessage, Error>) -> Void
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
        websocketClient.sendMessage(subscribeMessage.toFrame(), { _ in })
        
        let newCompletion = ReceiveCompletion(
            completion: receiveCompletion,
            subscriptionID: subscriptionID
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
            websocketClient.sendMessage(unsubscribeMessage.toFrame(), completion)
        }
        receiveCompletions.removeValue(forKey: topic)
    }
    
    public func disconnect(
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        websocketClient.disconnect() { error in
            completion(error)
        }
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
}
