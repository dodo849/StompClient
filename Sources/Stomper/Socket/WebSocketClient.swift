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
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: "WebSocket"
    )
    private var isLogOn: Bool = false
    
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
                self?.logger.error("WebSocket failed to send the message:\n\(message)")
            } else {
                self?.log {
                    self?.logger.info("WebSocket successfully sent the message:\n\(message)")
                }
            }
        }
    }
    
    func receiveMessage(
        _ completion: @escaping (Result<URLSessionWebSocketTask.Message, Error>) -> Void
    ) {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                self?.log {
                    self?.logger.critical("WebSocket receive error message:\n\(error)")
                }
                completion(.failure(error))
            case .success(let message):
                self?.log {
                    self?.printReceivedMessage(message)
                }
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

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
    
    // MARK: URLSessionWebSocketDelegate methods
    // This method is called when the socket successfully connects. If the socket connection fails, this method is not called.
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.log {
            self.logger.info("WebSocket connected successfully")
        }
        connectCompletion?(nil)
    }
    
    // This method is called when the socket is closed, such as disconnect or timeout.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.log {
                self.logger.error("WebSocket failed to connect: \(error.localizedDescription)")
            }
            connectCompletion?(error)
        } else {
            self.log {
                self.logger.info("WebSocket connection closed successfully")
            }
            connectCompletion?(nil)
            self.webSocketTask = nil
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.log {
            self.logger.info("WebSocket disconnected")
        }
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
        self.isLogOn = true
    }
    
    func disableLogging() {
        self.isLogOn = false
    }
    
    func log(_ completion: @escaping () -> Void) {
        if isLogOn {
            completion()
        }
    }
}
