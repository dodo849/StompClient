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
    public typealias DisconnectCompletionType = (Result<Void, Never>) -> Void
    
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
    private var retrier: Retrier? = nil
    
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
//        let send: (StompRequestMessage) -> Void = { [weak self] message in
//            self?.performSendAnyMessage(message: message, completion)
//        }
//
//        if let interceptor = interceptor {
//            interceptor.execute(message: message, completion: send)
//        } else {
//            send(message)
//        }
        
        self.performSendAnyMessage(message: message, completion)
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
        _ connectCompletion: @escaping ConnectCompletionType
    ) {
        guard let host = url.host
        else {
            logger.error("""
                        No host in the provided URL.
                        Check your URL format.\n URL: \(self.url)
                        """)
            return
        }
        
        self.connectCompletion = connectCompletion
        
        let connectMessage = StompRequestMessage(
            command: .connect,
            headers: headers
        )
        
//        let connect: (StompRequestMessage) -> Void = { [weak self] message in
//            self?.performConnect(message: message)
//        }
//
//        if let interceptor = interceptor {
//            interceptor.execute(message: connectMessage, completion: connect)
//        } else {
//            connect(connectMessage)
//        }
        
        self.performConnect(message: connectMessage)
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
                        try self.executeCompletions(text)
                    } catch {
                        logger.error("Failed to decode string to StompReceiveMessage\n \(error)")
                    }
                case .data(let data):
                    if let decodedText = String(data: data, encoding: .utf8) {
                        do {
                            try self.executeCompletions(decodedText)
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
    
    func executeCompletions(_ frameString: String) throws {
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
        _ receiptCompletion: @escaping ReceiptCompletionType
    ) {
        guard let _ = headers["destination"]
        else { logger.error("Missing 'destination' header"); return }
        
        if let receiptID = headers["receipt"] {
            let receiptCompletion = ReceiptCompletion(
                completion: receiptCompletion,
                receiptID: receiptID
            )
            receiptCompletions[receiptID] = receiptCompletion
        }
        
        let sendMessage = StompRequestMessage(
            command: .send,
            headers: headers,
            body: body
        )
        
//        let send: (StompRequestMessage) -> Void = { [weak self] message in
//            self?.performSend(message: sendMessage)
//        }
//
//        if let interceptor = interceptor {
//            interceptor.execute(message: sendMessage, completion: send)
//        } else {
//            send(sendMessage)
//        }
        
        self.performSend(message: sendMessage)
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
        
//        let subscribe: (StompRequestMessage) -> Void = { [weak self] message in
//            self?.performSubscribe(
//                id: subscriptionID,
//                topic: topic,
//                message: subscribeMessage,
//                receiveCompletion
//            )
//        }
//
//        if let interceptor = interceptor {
//            interceptor.execute(message: subscribeMessage, completion: subscribe)
//        } else {
//            subscribe(subscribeMessage)
//        }
        
            self.performSubscribe(
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
        headers: [String: String]
    ) {
        guard let _ = headers["destination"]
        else { logger.error("Missing 'id' header"); return }
        
        guard let topic = headers["destination"] 
        else { logger.error("Missing 'destination' header"); return }
        
        let unsubscribeMessage = StompRequestMessage(
            command: .unsubscribe,
            headers: headers
        )
//        
//        let unsubscribe: (StompRequestMessage) -> Void = { [weak self] message in
//            self?.performUnsubscribe(message: unsubscribeMessage, topic: topic)
//        }
//
//        if let interceptor = interceptor {
//            interceptor.execute(message: unsubscribeMessage, completion: unsubscribe)
//        } else {
//            unsubscribe(unsubscribeMessage)
//        }
        
        performUnsubscribe(message: unsubscribeMessage, topic: topic)
    }

    private func performUnsubscribe(
        message: StompRequestMessage,
        topic: String
    ) {
        websocketClient.sendMessage(message.toFrame())
        receiveCompletions.removeValue(forKey: topic)
        idByTopic.removeValue(forKey: topic)
    }
    
    public func disconnect(
        headers: [String: String],
        _ receiptCompletion: @escaping DisconnectCompletionType
    ) {
        if let receiptID = headers["receipt"] {
            let receiptCompletion = ReceiptCompletion(
                completion: { [weak self] _ in
                    receiptCompletion(.success(()))
                    
                    self?.websocketClient.disconnect()
                    self?.receiveCompletions.removeAll()
                },
                receiptID: receiptID
            )
            receiptCompletions[receiptID] = receiptCompletion
        }
        
        let disconnectMessage = StompRequestMessage(
            command: .disconnect,
            headers: headers
        )
        
        websocketClient.sendMessage(disconnectMessage.toFrame())
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

        guard let retrier = retrier else {
            completion(.failure(error))
            return
        }

        retrier.retry(
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
    
    func setRetirier(_ retrier: Retrier) {
        self.retrier = retrier
    }
}
