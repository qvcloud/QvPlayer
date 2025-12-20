import Foundation
import AVKit
import Combine
import CoreMedia

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentVideo: Video?
    
    private var cancellables = Set<AnyCancellable>()
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    
    init() {
        // Setup audio session for playback if needed (more relevant for iOS but good practice)
        // For tvOS, AVPlayer handles most things automatically.
    }
    
    func load(video: Video) {
        print("🎬 [Player] Loading video: \(video.title) - \(video.url)")
        self.currentVideo = video
        let playerItem = AVPlayerItem(url: video.url)
        
        // Set external metadata for tvOS Info Panel
        var metadata: [AVMetadataItem] = []
        
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = video.title as NSString
        titleItem.extendedLanguageTag = "und"
        metadata.append(titleItem)
        
        if let desc = video.description {
            let descItem = AVMutableMetadataItem()
            descItem.identifier = .commonIdentifierDescription
            descItem.value = desc as NSString
            descItem.extendedLanguageTag = "und"
            metadata.append(descItem)
        }
        
        playerItem.externalMetadata = metadata
        
        // Add Error Log Observer
        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: playerItem, queue: .main) { notification in
            if let item = notification.object as? AVPlayerItem, let log = item.errorLog()?.events.last {
                print("❌ [Player Error] \(log.errorDomain): \(log.errorComment ?? "Unknown error")")
            }
        }
        
        // Add Access Log Observer (Connection status)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewAccessLogEntry, object: playerItem, queue: .main) { notification in
            if let item = notification.object as? AVPlayerItem, let log = item.accessLog()?.events.last {
                print("📡 [Player Access] URI: \(log.uri ?? "nil") | IP: \(log.serverAddress ?? "nil") | Bitrate: \(log.indicatedBitrate)")
            }
        }
        
        // Observe Item Status
        itemStatusObserver = playerItem.observe(\.status) { item, _ in
            switch item.status {
            case .readyToPlay:
                print("✅ [Player Status] Ready to play")
            case .failed:
                if let error = item.error {
                    print("❌ [Player Status] Failed: \(error.localizedDescription)")
                }
            case .unknown:
                print("❓ [Player Status] Unknown")
            @unknown default:
                break
            }
        }
        
        if let player = self.player {
            player.replaceCurrentItem(with: playerItem)
        } else {
            self.player = AVPlayer(playerItem: playerItem)
        }
        
        // Observe buffering status
        timeControlStatusObserver = player?.observe(\.timeControlStatus) { [weak self] player, _ in
            Task { @MainActor in
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
        
        // Observe playback rate to sync isPlaying state
        rateObserver = player?.observe(\.rate) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.rate != 0
            }
        }
        
        // Auto play on load
        play()
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(by seconds: Double) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
        player.seek(to: newTime)
    }
}
