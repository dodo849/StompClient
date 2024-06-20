//
//  File.swift
//  
//
//  Created by DOYEON LEE on 6/14/24.
//

import Foundation

extension EntryCommand {
    public func headers(
        _ additionalHeaders: [String: String]? = [:]
    ) -> [String: String] {
        let mirror = Mirror(reflecting: self)
        var headers: [String: String] = [:]
        
        for child in mirror.children {
            let childMirror = Mirror(reflecting: child.value)
            
            for valueChild in childMirror.children {
                if let label = valueChild.label {
                    let headerName = convertToDashCase(label)
                    
                    if let value = valueChild.value as? String {
                        headers[headerName] = value
                    } else if let value = child.value as? Int {
                        headers[headerName] = String(value)
                    } else if let value = valueChild.value as? String? {
                        if let unwrapped = value {
                            headers[headerName] = unwrapped
                        }
                    } else if let value = valueChild.value as? Int? {
                        if let unwrapped = value {
                            headers[headerName] = String(unwrapped)
                        }
                    }
                }
            }
        } 
        
        
        let mergedHeaders: [String: String] = {
            if let additionalHeaders = additionalHeaders {
                headers.merging(additionalHeaders) { (_, explicit) in explicit }
            } else {
                headers
            }
        }()
        
        return mergedHeaders
    }
    
    private func convertToDashCase(_ camelCase: String) -> String {
        let uppercase = CharacterSet.uppercaseLetters
        var dashCase = ""
        
        for scalar in camelCase.unicodeScalars {
            if uppercase.contains(scalar) {
                dashCase.append("-")
                dashCase.append(Character(scalar).lowercased())
            } else {
                dashCase.append(Character(scalar))
            }
        }
        
        return dashCase
    }
}
