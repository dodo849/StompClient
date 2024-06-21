//
//  DecodeHelper.swift
//
//
//  Created by DOYEON LEE on 6/19/24.
//

import Foundation

struct DecodeHelper {
    func handleDecodable<Response>(
        _ receiveMessage: StompReceiveMessage,
        ofType type: Decodable.Type,
        completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        do {
            let decoded = try receiveMessage.decode(type)
            if let typedDecoded = decoded as? Response {
                completion(.success(typedDecoded))
            } else {
                completion(.failure(StomperError.decodeFailed(decodingError(Response.self))))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func handleString<Response>(
        _ receiveMessage: StompReceiveMessage,
        ofType type: String.Type,
        completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        if let data = receiveMessage.body,
           let decoded = String(data: data, encoding: .utf8) as? Response {
            completion(.success(decoded))
        } else {
            completion(.failure(StomperError.decodeFailed(decodingError(Response.self))))
        }
    }
    
    func handleData<Response>(
        _ receiveMessage: StompReceiveMessage,
        completion: @escaping (Result<Response, any Error>) -> Void
    ) {
        if let response = receiveMessage.body as? Response {
            completion(.success(response))
        } else {
            completion(.failure(StomperError.decodeFailed(decodingError(Response.self))))
        }
    }
    
    private func decodingError(_ type: Any.Type) -> String {
        """
        Received message body does not match the ResponseType (\(type.self))
        """
    }
}
