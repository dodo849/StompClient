//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/15/24.
//

import Foundation

//class MockWebSocketClient: WebSocketClient {
//    private var connectCompletion: ConnectCompletion?
//    private var isConnected: Bool = false
//    private var sentMessages: [String] = []
//    private var receiveQueue: [(Result<URLSessionWebSocketTask.Message, Error>)] = []
//    
//    override init(url: URL) {
//        super.init(url: url)
//    }
//    
//    override func connect(
//        _ completion: @escaping ((any Error)?) -> Void
//    ) {
//        self.isConnected = true
//        self.connectCompletion = completion
//        // Simulate successful connection
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            self.log {
//                self.logger.info("Mock WebSocket connected successfully")
//            }
//            self.connectCompletion?(nil)
//        }
//    }
//    
//    override func sendMessage(
//        _ message: String,
//        _ completion: @escaping ((any Error)?) -> Void
//    ) {
//        guard isConnected else {
//            completion(MockWebSocketError.notConnected)
//            return
//        }
//        
//        sentMessages.append(message)
//        self.log {
//            self.logger.info("Mock WebSocket sent message:\n\(message)")
//        }
//        completion(nil)
//    }
//    
//    override func receiveMessage(
//        _ completion: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void
//    ) {
//        guard isConnected else {
//            completion(.failure(MockWebSocketError.notConnected))
//            return
//        }
//        
//        if receiveQueue.isEmpty {
//            // Simulate waiting for a message
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                completion(.failure(MockWebSocketError.noMessage))
//            }
//        } else {
//            let message = receiveQueue.removeFirst()
//            completion(message)
//        }
//    }
//    
//    override func disconnect() {
//        isConnected = false
//        self.log {
//            self.logger.info("Mock WebSocket disconnected")
//        }
//    }
//    
//    // Methods to simulate incoming messages
//    func simulateIncomingMessage(_ message: String) {
//        receiveQueue.append(.success(.string(message)))
//    }
//    
//    func simulateIncomingData(_ data: Data) {
//        receiveQueue.append(.success(.data(data)))
//    }
//    
//    func simulateError(_ error: Error) {
//        receiveQueue.append(.failure(error))
//    }
//    
//    enum MockWebSocketError: Error {
//        case notConnected
//        case noMessage
//    }
//}
