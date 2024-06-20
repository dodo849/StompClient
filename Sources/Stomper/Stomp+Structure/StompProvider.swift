//
//  StompProvider.swift
//
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

open class StompProvider<Entry: EntryType>: StompProviderProtocol {
    private var client: StompClient?
    private let decodeHelper = DecodeHelper()
    /// Store interceptors to pass them during client initialization
    private var interceptor: Interceptor? = nil
    
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
        
        switch entry.command {
        case .connect:
            client.connect(
                headers: entry.command.headers(entry.additionalHeaders),
                body: entry.body.toStompBody()
            ) { [weak self] result in
                switch result {
                case .success():
                    if let response = "Connect success" as? Response {
                        completion(.success(response))
                    } else {
                        self?.handleTypeMismatchError(
                            "Connect success case of request method",
                            Response.self,
                            String.self,
                            completion
                        )
                    }
                }
            }
            
        case .send:
            client.send(
                headers: entry.command.headers(entry.additionalHeaders),
                body: entry.body.toStompBody()
            ) { [weak self] result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                    
                case .success(let reciptMessage):
                    if let response = reciptMessage as? Response {
                        completion(.success(response))
                    } else {
                        self?.handleTypeMismatchError(
                            "Send success case of request method",
                            Response.self,
                            StompReceiveMessage.self,
                            completion
                        )
                    }
                }
            }
            
        case .subscribe:
            client.subscribe(
                headers: entry.command.headers(entry.additionalHeaders)
            ) { [weak self] result in
                switch result {
                case .success(let receiveMessage):
                    guard let self = self else { return }
                    
                    if let receiveType = Response.self as? StompReceiveMessage.Type {
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
            
        default:
            guard let command = StompRequestCommand(
                rawValue: entry.command.name
            ) else {
                fatalError(commandMappingError)
            }
            
            let message = StompRequestMessage(
                command: command,
                headers: entry.command.headers(entry.additionalHeaders),
                body: entry.body.toStompBody()
            )
            
            client.sendAnyMessage(message: message) { [weak self] result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                    
                case .success(let reciptMessage):
                    if let response = reciptMessage as? Response {
                        completion(.success(response))
                    } else {
                        self?.handleTypeMismatchError(
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
    
    public func disconnect() {
        client?.disconnect()
        client = nil
    }
}

public extension StompProvider {
    private func createNewClient() -> StompClient {
        let newClient = StompClient(url: Entry.baseURL)
        if let interceptor = interceptor {
            newClient.setInterceptor(interceptor)
        }
        return newClient
    }
    
    func enableLogging() -> Self {
        self.client?.enableLogging()
        return self
    }

    
    func intercepted(_ intercepter: Interceptor) -> Self {
        self.interceptor = intercepter
        
        if let client = client {
            let _ = client.setInterceptor(intercepter)
        }
        return self
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
            let error = StompError.responseTypeMismatch(
                """
                \(closureName) expected a \(expectedType.self) \
                type response, but responseType is \(tryType.self)
                """
            )
            completion(.failure(error))
    }
}
