//
//  StompClientInterceptorDecorator.swift
//
//
//  Created by DOYEON LEE on 6/21/24.
//

import Foundation

final class StompClientExecutorDecorator: StompClientProtocol {
    private var executor: Executor
    
    private var wrappee: StompClientProtocol
    
    init(
        executor: Executor,
        wrappee: StompClientProtocol
    ) {
        self.executor = executor
        self.wrappee = wrappee
    }
    
    
    func sendAnyMessage(
        message: StompRequestMessage,
        _ completion: @escaping (Result<StompReceiveMessage, any Error>) -> Void
    ) {
        executor.execute(message: message) { [weak self] interceptedMessage in
            self?.wrappee.sendAnyMessage(message: interceptedMessage, completion)
        }
    }
        
    func connect(
        headers: [String : String],
        _ completion: @escaping (Result<Void, Never>) -> Void
    ) {
        let connectMessage = StompRequestMessage(
            command: .connect,
            headers: headers
        )
        
        executor.execute(message: connectMessage) { [weak self] interceptedMessage in
            self?.wrappee.connect(headers: interceptedMessage.headers.dict, completion)
        }
    }
    
    func send(
        headers: [String : String],
        body: StompBody?,
        _ completion: @escaping (Result<StompReceiveMessage, any Error>) -> Void
    ) {
        let sendMessage = StompRequestMessage(
            command: .send,
            headers: headers,
            body: body
        )
        
        executor.execute(message: sendMessage) { [weak self] interceptedMessage in
            self?.wrappee.send(
                headers: interceptedMessage.headers.dict,
                body: interceptedMessage.body,
                completion
            )
        }
    }
    
    func subscribe(
        headers: [String : String],
        _ receiveCompletion: @escaping (Result<StompReceiveMessage, any Error>) -> Void
    ) {
        let subscribeMessage = StompRequestMessage(
            command: .subscribe,
            headers: headers
        )
        
        executor.execute(message: subscribeMessage) { [weak self] interceptedMessage in
            self?.wrappee.subscribe(
                headers: interceptedMessage.headers.dict,
                receiveCompletion
            )
        }
    }
    
    func unsubscribe(
        headers: [String : String]
    ) {
        let unsubscribeMessage = StompRequestMessage(
            command: .subscribe,
            headers: headers
        )
        
        executor.execute(message: unsubscribeMessage) { [weak self] interceptedMessage in
            self?.wrappee.unsubscribe(
                headers: interceptedMessage.headers.dict
            )
        }
    }
    
    func disconnect(
        headers: [String: String],
        _ receiptCompletion: @escaping (Result<Void, Never>) -> Void
    ) {
        let disconnectMessage = StompRequestMessage(
            command: .disconnect,
            headers: headers
        )
        
        executor.execute(message: disconnectMessage) { [weak self] interceptedMessage in
            self?.wrappee.disconnect(
                headers: interceptedMessage.headers.dict,
                receiptCompletion
            )
        }
    }
    
    func enableLogging() {
        wrappee.enableLogging()
    }
}
