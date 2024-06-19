//
//  StompProvider.swift
//
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

open class StompProvider<Entry: EntryType>: StompProviderProtocol {
    private let client: StompClient
    private let decodeHelper = DecodeHelper()
    private var interceptor: Interceptor? = nil
    
    public init() {
        self.client = StompClient(url: Entry.baseURL)
    }
    
    /// A proxy function for executing interceptors and merging additional headers
    public func request<Response>(
        of: Response.Type,
        entry: Entry,
        _ completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        let handleRequest: (Entry) -> Void = { interceptedEntry in
            interceptedEntry.headers.addHeaders(entry.destinationHeader)
            self.performRequest(
                of: Response.self,
                entry: interceptedEntry,
                completion
            )
        }

        if let interceptor = interceptor {
            interceptor.execute(entry: entry) { interceptedEntry in
                handleRequest(interceptedEntry)
            }
        } else {
            handleRequest(entry)
        }
    }
    
    /// Send the request to the actual client
    private func performRequest<Response>(
        of: Response.Type,
        entry: Entry,
        _ completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        switch entry.command {
        case .connect:
            client.connect() { [weak self] error in
                if let error = error {
                    self?.handleRetry(
                        entry: entry,
                        error: error,
                        completion: completion
                    )
                } else {
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
                headers: entry.command.headers(entry.headers.dict),
                body: entry.body.toStompBody()
            ) { [weak self] result in
                switch result {
                case .failure(let error):
                    self?.handleRetry(
                        entry: entry,
                        error: error,
                        completion: completion
                    )
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
                headers: entry.command.headers(entry.headers.dict)
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
                    self?.handleRetry(
                        entry: entry,
                        error: error,
                        completion: completion
                    )
                }
            }
            
        default:
            guard let command = StompRequestCommand(rawValue: entry.command.name) else {
                fatalError(commandMappingError)
            }
            let message = StompAnyMessage(
                command: command,
                headers: entry.command.headers(entry.headers.dict),
                body: nil
            )
            
            client.sendAnyMessage(message: message) { [weak self] result in
                switch result {
                case .failure(let error):
                    self?.handleRetry(
                        entry: entry,
                        error: error,
                        completion: completion
                    )
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
    
    private func handleRetry<Response>(
        entry: Entry,
        error: Error,
        completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        guard let interceptor = interceptor else {
            completion(.failure(error))
            return
        }
        
        interceptor.retry(
            entry: entry,
            error: error
        ) { [weak self] retryEntry, retryType in
            guard let self = self else {
                completion(.failure(error))
                return
            }
            
            switch retryType {
            case .retry:
                self.performRequest(of: Response.self, entry: retryEntry, completion)
                
            case .delayedRetry(let delay):
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.performRequest(of: Response.self, entry: retryEntry, completion)
                }
                
            case .doNotRetry:
                completion(.failure(error))
                
            case .doNotRetryWithError(let retryError):
                completion(.failure(retryError))
            }
        }
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
    
//    private func decodingError(_ type: Any.Type) -> String {
//        """
//        Received message body does not match the ResponseType (\(type.self))
//        """
//    }
    
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

public extension StompProvider {
    func enableLogging() -> Self {
        self.client.enableLogging()
        return self
    }
}

public extension StompProvider {
    func intercept(_ intercepter: Interceptor) -> Self {
        self.interceptor = intercepter
        return self
    }
}
