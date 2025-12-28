import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    
    private init() {}
    
    var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        // Apply Proxy Settings
        if UserDefaults.standard.bool(forKey: "proxyEnabled") {
            var proxyDict: [AnyHashable: Any] = [:]
            
            if let host = UserDefaults.standard.string(forKey: "proxyHost"), !host.isEmpty {
                proxyDict[kCFNetworkProxiesHTTPEnable] = 1
                proxyDict[kCFNetworkProxiesHTTPProxy] = host
                proxyDict[kCFNetworkProxiesHTTPPort] = Int(UserDefaults.standard.string(forKey: "proxyPort") ?? "8080") ?? 8080
                
                #if !os(tvOS)
                proxyDict[kCFNetworkProxiesHTTPSEnable] = 1
                proxyDict[kCFNetworkProxiesHTTPSProxy] = host
                proxyDict[kCFNetworkProxiesHTTPSPort] = Int(UserDefaults.standard.string(forKey: "proxyPort") ?? "8080") ?? 8080
                #endif
            }
            
            config.connectionProxyDictionary = proxyDict
        }
        
        return URLSession(configuration: config)
    }
}
