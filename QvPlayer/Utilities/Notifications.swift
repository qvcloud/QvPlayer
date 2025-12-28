import Foundation

extension Notification.Name {
    static let commandPlay = Notification.Name("commandPlay")
    static let commandPause = Notification.Name("commandPause")
    static let commandToggle = Notification.Name("commandToggle")
    static let commandSeek = Notification.Name("commandSeek") // UserInfo: ["seconds": Double]
    static let commandSeekTo = Notification.Name("commandSeekTo") // UserInfo: ["time": Double]
    static let commandPlayVideo = Notification.Name("commandPlayVideo") // UserInfo: ["index": Int]
    static let commandSelectAudioTrack = Notification.Name("commandSelectAudioTrack") // UserInfo: ["trackId": String]
    static let commandSetPlaybackRate = Notification.Name("commandSetPlaybackRate") // UserInfo: ["rate": Float]
    static let playerStatusDidUpdate = Notification.Name("playerStatusDidUpdate") // UserInfo: ["status": [String: Any]]
    static let playerTracksDidUpdate = Notification.Name("playerTracksDidUpdate") // UserInfo: ["audioTracks": [String], "currentAudioTrack": String]
    static let playerDidFinishPlaying = Notification.Name("playerDidFinishPlaying")
}
