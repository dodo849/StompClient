//
//  WebSocketClient.swift
//  StompClient
//
//  Created by DOYEON LEE on 6/4/24.
//

import Foundation
import OSLog

class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    private typealias ConnectCompletion = ((any Error)?) -> Void
    
    private let logger = DisableableLogger(
        subsystem: "Stomper",
        category: "WebSocket",
        isDisabled: true
    )
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let url: URL
    private var connectCompletion: (ConnectCompletion)?
    
    init(url: URL) {
        self.url = url
        super.init()
        createURLSession()
    }
    
    private func createURLSession() {
        let configuration = URLSessionConfiguration.default
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = urlSession?.webSocketTask(with: url)
    }
    
    func connect() {
        if webSocketTask == nil {
            createURLSession()
        }
        webSocketTask?.resume()
    }
    
    func sendMessage(
        _ message: String
    ) {
        let socketMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(socketMessage) { [weak self] error in
            if let error = error {
                self?.logger.error("""
                    WebSocket failed to send the message:\n\(message)\n error: \(error)
                    """)
            } else {
                self?.logger.info("WebSocket successfully sent the message:\n\(message)")
            }
        }
    }
    
    func receiveMessage(
        _ completion: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    ) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.logger.fault("WebSocket encountered error:\n\(error)")
            case .success(let message):
                self?.printReceivedMessage(message)
                completion(.success(message))
                self?.receiveMessage(completion) // For next message
            }
        }
    }
    
    private func printReceivedMessage (
        _ message: URLSessionWebSocketTask.Message
    ) {
        switch message {
        case .string(let text):
            logger.debug("WebSocket receive message:\n\(text)")
        case .data(let data):
            logger.debug("WebSocket receive message:\n\(data)")
        @unknown default:
            fatalError()
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    // MARK: URLSessionWebSocketDelegate methods
    // This method is called when the socket successfully connects. If the socket connection fails, this method is not called.
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.logger.info("WebSocket connected successfully")
        connectCompletion?(nil)
    }
    
    // This method is called when the socket is closed, such as disconnect or timeout.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.logger.error("WebSocket failed to connect: \(error.localizedDescription)")
            connectCompletion?(error)
        } else {
            self.logger.info("WebSocket connection closed successfully")
            connectCompletion?(nil)
            self.webSocketTask = nil
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.logger.info("WebSocket try disconnect")
        self.webSocketTask = nil
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

extension WebSocketClient {
    func enableLogging() {
        self.logger.disabled(false)
    }
    
    func disableLogging() {
        self.logger.disabled(true)
    }
}
