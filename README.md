# GithubUserProfile
- Navigation Controller
- UISearchController
- Combine
- Kingfisher
- Xcode Package Manager

## 🍎 작동 화면


| 작동 화면 |
|:-:|
|![](https://i.imgur.com/RsBOodO.gif)|


## 🍎 코드 분석
### 앱의 가장 중심이 되는 UserProfileViewController
```swift
import UIKit
import Combine
import Kingfisher

class UserProfileViewController: UIViewController {
    @Published private(set) var user: UserProfile? 
    // bind 메서드에서 sink로 받아 업데이트를 할 수 있게 만드는 객체.
    // @Published를 붙여 퍼블리셔의 역할을 할 수 있게 함.
    
    var subscriptions = Set<AnyCancellable>()      // subscription을 보관하는 공간
    
    var network = NetworkService(configuration: .default)    // 네트워크 서비스 객체
    
    @IBOutlet weak var thumbnail: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var loginLabel: UILabel!
    @IBOutlet weak var followerLabel: UILabel!
    @IBOutlet weak var followingLabel: UILabel!
    @IBOutlet weak var firstDateLabel: UILabel!
    @IBOutlet weak var latestUpdateLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        embendSearchControl()
        bind()
    }

    // setupUI
    private func setupUI() {
        thumbnail.layer.cornerRadius = 80    // 원래 이미지 사이즈 = 160 x 160.
                                             // 반 사이즈로 깎아서 둥글게함
    }
    
    // search control 추가
    private func embendSearchControl() {
        self.navigationItem.title = "Search"
        
        let searchController = UISearchController(searchResultsController: nil)
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "kayahn0126"    // 도움말 (바탕에 보이는 문장)
        searchController.searchResultsUpdater = self             // 입력될때마다 업데이트되는곳
        searchController.searchBar.delegate = self               // 여기서는 아이폰 키보드에서 search를 눌렀을떄 어떤 동작이 실행될수 있도록 역할 delegate
        self.navigationItem.searchController = searchController
    }
    
    // bind
    private func bind() {                        // 파이프라인 생성 (캔슬되기 전까지 유지)
        $user                            
            .receive(on: RunLoop.main)           // subscriber가 어디서 수행할지 정하는 스케쥴러
            .sink { [unowned self] result in     // UserProfile을 받아,
                self.update(result)              // 현재 클래스 내 메서드를 통해 업데이트
            }.store(in: &subscriptions)
    }
    
    private func update(_ user: UserProfile?) {
        guard let user = user else {
            self.nameLabel.text = "Name : "
            self.loginLabel.text = "Github id : "
            self.followerLabel.text = "followers : 0"
            self.followingLabel.text = "following : 0"
            self.firstDateLabel.text = "first date : yesterday"
            self.latestUpdateLabel.text = "latest update : today"
            self.thumbnail.image = nil
            return
        }
        self.nameLabel.text = "Name : " + user.name
        self.loginLabel.text = "Github id : " + user.login
        self.followerLabel.text = "followers : \(user.followers)"
        self.followingLabel.text = "following : \(user.following)"
        self.firstDateLabel.text = "first date : \(user.firstDate)"
        self.latestUpdateLabel.text = "latest update : \(user.latestupdateDate)"
        self.thumbnail.kf.setImage(with: user.avatarUrl) // kingfisher 사용
        // kingfisher = 고유의 URL 주소를 가지고 있는 이미지를 앱 내에서 보여지게 해주는 라이브러리


    }
}

// 서치 컨트롤러에 무언가 입력되면 계속 업데이트하는 메서드
extension UserProfileViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let keyword = searchController.searchBar.text
        print("search: \(keyword)")
    }
}

extension UserProfileViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        print("button clicked: \(searchBar.text)")
        
        guard let keyword = searchBar.text, !keyword.isEmpty else { return }
        
        //Resource
        let resource = Resource<UserProfile>(        // struct Resource<T> where T : Decodable
            base: "https://api.github.com/",
            path: "users/\(keyword)",
            params: [:],
            header: ["Content-Type": "application/json"]
        )
        
        // Network Service
        network.load(resource)
            .receive(on: RunLoop.main) //subscriber를 main 스레드에서 실행.
            .sink { completion in
                switch completion {    // 에러 또는 성공적으로 종료 될 수 있다. 어쨌든 종료가 되면 불리는 클로져
                case.failure(let error):
                    self.user = nil
                    print("Error Code : \(error)")
                case.finished :
                    print("Completed : \(completion)")
                    break
                }
            } receiveValue: { value in
                self.user = value
            }.store(in: &subscriptions)
    }
}
```

### Resource를 구성해 Network하기
```swift
//  Resource.swift

import Foundation

struct Resource<T: Decodable> {        // Decodable 프로토콜을 준수하는 T타입
    var base: String
    var path: String
    var params: [String: String]
    var header: [String: String]
    
    var urlRequest: URLRequest? {
        var urlComponents = URLComponents(string: base + path)!
        let queryItems = params.map { (key: String, value: String) in
            URLQueryItem(name: key, value: value)
        }
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        header.forEach { (key: String, value: String) in
            request.addValue(value, forHTTPHeaderField: key)
        }
        return request
    }
    
    init(base: String, path: String, params: [String: String] = [:], header: [String: String] = [:]) {
        self.base = base
        self.path = path
        self.params = params
        self.header = header
    }
}
```

### 구성한 Resource를 활용해 실제로 Network 하기
```swift
//  Network.swift

import Foundation
import Combine

///// Defines the Network service errors.
enum NetworkError: Error {
    case invalidRequest
    case invalidResponse
    case responseError(statusCode: Int)
    case jsonDecodingError(error: Error)
}

final class NetworkService {
    let session: URLSession
    
    init(configuration: URLSessionConfiguration) {
        session = URLSession(configuration: configuration)
    }
    
    func load<T>(_ resource: Resource<T>) -> AnyPublisher<T, Error> {
        guard let request = resource.urlRequest else {
            return .fail(NetworkError.invalidRequest)
        }
        
        return session
            .dataTaskPublisher(for: request)
            .tryMap { result -> Data in
                guard let response = result.response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode)
                else {
                    let response = result.response as? HTTPURLResponse
                    let statusCode = response?.statusCode ?? -1
                    throw NetworkError.responseError(statusCode: statusCode)
                }
                return result.data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
```

## 🍎 네트워크를 담당하는 NetworkService 클래스에서 eraseToAnyPublisher()는 무엇일까?
- tryMap함수 내부는 아래와 같이 생겼다
```swift
func tryMap<T>(_ transform: @escaping ((data: Data, response: URLResponse)) throws -> T) -> Publishers.TryMap<URLSession.DataTaskPublisher, T>
```
- 즉 반환형이 Publishers.TryMap<URLSession.DataTaskPublisher, T>라는 것인데 eraseToAnyPublisher함수를 사용하게 되면 tryMap을 거치고 나온 반환형을 AnyPublisher< ~ , ~> 형태로 바꿔준다.
```swift
let x = PassthroughSubject<String, Never>()
//////////생략
}.eraseToAnyPublisher()
// 이제 x는 AnyPublisher<String, Never>
```
- Operation에서의 데이터를 처리할 땐 Operation 상호 간 에러 처리나 혹은 스트림 제어를 위해서 데이터 형식을 알아야 하지만 Subscrbier에게 전달될 땐 필요가 없게 됩니다. 따라서 최종적인 형태로 데이터를 전달할 땐 eraseToAnyPublisher를 사용하게 됩니다.[출처](https://medium.com/harrythegreat/swift-combine-%EC%9E%85%EB%AC%B8%ED%95%98%EA%B8%B03-%EB%84%A4%ED%8A%B8%EC%9B%8C%ED%81%AC%EC%9A%94%EC%B2%AD-f36d6a32af14)

## 🍎 보충해야 할 점.
- combine과 network가 같이 나와 많이 헷갈리지만 더 공부하기 (천천히, 더 많이!)
