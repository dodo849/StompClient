# Stomper
![iOS badge](https://img.shields.io/badge/iOS-14.0%2B-black)
![macOS badge](https://img.shields.io/badge/macOS-11.0%2B-black)
![tvOS badge](https://img.shields.io/badge/tvOS-14.0%2B-black)
![watchOS badge](https://img.shields.io/badge/watchOS-7.0%2B-black)
---
안정화중입니다...🙇


## Installation
### Swift Package Manager
해당 패키지를 프로젝트에 추가하려면 Pakage.swift파일에 아래 코드를 추가하세요.
```swift
.package(url: "https://github.com/dodo849/Stomper.git", .upToNextMajor(from: "0.6.0"))
```
혹은 Xcode에서 Project Settings > Swift Packages Dependenceis...

## Basic Usage
먼저, 요청을 보내기 위한 정보를 EntryType을 이용해서 정의하세요

- baseURL은 소켓에 접속하기 위한 엔드포인트입니다. wss 혹은 ws로 시작합니다.
- path는 STOMP에서 구독하거나 
```swift
enum ChatEntry {
   case connect
   case subscribeChat
   case sendChat(ChatMessage)
   case disconnect
}

extension ChatMessageEntry: EntryType {
   static var baseURL: URL {
       URL(string: "wws://localhost:8080")!
   }
   
   var path: String? {
       switch self {
       case .subscribeChat:
           return "/sub/chat"
       case .sendMessage:
           return "/pub/chat"
       default:
           return nil
       }
   }
   
   var command: EntryCommand {
       switch self {
       case .connect:
           return .connect()
       case .subscribeChat:
           return .subscribe()
       case .sendMessage(_):
           return .send()
       case .disconnect:
           return .disconnect()
       }
   }
   
   var body: EntryRequestBodyType {
       switch self {
       case .sendMessage(let message):
           return .withJSON(message)
       default:
           return .none
       }
   }
   
   var additionalHeaders: [String : String] {
       return [:]
   }
}
```

