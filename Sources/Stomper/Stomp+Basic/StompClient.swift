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
    public typealias ConnectCompletionType = (Result<Void, Never>) -> Void
    
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
    
    // MARK: Websocket
    private var websocketClient: WebSocketClient
    private var url: URL
    
    // MARK: Completions
    /// Completions for Stomp 'MESSAGE' command
    /// key: topic
    /// value: receive completions
    private var receiveCompletions: [String: [ReceiveCompletion]] = [:]
    /// Completions for Stomp 'RECEIPT' command
    /// key: Id
    /// value: receipt completion
    private var receiptCompletions: [String: ReceiptCompletion] = [:]
    /// A Completion for Stomp 'CONNECTED' command
    private var connectCompletion: ConnectCompletionType?
    /// An ID used to subscribe to the topic. [Topic: ID]
    private var idByTopic: [String: String] = [:]
    
    // MARK: Socket state
    private var isSocketConnect: Bool = false

    // MARK: Inerceptor
    private var interceptor: Interceptor? = nil
    
    public init(url: URL) {
        self.url = url
        self.websocketClient = WebSocketClient(url: url)
        super.init()
    }
    
    /// - Warning: You must send a `CONNECT` frame before sending a`SEND` frame.
    public func sendAnyMessage(
        message: StompRequestMessage,
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
        socketConnectIfNeeded()
        websocketClient.sendMessage(message.toFrame())
        
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
        _ completion: @escaping ConnectCompletionType
    ) {
        guard let host = url.host
        else {
            logger.error("""
                        No host in the provided URL.
                        Check your URL format.\n URL: \(self.url)
                        """)
            return
        }
        
        self.connectCompletion = completion
        
        let connectMessage = StompRequestMessage(
            command: .connect,
            headers: headers,
            body: body
        )
        
        if let interceptor = interceptor {
            interceptor.execute(message: connectMessage) { [weak self] interceptedMessage in
                self?.performConnect(message: interceptedMessage)
            }
        } else {
            performConnect(message: connectMessage)
        }
        
        
    }
    
    private func performConnect(
        message: StompRequestMessage
    ) {
        socketConnectIfNeeded()
        websocketClient.receiveMessage() { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error): break // This is handle in Websocket Client
            case .success(let message):
                switch message {
                case .string(let text):
                    do {
                        try self.performCompletions(text)
                    } catch {
                        logger.error("Failed to decode string to StompReceiveMessage\n \(error)")
                    }
                case .data(let data):
                    if let decodedText = String(data: data, encoding: .utf8) {
                        do {
                            try self.performCompletions(decodedText)
                        } catch {
                            logger.error("Failed to decode string to StompReceiveMessage\n \(error)")
                        }
                    } else {
                        logger.error("Failed to decode data to string before converting to StompReceiveMessage")
                    }
                @unknown default:
                    fatalError()
                }
            }
        }
        
        websocketClient.sendMessage(message.toFrame())
    }
    
    func performCompletions(_ frameString: String) throws {
        do {
            let receiveMessage = try StompReceiveMessage
                .convertFromFrame(frameString)
            self.executeReceiveCompletions(receiveMessage)
            self.executeReceiptCompletions(receiveMessage)
        } catch {
            throw error
        }
    }
    
    public func send(
        headers: [String: String],
        body: StompBody?,
        _ completion: @escaping ReceiveCompletionType
    ) {
        guard let _ = headers["destination"]
        else { logger.error("Missing 'destination' header"); return }
        
        if let receiptID = headers["receipt"] {
            let receiptCompletion = ReceiptCompletion(
                completion: completion,
                receiptID: receiptID
            )
            receiptCompletions[receiptID] = receiptCompletion
        }
        
        let sendMessage = StompRequestMessage(
            command: .send,
            headers: headers,
            body: body
        )
        
        performSend(message: sendMessage)
    }
    
    
    private func performSend(
        message: StompRequestMessage
    ){
        websocketClient.sendMessage(message.toFrame())
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
        
        let subscribeMessage = StompRequestMessage(
            command: .subscribe,
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
        message: StompRequestMessage,
        _ receiveCompletion: @escaping ReceiveCompletionType
    ) {
        websocketClient.sendMessage(message.toFrame())
        
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
        
        let unsubscribeMessage = StompRequestMessage(
            command: .unsubscribe,
            headers: headers
        )
        performUnsubscribe(message: unsubscribeMessage, topic: topic, completion: completion)
    }

    private func performUnsubscribe(
        message: StompRequestMessage,
        topic: String,
        completion: @escaping ((any Error)?) -> Void
    ) {
        websocketClient.sendMessage(message.toFrame())
        receiveCompletions.removeValue(forKey: topic)
        idByTopic.removeValue(forKey: topic)
    }
    
    public func disconnect() {
        websocketClient.disconnect()
        receiveCompletions.removeAll()
    }
}

private extension StompClient {
    private func socketConnectIfNeeded() {
        if !isSocketConnect {
            websocketClient.connect()
        }
    }
    
    private func connectCompletions(
        _ message: StompReceiveMessage
    ) {
        if message.command != .connected {
            return
        }
        
        if let connectCompletion = self.connectCompletion {
            connectCompletion(.success(()))
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
