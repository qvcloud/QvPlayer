import Foundation

extension Notification.Name {
    static let commandPlay = Notification.Name("commandPlay")
    static let commandPause = Notification.Name("commandPause")
    static let commandToggle = Notification.Name("commandToggle")
    static let commandSeek = Notification.Name("commandSeek") // UserInfo: ["seconds": Double]
    static let commandSeekTo = Notification.Name("commandSeekTo") // UserInfo: ["time": Double]
    static let commandPlayVideo = Notification.Name("commandPlayVideo") // UserInfo: ["index": Int]
    static let playerStatusDidUpdate = Notification.Name("playerStatusDidUpdate") // UserInfo: ["status": [String: Any]]
    static let playerDidFinishPlaying = Notification.Name("playerDidFinishPlaying")
}
