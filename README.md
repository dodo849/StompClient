# Stomper

![iOS badge](https://img.shields.io/badge/iOS-14.0%2B-black)
![macOS badge](https://img.shields.io/badge/macOS-11.0%2B-black)
![tvOS badge](https://img.shields.io/badge/tvOS-14.0%2B-black)
![watchOS badge](https://img.shields.io/badge/watchOS-7.0%2B-black)

> Stomper is a Swift network socket communication library that uses the STOMP protocol.

#### This library provides a convenient Swift interface for STOMP-based socket communication.
- Commands and headers can be safely defined at compile time.
- Converts STOMP frames into Swift objects.
- Transforms bidirectional socket communication into a pub/sub model, making it convenient to use completion handlers.
- Provides specialized protocols for easy management of specifications and endpoints.
- Allows implementation of interceptors and retry logic.
---

#### Currently Stabilizing... 🙇
---
For more details on STOMP, refer to the [STOMP Specification](https://stomp.github.io/stomp-specification-1.2.html).
<br/><br/>

## Installation
### 1. Using Swift Package Manager (SPM)
To install the package using SPM, add the dependency to your `Package.swift` file.
```swift
.package(url: "https://github.com/dodo849/Stomper", from: "0.6.0")
```
### 2. Adding Package in Xcode
1. Open your Xcode project.
2. Select the project file in the project navigator.
3. Click on the "Swift Packages" tab.
4. Click the "Add Package Dependency" button.
5. Enter the GitHub URL or another repository URL, proceed to the next steps, and select the desired version.
6. Xcode will automatically download and integrate the dependency into your project.
<br/>

After installing the package, you can use the import statement to use the library in your project.
```swift
import Stomper
```
<br/>

## Preparation - EntryType

You can manage communication specifications by inheriting from `EntryType`. First, enumerate the communication names in an enum and receive the necessary parameters using associated values. Then, inherit `EntryType` and define the required `baseURL`, `topic`, `command`, `body`, and `additionalHeaders`.

#### **baseURL**
> The server address, starting with `ws` or `wss`.
#### **topic**
> The path corresponding to `destination` in STOMP communication. Use `nil` if not needed.
#### **command**
> Define which STOMP command to use. Each command can pass the required headers specified by the STOMP specification as associated values.
- For detailed command types and headers, refer to [`EntryCommand`](https://github.com/dodo849/Stomper/blob/main/Sources/Stomper/Stomp%2BStructure/EntryCommand.swift).
#### **body**
> If there is information to be included in the body, pass the parameters along with the decode specification.
- `.none`: No body
- `.withPlain`: Simple String
- `.withData`: Data type information
- `.withJSON`: JSON information. Receives an `Encodable` object.
- `.withCustomJSONE`: Used when a custom encoder other than the default `JSONEncoder` is needed. Receives an `Encodable` object and an `Encoder`.
- `.withParameters`: Used when passing key-value type parameters. Requires a special encoder to convert to Data type for the body.
#### **additionalHeaders**
> If special headers are needed beyond the STOMP specification, use this. If it overlaps with the STOMP specification, `additionalHeaders` takes precedence.

```swift
enum ChatEntry {
    case connect
    case subscribeChat
    case sendMessage(message: ChatRequestDTO)
    case disconnect
}

extension ChatEntry: EntryType {
    static var baseURL: URL {
        URL(string: "wss://localhost:8080")!
    }
    
    var topic: String? {
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
            return .connect(host: "wss://localhost:8080")
        case .subscribeChat:
            return .subscribe()
        case .sendMessage:
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
<br/>

## Usage - Provider

Declare a `StompProvider` that takes the enum implementing `EntryType` as a generic parameter.

```swift
let provider = StompProvider<ChatEntry>()
```

You can send requests using the `request` method. By defining the response type with the `of` parameter, the provider decodes and delivers it through the `success` parameter. For more details, refer to [`STOMPProviderProtocol`](https://github.com/dodo849/Stomper/blob/main/Sources/Stomper/Stomp%2BStructure/StompProviderProtocol.swift).

```swift
provider.request(
    of: String.self,
    entry: .connect
) { [weak self] result in
    switch result {
    case .failure(let error):
        // Handle failure
    case .success(_):
        // Handle success
    }
}
```
<br/>

## Additional Configuration - Interceptor

`Stomper` provides the `Interceptor` feature to add logic before and after communication.

Declare a structure that adopts the `Interceptor` protocol to implement common logic before and after sending messages.
- **execute**: Method executed before sending a specific message.
- **retry**: Method to set retry logic and preprocessing when receiving an error frame from the server.
  - `retry(count:delay:)`: Set the number of retries and the delay in seconds before retrying.
  - `doNotRetry`: Do not retry on failure.
  - `doNotRetryWithError`: Do not retry and deliver an error.

⚠️ **Retry Warning**: On retry, the socket connection is retried from the beginning, and additional frames are sent to restore existing subscriptions. The failed frame is also resent afterward. However, if the error frame lacks a `receipt-id`, the failed frame will not be resent.

```swift
struct StompTokenInterceptor: Interceptor {
    func execute(
        message: StompRequestMessage,
        completion: @escaping (StompRequestMessage) -> Void
    ) {
        let accessToken = tokenRepository.getAccessToken()
        message.headers.addHeader(key: "Authorization", value: "Bearer \(accessToken)")
        completion(message)
    }
    
    func retry(
        message: StompRequestMessage,
        errorMessage: StompReceiveMessage,
        completion: @escaping (StompRequestMessage, InterceptorRetryType) -> Void
    ) {
        Task {
            do {
                let accessToken = try await tokenRepository.fetchNewAccessToken()
                var updatedMessage = message
                updatedMessage.headers.addHeader(key: "Authorization", value: "Bearer \(accessToken)")
                completion(updatedMessage, .retry(count: 3, delay: 2.0))
            } catch {
                // Fail to get new access token
                let tokenError = TokenError.failedFetchNewAccessToken(
                    accessToken: tokenRepository.getAccessToken(),
                    refreshToken: tokenRepository.getRefreshToken()
                )
                completion(message, .doNotRetryWithError(tokenError))
            }
        }
    }
}
```

You can set the interceptor by chaining it to the provider.

```swift
private let provider = StompProvider<ChatEntry>()
    .intercepted(StompTokenInterceptor())
```

If you want to set multiple interceptors, refer to [`MultiInterceptor`](https://github.com/dodo849/Stomper/blob/main/Sources/Stomper/Stomp%2BBasic/Interceptor/MultiInterceptor.swift).
<br/>

## Logging Configuration

Enable logging to view meaningful debugging information at the socket level in the console. It uses OSLog.

```swift
private let provider = StompProvider<ChatEntry>()
    .enableLogging()
```

With this guide, you are now ready to set up and use STOMP communication effectively. You can add appropriate interceptors and logging features to enhance the reliability and debugging efficiency of your communication.
