//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

public protocol ResponseProtocol {}
extension Bool: ResponseProtocol {}
extension String: ResponseProtocol {}
extension Data: ResponseProtocol {}
extension Encodable where Self: ResponseProtocol {}

open class StompProvider<Entry: EntryType>: StompProviderProtocol {
    
    private let client: StompClient
    
    public init() {
        self.client = StompClient(url: Entry.baseURL)
    }
    
    public func request<ResponseType>(
        entry: Entry,
        _ completion: @escaping (Result<ResponseType, any Error>) -> Void
    ) {
        switch entry.command {
        case .connect:
            client.connect() { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(true as! ResponseType))
                }
            }
            
        case .send:
            client.send(
                headers: entry.command.headers(entry.destinationHeader),
                body: entry.body.toStompBody()
            ) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(_):
                    completion(.success(true as! ResponseType))
                }
            }
            
        case .subscribe:
            client.subscribe(
                headers: entry.command.headers(entry.destinationHeader)
            ) { [weak self] result in
                switch result {
                case .success(let receiveMessage):
                    guard let self = self else { return }
                    
                    if let decodableType = ResponseType.self as? Decodable.Type {
                        self.handleDecodable(
                            receiveMessage,
                            ofType: decodableType,
                            completion: completion
                        )
                    } else if let stringType = ResponseType.self as? String.Type {
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
                headers: entry.command.headers(),
                body: nil
            )
            
            client.sendAnyMessage(message: message) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(true as! ResponseType))
                }
                
            }
        }
    }
}

private extension StompProvider {
    private func handleDecodable<ResponseType>(
        _ receiveMessage: StompReceiveMessage,
        ofType type: Decodable.Type,
        completion: @escaping (Result<ResponseType, any Error>) -> Void
    ) {
        do {
            let decoded = try receiveMessage.decode(type)
            if let typedDecoded = decoded as? ResponseType {
                completion(.success(typedDecoded))
            } else {
                completion(.failure(StompError.decodeFaild(decodingError(ResponseType.self))))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private func handleString<ResponseType>(
        _ receiveMessage: StompReceiveMessage,
        ofType type: String.Type,
        completion: @escaping (Result<ResponseType, any Error>) -> Void
    ) {
        if let data = receiveMessage.body,
           let decoded = String(data: data, encoding: .utf8) as? ResponseType {
            completion(.success(decoded))
        } else {
            completion(.failure(StompError.decodeFaild(decodingError(ResponseType.self))))
        }
    }
    
    private func handleData<ResponseType>(
        _ receiveMessage: StompReceiveMessage,
        completion: @escaping (Result<ResponseType, any Error>) -> Void
    ) {
        if let response = receiveMessage.body as? ResponseType {
            completion(.success(response))
        } else {
            completion(.failure(StompError.decodeFaild(decodingError(ResponseType.self))))
        }
    }
}

extension StompProvider {
    var commandMappingError: String {
        """
        Library error: The Stomp command protocol is not valid.
        Please consult the library developer for assistance.
        For library developer: Please ensure the command spelling is correctly mapped.
        """
    }
    
    func decodingError(_ type: Any.Type) -> String {
        return "Received message body does not match the ResponseType (\(type.self))"
    }
}

public extension StompProvider {
    func enableLogging() {
        self.client.enableLogging()
    }
}
