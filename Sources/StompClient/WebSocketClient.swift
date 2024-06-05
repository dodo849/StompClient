//
//  WebSocketClient.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation
import OSLog

class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var connectCompletion: ((Error?) -> Void)?
    private var disconnectCompletion: ((Error?) -> Void)?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "WebSocket"
    )
    
    init(url: URL) {
        super.init()
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = urlSession?.webSocketTask(with: url)
    }
    
    func connect(
        _ completion: @escaping (Error?) -> Void
    ) {
        self.connectCompletion = completion
        webSocketTask?.resume()
    }
    
    func sendMessage(
        _ message: String,
        _ completion: @escaping ((any Error)?) -> Void
    ) {
        let socketMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(socketMessage) { error in
            self.logger.info("WebSocket send message:\n\(message)")
            if let error = error {
                completion(error)
            } else {
                completion(nil)
            }
        }
    }
    
    func receiveMessage(
        _ completion: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    ) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.logger.critical("WebSocket receive error message:\n\(error)")
                completion(.failure(error))
            case .success(let message):
                self?.printReceivedMessage(message)
                completion(.success(message))
                self?.receiveMessage(completion)
            }
        }
    }
    
    private func printReceivedMessage (
        _ message: URLSessionWebSocketTask.Message
    ) {
        switch message {
        case .string(let text):
            print("WebSocket receive message:\n\(text)")
        case .data(let data):
            print("WebSocket receive message:\n\(data)")
        @unknown default:
            fatalError()
        }
    }


    
    func disconnect(
        _ completion: @escaping (Error?) -> Void
    ) {
        self.disconnectCompletion = completion
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    // URLSessionWebSocketDelegate methods
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.logger.info("WebSocket connected successfully")
        connectCompletion?(nil)
        connectCompletion = nil
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.logger.info("WebSocket disconnected")
        disconnectCompletion?(nil)
        disconnectCompletion = nil
    }
}

// URLSessionDelegate to handle SSL handshake issues
extension WebSocketClient: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let trust = challenge.protectionSpace.serverTrust!
        let credential = URLCredential(trust: trust)
        completionHandler(.useCredential, credential)
    }
}

