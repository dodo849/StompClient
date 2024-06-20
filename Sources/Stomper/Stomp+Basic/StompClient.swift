//
//  StompClient.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation
import OSLog

public final class StompClient: NSObject, StompClientProtocol {
    public typealias ReceiveCompletionType = (Result<StompReceiveMessage, any Error>) -> Void
    public typealias ReceiptCompletionType = (Result<StompReceiveMessage, any Error>) -> Void
    
    /// A Completion for Stomp 'MESSAGE' command
    fileprivate struct ReceiveCompletion {
        var completion: ReceiveCompletionType
        var subscriptionID: String
    }
    
    /// A Completion for Stomp 'RECEIPT' command
    fileprivate struct ReceiptCompletion {
        var completion: ReceiptCompletionType
        var receiptID: String
    }
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "StompClient"
    )
    
    private var websocketClient: WebSocketClient
    private var url: URL
    /// Completions for Stomp 'MESSAGE' command
    /// key: topic
    /// value: receive completions
    private var receiveCompletions: [String: [ReceiveCompletion]] = [:]
    /// Completions for Stomp 'RECEIPT' command
    /// key: Id
    /// value: receipt completion
    private var receiptCompletions: [String: ReceiptCompletion] = [:]
    /// An ID used to subscribe to the topic. [Topic: ID]
    private var idByTopic: [String: String] = [:]
    private var isSocketConnect: Bool = false

    private var interceptor: Interceptor? = nil
    
    public init(url: URL) {
        self.url = url
        self.websocketClient = WebSocketClient(url: url)
        super.init()
    }
    
    /// - Warning: You must send a `CONNECT` frame before sending a`SEND` frame.
    public func sendAnyMessage(
        message: StompAnyMessage,
        _ completion: @escaping ReceiptCompletionType
    ) {
        if let interceptor = interceptor {
            interceptor.execute(message: message) { [weak self] interceptedMessage in
                self?.performSendAnyMessage(message: interceptedMessage, completion)
            }
        } else {
            performSendAnyMessage(message: message, completion)
        }
    }
    
    private func performSendAnyMessage(
        message: StompRequestMessage,
        isRetry: Bool = false,
        _ completion: @escaping ReceiptCompletionType
    ) {
        socketConnectIfNeeded() { _ in } // 커넥트 받는거 확인하고 send 해야하나?
        websocketClient.sendMessage(message.toFrame()) { _ in }
        
        if let receiptID = message.headers.dict["receipt"] {
            let receiptCompletion = ReceiptCompletion(
                completion: completion,
                receiptID: receiptID
            )
            receiptCompletions[receiptID] = receiptCompletion
        }
    }
    
    public func connect(
        headers: [String: String],
        body: StompBody?,
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        guard let host = url.host
        else { completion(StompError.invalidURLHost); return }
        
        let connectMessage = StompAnyMessage(
            command: .connect,
            headers: headers,
            body: body
        )
        
        if let interceptor = interceptor {
            interceptor.execute(message: connectMessage) { [weak self] interceptedMessage in
                self?.performConnect(message: interceptedMessage, completion)
            }
        } else {
            performConnect(message: connectMessage, completion)
        }
        
        
    }
    
    private func performConnect(
        message: StompRequestMessage,
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        socketConnectIfNeeded(completion)
        websocketClient.receiveMessage() { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                completion(error)
            case .success(let message):
                switch message {
                case .string(let text):
                    do {
                        try self.performCompletions(text)
                    } catch {
                        completion(error) // 이 실패 처리 고민. parse 실패가 connect error로 들어감. (?)
                    }
                case .data(let data):
                    if let decodedText = String(data: data, encoding: .utf8) {
                        do {
                            try self.performCompletions(decodedText)
                        } catch {
                            completion(error)
                        }
                    } else {
                        let decodingError = StompError.decodeFaild("Failed to decode data to string")
                        completion(decodingError)
                    }
                @unknown default:
                    fatalError()
                }
            }
        }
        
        websocketClient.sendMessage(message.toFrame(), completion)
    }
    
    func performCompletions(_ frameString: String) throws {
        do {
            let receiveMessage = try toReceiveMessage(frameString)
            self.executeReceiveCompletions(receiveMessage)
            self.executeReceiptCompletions(receiveMessage)
        } catch {
            throw error
        }
    }
    
    @available(*, deprecated, message: "Do not use the Stomp client directly; use the `StompProvider` instead")
    public func send(
        topic: String,
        body: StompBody?,
        receiptID: String? = nil,
        _ completion: @escaping ReceiveCompletionType
    ) {
        let sendMessage = StompSendMessage(destination: topic, body: body)
        performSend(message: sendMessage)
    }
    
    func send(
        headers: [String: String],
        body: StompBody?,
        _ completion: @escaping ReceiveCompletionType
    ) {
        guard let _ = headers["destination"] else {
            completion(.failure(StompError.invalidHeader("Missing 'destination' header")))
            return
        }
        
        if let receiptID = headers["receipt"] {
            let receiptCompletion = ReceiptCompletion(
                completion: completion,
                receiptID: receiptID
            )
            receiptCompletions[receiptID] = receiptCompletion
        }
        
        let sendMessage = StompSendMessage(
            headers: headers,
            body: body
        )
        
        performSend(message: sendMessage)
    }
    
    
    private func performSend(
        message: StompSendMessage
    ){
        websocketClient.sendMessage(message.toFrame()) { _ in }
    }
    
    @available(*, deprecated, message: "Do not use the Stomp client directly; use the `StompProvider` instead")
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
    
    func subscribe(
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
    
    @available(*, deprecated, message: "Do not use the Stomp client directly; use the `StompProvider` instead")
    public func unsubscribe(
        topic: String,
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        if let id = idByTopic[topic] {
            let unsubscribeMessage = StompUnsubscribeMessage(id: id)
            performUnsubscribe(message: unsubscribeMessage, topic: topic, completion: completion)
        } else {
            completion(StompError.invalidTopic)
        }
    }

    func unsubscribe(
        headers: [String: String],
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        guard let _ = headers["id"] else {
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
        _ message: StompReceiveMessage
    ) {
        if message.command != .message {
            return
        }
        
        if let topic = message.headers["destination"] {
            let executeReceiveCompletions = self.receiveCompletions
                .filter { key, value in
                    key == topic
                }
            executeReceiveCompletions.forEach { _, receiveCompletions in
                receiveCompletions.forEach {
                    $0.completion(.success(message))
                }
            }
        }
    }
    
    private func executeReceiptCompletions(
        _ message: StompReceiveMessage
    ) {
        if message.command != .receipt {
            return
        }
        
        if let receiptID = message.headers["receipt-id"] {
            if let receiptCompletion = self.receiptCompletions[receiptID]  {
                receiptCompletion.completion(.success(message))
            }
            
            receiptCompletions.removeValue(forKey: receiptID)
        }
    }
    
    private func toReceiveMessage(
        _ frame: String
    ) throws -> StompReceiveMessage {
        let lines = frame.split(separator: "\n", omittingEmptySubsequences: false)
        
        guard let commandString = lines.first,
              let command = StompResponseCommand(rawValue: String(commandString)) else {
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
    
    private func handleRetry(
        message: StompRequestMessage,
        error: Error,
        isRetried: Bool,
        completion: @escaping (Result<StompReceiveMessage, any Error>) -> Void
    ) {
        if isRetried {
            completion(.failure(error))
            return
        }

        guard let interceptor = interceptor else {
            completion(.failure(error))
            return
        }

        interceptor.retry(
            message: message,
            error: error
        ) { [weak self] retryMessage, retryType in
            guard let self = self else {
                completion(.failure(error))
                return
            }

            switch retryType {
            case .retry:
                self.performSendAnyMessage(
                    message: retryMessage,
                    isRetry: true,
                    completion
                )
                
            case .delayedRetry(let delay):
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performSendAnyMessage(
                        message: retryMessage,
                        isRetry: true,
                        completion
                    )
                }

            case .doNotRetry:
                completion(.failure(error))

            case .doNotRetryWithError(let retryError):
                completion(.failure(retryError))
            }
        }
    }
}

public extension StompClient {
    func enableLogging() {
        self.websocketClient.enableLogging()
    }
    
    func setInterceptor(_ intercepter: Interceptor) {
        self.interceptor = intercepter
    }
}
