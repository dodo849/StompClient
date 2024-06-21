//
//  StompClient.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation
import OSLog

public final class StompClient: NSObject, StompClientProtocol {
    public typealias ReceiveCompletionType = (Result<StompReceiveMessage, Never>) -> Void
    public typealias ReceiptCompletionType = (Result<StompReceiveMessage, any Error>) -> Void
    public typealias ConnectCompletionType = (Result<Void, Error>) -> Void
    public typealias DisconnectCompletionType = (Result<Void, Error>) -> Void
    
    /// A Completion for Stomp 'MESSAGE' command
    fileprivate struct ReceiveCompletion {
        var completion: ReceiveCompletionType
        var subscriptionID: String
    }
    
    /// A Completion for Stomp 'RECEIPT' command
    fileprivate struct ReceiptCompletion {
        var completion: ReceiptCompletionType
        var requestMessage: StompRequestMessage
        var receiptID: String
    }
    
    /// A Completion for Stomp 'CONNECTED' command
    fileprivate struct ConnectCompletion {
        var completion: ConnectCompletionType
        var requestMessage: StompRequestMessage
    }
    
    private let logger = DisableableLogger(
        subsystem: "Stomper",
        category: "StompClient",
        isDisabled: true
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
    private var connectCompletion: ConnectCompletion?
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
    
    /// - Warning: You must call the `connect(headers:_:)` or send `CONNECT` frame before sending any frames other than `CONNECT`.
    public func sendAnyMessage(
        message: StompRequestMessage,
        _ completion: @escaping ReceiptCompletionType
    ) {
        if message.command == .connect {
            socketConnectIfNeeded()
            self.connect(headers: message.headers.dict) { _ in }
        } else if isSocketConnect == false {
            logger.error("""
                        You must call the `connect(headers:_:)` or send `CONNECT` frame before sending any frames other than `CONNECT`.
                        """)
            return
        }
        
        self.performSendAnyMessage(message: message, completion)
    }
    
    private func performSendAnyMessage(
        message: StompRequestMessage,
        didRetryCount: Int = 0,
        _ completion: @escaping ReceiptCompletionType
    ) {
        websocketClient.sendMessage(message.toFrame())
        
        if let receiptID = message.headers.dict["receipt"] {
            let receiptCompletion = ReceiptCompletion(
                completion: completion,
                requestMessage: message,
                receiptID: receiptID
            )
            receiptCompletions[receiptID] = receiptCompletion
        }
    }
    
    public func connect(
        headers: [String: String],
        _ connectCompletion: @escaping ConnectCompletionType
    ) {
        guard url.host != nil
        else {
            logger.error("""
                        No host in the provided URL.
                        Check your URL format.\n URL: \(self.url)
                        """)
            return
        }
        
        let connectMessage = StompRequestMessage(
            command: .connect,
            headers: headers
        )
        
        self.connectCompletion = ConnectCompletion(
            completion: connectCompletion,
            requestMessage: connectMessage
        )
        
        self.performConnect(message: connectMessage)
    }
    
    private func performConnect(
        message: StompRequestMessage,
        didRetryCount: Int = 0
    ) {
        socketConnectIfNeeded()
        websocketClient.receiveMessage() { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(_):
                isSocketConnect = false
                return
            case .success(let message):
                switch message {
                case .string(let text):
                    do {
                        try self.executeCompletions(
                            text,
                            didRetryCount: didRetryCount
                        )
                    } catch {
                        logger.error("Failed to decode string to StompReceiveMessage\n \(error)")
                    }
                case .data(let data):
                    if let decodedText = String(data: data, encoding: .utf8) {
                        do {
                            try self.executeCompletions(
                                decodedText,
                                didRetryCount: didRetryCount
                            )
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
    
    func executeCompletions(
        _ frameString: String,
        didRetryCount: Int = 0
    ) throws {
        do {
            let receiveMessage = try StompReceiveMessage
                .convertFromFrame(frameString)
            
            self.executeConnectCompletion(
                message: receiveMessage,
                didRetryCount: didRetryCount
            )
            self.executeReceiveCompletions(message: receiveMessage)
            self.executeReceiptCompletions(
                message: receiveMessage,
                didRetryCount: didRetryCount
            )
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
                requestMessage: StompRequestMessage(
                    command: .send,
                    headers: headers,
                    body: body
                ),
                receiptID: receiptID
            )
            receiptCompletions[receiptID] = receiptCompletion
        }
        
        let sendMessage = StompRequestMessage(
            command: .send,
            headers: headers,
            body: body
        )
        
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
                requestMessage: StompRequestMessage(
                    command: .disconnect,
                    headers: headers
                ),
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
    
    private func executeConnectCompletion(
        message: StompReceiveMessage,
        didRetryCount: Int = 0
    ) {
        guard message.command == .connected || message.command == .error 
        else { return }
        
        guard let connectCompletion = self.connectCompletion 
        else { return }

        if message.command == .connected {
            isSocketConnect = true
            connectCompletion.completion(.success(()))
            return
        }
        
        // error인데 socket커넥트가 완료가 안된 상태이면 CONNET 재시도.
        if message.command == .error && !isSocketConnect {
            handleConnectRetry(
                message: connectCompletion.requestMessage,
                errorMessage: message,
                didRetryCount: didRetryCount,
                completion: connectCompletion.completion
            )
            return
        }
    }
    
    private func executeReceiveCompletions(
        message: StompReceiveMessage
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
        message: StompReceiveMessage,
        didRetryCount: Int = 0
    ) {
        if message.command != .receipt || message.command != .error {
            return
        }
        
        if let receiptID = message.headers["receipt-id"],
           let receiptCompletion = self.receiptCompletions[receiptID]  {
                if message.command == .receipt {
                    receiptCompletion.completion(.success(message))
                    
                } else if message.command == .error {
                        handleSendAnyMessageRetry(
                            message: receiptCompletion.requestMessage,
                            errorMessage: message,
                            didRetryCount: didRetryCount,
                            completion: receiptCompletion.completion
                        )
                }
            
            receiptCompletions.removeValue(forKey: receiptID)
        }
    }
    
    private func handleConnectRetry(
        message: StompRequestMessage,
        errorMessage: StompReceiveMessage,
        didRetryCount: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        
        let receiveError = StomperError.receiveErrorFrame(errorMessage)
        
        guard let retrier = retrier else {
            completion(.failure(receiveError))
            return
        }
        
        retrier.retry(
            message: message,
            errorMessage: errorMessage
        ) { [weak self] retryMessage, retryType in
            guard let self = self else {
                completion(.failure(receiveError))
                return
            }
            
            switch retryType {
            case .retry(let count, let delay):
                if didRetryCount >= count {
                    completion(.failure(receiveError))
                    return
                }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performConnect(
                        message: retryMessage,
                        didRetryCount: didRetryCount + 1
                    )
                }
                
            case .doNotRetry:
                completion(.failure(receiveError))
                
            case .doNotRetryWithError(let retryError):
                completion(.failure(retryError))
            }
        }
    }
    
    private func handleSendAnyMessageRetry(
        message: StompRequestMessage,
        errorMessage: StompReceiveMessage,
        didRetryCount: Int,
        completion: @escaping (Result<StompReceiveMessage, Error>) -> Void
    ) {
        
        let receiveError = StomperError.receiveErrorFrame(errorMessage)
        
        guard let retrier = retrier else {
            completion(.failure(receiveError))
            return
        }
        
        retrier.retry(
            message: message,
            errorMessage: errorMessage
        ) { [weak self] retryMessage, retryType in
            guard let self = self else {
                completion(.failure(receiveError))
                return
            }
            
            switch retryType {
            case .retry(let count, let delay):
                if didRetryCount >= count {
                    completion(.failure(receiveError))
                    return
                }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performSendAnyMessage(
                        message: retryMessage,
                        didRetryCount: didRetryCount + 1,
                        completion
                    )
                }
                
            case .doNotRetry:
                completion(.failure(receiveError))
                
            case .doNotRetryWithError(let retryError):
                completion(.failure(retryError))
            }
        }
    }
}

public extension StompClient {
    func enableLogging() {
        self.logger.disabled(false)
        self.websocketClient.enableLogging()
    }
    
    func setRetirier(_ retrier: Retrier) {
        self.retrier = retrier
    }
}
