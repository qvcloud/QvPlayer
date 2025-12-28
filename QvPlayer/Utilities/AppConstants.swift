import Foundation
import UIKit

struct AppConstants {
    static let defaultPlayerEngine = "ksplayer"
    static let defaultWebServerPort = 12345
    
    static var defaultUserAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let systemName = UIDevice.current.systemName
        return "QvPlayer/\(version)(\(systemName))"
    }
}
