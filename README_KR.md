# Stomper
![iOS badge](https://img.shields.io/badge/iOS-14.0%2B-black)
![macOS badge](https://img.shields.io/badge/macOS-11.0%2B-black)
![tvOS badge](https://img.shields.io/badge/tvOS-14.0%2B-black)
![watchOS badge](https://img.shields.io/badge/watchOS-7.0%2B-black)
---

#### 안정화중입니다...🙇
---
STOMP에 대한 자세한 사항은 [STOMP 명세](https://stomp.github.io/stomp-specification-1.2.html)를 참고하세요.
<br/><br/>

## 설치
### 1. Swift Package Manager (SPM) 사용
SPM을 사용하여 패키지를 설치하려면 Package.swift 파일에 의존성을 추가합니다.
```swift
.package(url: "https://github.com/dodo849/Stomper", from: "0.6.0")
```
### 2. Xcode에서 패키지 추가
1. Xcode 프로젝트를 엽니다.
2. 프로젝트 탐색기에서 프로젝트 파일을 선택합니다.
3. "Swift Packages" 탭을 클릭합니다.
4. "Add Package Dependency" 버튼을 클릭합니다.
5. GitHub 또는 다른 저장소 URL을 입력하고, 다음 단계를 진행하여 원하는 버전을 선택합니다.
6. 패키지를 추가하면 Xcode가 자동으로 의존성을 다운로드하고 프로젝트에 통합합니다.
<br/>


패키지 설치가 완료되면 import 구문을 사용하여 프로젝트에서 해당 라이브러리를 사용할 수 있습니다.
```swift
import Stomper
```
<br/>

## 준비단계 - EntryType

`EntryType`을 상속하여 통신에 대한 명세를 관리할 수 있습니다. 먼저 enum에 통신에 대한 명칭을 열거하고, 연관값을 이용해 통신에 필요한 인자를 받습니다. 그런 다음 `EntryType`을 상속하고 통신에 필요한 `baseURL`, `topic`, `command`, `body`, `additionalHeaders`를 정의합니다.

#### **baseURL**
> 서버의 주소입니다. `ws` 또는 `wss`로 시작합니다.
#### **topic**
> STOMP 통신에서 `destination`에 해당하는 path입니다. 필요하지 않다면 `nil`을 사용하세요.
#### **command**
> 어떤 STOMP 명령을 사용할지 정의합니다. 각 명령에는 STOMP 명세에 정의된 필수 헤더를 연관값으로 전달할 수 있습니다.
- 자세한 커맨드 종류와 헤더는 [`EntryCommand`](https://github.com/dodo849/Stomper/blob/main/Sources/Stomper/Stomp%2BStructure/EntryCommand.swift)를 참고하세요.
#### **body**
> body에 들어가는 정보가 있다면 디코드 명세와 함께 인자를 전달합니다.
- `.none`: Body가 없을 경우
- `.withPlain`: 단순 String
- `.withData`: Data 형 정보
- `.withJSON`: JSON 정보. `Encodable` 객체를 받습니다.
- `.withCustomJSONE`: 기본적인 `JSONEncoder` 외의 인코더가 필요할 때 사용합니다. `Encodable` 객체와 `Encoder`를 받습니다.
- `.withParameters`: key-value 형태의 인자를 넘길 때 사용합니다. body에 들어갈 수 있도록 Data 형으로 변환하는 특수한 인코더가 필요합니다.
#### **additionalHeaders**
> STOMP 명세 외에 특수한 헤더가 필요하다면 사용합니다. 만약 STOMP 명세와 겹치게 된다면 additionalHeaders가 우선됩니다.

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

## 사용단계 - Provider

`EntryType`을 구현한 열거형을 제네릭으로 받는 `StompProvider`를 선언하세요.

```swift
let provider = StompProvider<ChatEntry>()
```

`request` 메서드를 통해 요청을 보낼 수 있습니다. `of` 인자로 응답받을 타입을 정의하면 provider가 디코드 후 `success` 인자로 전달합니다. 
자세한 사항은 [`STOMPProviderProtocol`](https://github.com/dodo849/Stomper/blob/main/Sources/Stomper/Stomp%2BStructure/StompProviderProtocol.swift)을 참고하세요.

```swift
provider.request(
    of: String.self,
    entry: .connect
) { [weak self] result in
    switch result {
    case .failure(let error):
        // 실패 처리
    case .success(_):
        // 성공 처리
    }
}
```
<br/>

## 추가 설정 - Interceptor

`Stomper`는 통신 전후로 로직을 추가할 수 있는 `Interceptor` 기능을 제공합니다.

`Interceptor`를 채택하는 구조체를 선언해 로직 전후의 공통적인 로직을 구현할 수 있습니다.
- **execute**: 특정 메시지를 보내기 전 실행되는 메서드입니다.
- **retry**: 서버에서 Error frame을 수신했을 때 재시도 여부와 전처리 로직을 설정하는 메서드입니다.
  - `retry(count:delay:)`: 재시도할 횟수와 몇 초 후 재시도할지 설정할 수 있습니다.
  - `doNotRetry`: 실패 시 재시도하지 않습니다.
  - `doNotRetryWithError`: 에러를 전달하며 재시도하지 않습니다.

⚠️ **재시도 주의사항**: 재시도 시 소켓 연결부터 다시 시도되며, 기존에 `subscribe`를 복구하기 위한 프레임을 추가로 전송합니다. 또한 이후 실패한 프레임을 다시 전송합니다. 단, 이때 `receipt-id`가 없는 error frame이라면 실패한 프레임 전송은 진행되지 않습니다.

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

사용할 provider에 인터셉터를 체이닝하여 설정할 수 있습니다.

```swift
private let provider = StompProvider<ChatEntry>()
    .intercepted(StompTokenInterceptor())
```

여러 개의 인터셉터를 설정하고 싶다면 [`MultiInterceptor`](https://github.com/dodo849/Stomper/blob/main/Sources/Stomper/Stomp%2BBasic/Interceptor/MultiInterceptor.swift)를 참고하세요.
<br/>


## 로깅 설정

로깅 설정을 통해 소켓 레벨에서 유의미한 디버깅 정보를 콘솔로 확인할 수 있습니다. OSLog를 사용합니다.

```swift
private let provider = StompProvider<ChatEntry>()
    .enableLogging()
```
