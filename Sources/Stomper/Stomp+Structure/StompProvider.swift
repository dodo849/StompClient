//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

public extension StompProvider {
    func intercept(_ intercepters: [Intercepter]) {
        self.intercepters = intercepters
    }
}

open class StompProvider<Entry: EntryType>: StompProviderProtocol {
    
    private let client: StompClient
    private var intercepters: [Intercepter] = []
    
    public init() {
        self.client = StompClient(url: Entry.baseURL)
    }
    
    /// A proxy function for executing interceptors and merging additional headers
    public func request<Response>(
        entry: Entry,
        _ completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        let interceptedEntry = intercepters.reduce(entry) { $1.intercept($0) }
        
        interceptedEntry.headers.addHeaders(entry.destinationHeader)
        
        return performRequest(entry: interceptedEntry, completion)
    }
    
    /// Send the request to the actual client
    public func performRequest<Response>(
        entry: Entry,
        _ completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        switch entry.command {
        case .connect:
            client.connect() { [weak self] error in
                if let error = error {
                    completion(.failure(error))
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
                headers: entry.command.headers(entry.headers.dict)
            ) { [weak self] result in
                switch result {
                case .success(let receiveMessage):
                    guard let self = self else { return }
                    
                    if let receiveType = Response.self as? StompReceiveMessage.Type {
                        completion(.success(receiveMessage as! Response))
                    } else if let decodableType = Response.self as? Decodable.Type {
                        self.handleDecodable(
                            receiveMessage,
                            ofType: decodableType,
                            completion: completion
                        )
                    } else if let stringType = Response.self as? String.Type {
                        self.handleString(
                            receiveMessage,
                            ofType: stringType,
                            completion: completion
                        )
                    } else {
                        self.handleData(
                            receiveMessage,
                            completion: completion
                        )
                    }
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            
        default:
            guard let command = StompCommandType(rawValue: entry.command.name) else {
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
}

private extension StompProvider {
    private func handleDecodable<Response>(
        _ receiveMessage: StompReceiveMessage,
        ofType type: Decodable.Type,
        completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        do {
            let decoded = try receiveMessage.decode(type)
            if let typedDecoded = decoded as? Response {
                completion(.success(typedDecoded))
            } else {
                completion(.failure(StompError.decodeFaild(decodingError(Response.self))))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private func handleString<Response>(
        _ receiveMessage: StompReceiveMessage,
        ofType type: String.Type,
        completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        if let data = receiveMessage.body,
           let decoded = String(data: data, encoding: .utf8) as? Response {
            completion(.success(decoded))
        } else {
            completion(.failure(StompError.decodeFaild(decodingError(Response.self))))
        }
    }
    
    private func handleData<Response>(
        _ receiveMessage: StompReceiveMessage,
        completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        if let response = receiveMessage.body as? Response {
            completion(.success(response))
        } else {
            completion(.failure(StompError.decodeFaild(decodingError(Response.self))))
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
    
    private func decodingError(_ type: Any.Type) -> String {
        """
        Received message body does not match the ResponseType (\(type.self))
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

public extension StompProvider {
    func enableLogging() {
        self.client.enableLogging()
    }
}
