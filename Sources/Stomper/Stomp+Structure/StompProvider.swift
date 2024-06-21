//
//  StompProvider.swift
//
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

open class StompProvider<Entry: EntryType>: StompProviderProtocol {
    private var client: StompClientProtocol?
    private let decodeHelper = DecodeHelper()
    /// Store interceptors to pass them during client initialization
    private var interceptor: Interceptor? = nil
    private var enableReceiptAutoGeneration: Bool = true
    
    public init() {
        self.client = StompClient(url: Entry.baseURL)
    }
    
    // Send the request to the actual client
    public func request<Response>(
        of: Response.Type,
        entry: Entry,
        _ completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        if client == nil {
           client = createNewClient()
        }
        
        guard let client = client else {
            completion(.failure(StomperError.clientNotInitialized))
            return
        }
        
        let mergedHeaders = mergeAndGenerateHeaders(entry: entry)
        
        switch entry.command {
        case .connect:
            client.connect(headers: mergedHeaders) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success():
                    if let response = "Connect success" as? Response {
                        completion(.success(response))
                    } else {
                        self.handleTypeMismatchError(
                            "Connect success case of request method",
                            Response.self,
                            String.self,
                            completion
                        )
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        case .send:
            client.send(
                headers: mergedHeaders,
                body: entry.body.toStompBody()
            ) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                    
                case .success(let reciptMessage):
                    if let response = reciptMessage as? Response {
                        completion(.success(response))
                    } else {
                        self.handleTypeMismatchError(
                            "Send success case of request method",
                            Response.self,
                            StompReceiveMessage.self,
                            completion
                        )
                    }
                }
            }
            
        case .subscribe:
            client.subscribe(headers: mergedHeaders) { [weak self] result in
                switch result {
                case .success(let receiveMessage):
                    guard let self = self else { return }
                    
                    if Response.self is StompReceiveMessage.Type {
                        completion(.success(receiveMessage as! Response))
                    } else if let decodableType = Response.self as? Decodable.Type {
                        self.decodeHelper.handleDecodable(
                            receiveMessage,
                            ofType: decodableType,
                            completion: completion
                        )
                    } else if let stringType = Response.self as? String.Type {
                        self.decodeHelper.handleString(
                            receiveMessage,
                            ofType: stringType,
                            completion: completion
                        )
                    } else {
                        self.decodeHelper.handleData(
                            receiveMessage,
                            completion: completion
                        )
                    }
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        case .disconnect:
            client.disconnect(headers: mergedHeaders) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success():
                    if let response = "Disconnect success" as? Response {
                        completion(.success(response))
                        self.client = nil
                    } else {
                        self.handleTypeMismatchError(
                            "Disconnect success case of request method",
                            Response.self,
                            String.self,
                            completion
                        )
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        default:
            guard let command = StompRequestCommand(
                rawValue: entry.command.name
            ) else {
                fatalError(commandMappingError)
            }
            
            let message = StompRequestMessage(
                command: command,
                headers: mergedHeaders,
                body: entry.body.toStompBody()
            )
            
            client.sendAnyMessage(message: message) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                    
                case .success(let reciptMessage):
                    if let response = reciptMessage as? Response {
                        completion(.success(response))
                    } else {
                        self.handleTypeMismatchError(
                            "Send \(entry.command.name) send success case of request method",
                            Response.self,
                            StompReceiveMessage.self,
                            completion
                        )
                    }
                }
                
            }
        }
    }
}
    
public extension StompProvider {
    func enableLogging() -> Self {
        self.client?.enableLogging()
        return self
    }

    
    func intercepted(_ interceptor: Interceptor) -> Self {
        self.interceptor = interceptor
        
        if let client = client {
            let executorDecorator = StompClientExecutorDecorator(
                executor: interceptor,
                wrappee: client
            )
            self.client = executorDecorator
            self.client?.setRetrier(interceptor)
        }
        return self
    }
    
    func disableReceiptAutoGeneration(_ disabled: Bool = false) -> Self {
        self.enableReceiptAutoGeneration = disabled
        return self
    }
}

extension StompProvider {
    private func createNewClient() -> StompClientProtocol {
        let newClient = StompClient(url: Entry.baseURL)
        
        if let interceptor = interceptor {
            newClient.setRetrier(interceptor)
            let executorDecorator = StompClientExecutorDecorator(
                executor: interceptor,
                wrappee: newClient
            )
            return executorDecorator
        }
        return newClient
    }
    
    
    private func mergeAndGenerateHeaders(entry: Entry) -> [String: String] {
        let explicitHeaders = entry.additionalHeaders
            .merging(entry.destinationHeader) {
                (current, _) in current
            }
        
        var mergedHeaders = entry.command.headers(explicitHeaders)
        
        if enableReceiptAutoGeneration {
            mergedHeaders["receipt"] = mergedHeaders["receipt"] ?? UUID().uuidString
        }
        
        return mergedHeaders
    }
}

extension StompProvider {
    private var commandMappingError: String {
        """
        Library error: The Stomp command protocol is not valid.
        Please consult the library developer for assistance.
        For library developer: Please ensure the command spelling is correctly mapped.
        """
    }
    
    private func handleTypeMismatchError<Response>(
        _ closureName: String,
        _ expectedType: Any.Type,
        _ tryType: Any.Type,
        _ completion: @escaping (Result<Response, any Error>) -> Void
    ) {
            let error = StomperError.responseTypeMismatch(
                """
                \(closureName) expected a \(expectedType.self) \
                type response, but responseType is \(tryType.self)
                """
            )
            completion(.failure(error))
    }
    
    private func handleErrorFrame<Response>(
        receiveMessage: StompReceiveMessage,
        _ completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        completion(.failure(
            StomperError.receiveErrorFrame(receiveMessage)
        ))
    }
}
