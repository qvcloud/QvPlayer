import Foundation
import AVKit
import Combine
import CoreMedia

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false {
        didSet {
            broadcastStatus()
        }
    }
    @Published var isBuffering: Bool = false
    @Published var currentVideo: Video?
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var waitingReasonObserver: NSKeyValueObservation?
    private var statusTimer: Timer?
    
    init() {
        // Setup audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [AudioSession] Failed to setup: \(error)")
        }
        setupRemoteCommands()
    }
    
    private func setupRemoteCommands() {
        NotificationCenter.default.addObserver(forName: .commandPlay, object: nil, queue: .main) { [weak self] _ in
            self?.play()
        }
        
        NotificationCenter.default.addObserver(forName: .commandPause, object: nil, queue: .main) { [weak self] _ in
            self?.pause()
        }
        
        NotificationCenter.default.addObserver(forName: .commandToggle, object: nil, queue: .main) { [weak self] _ in
            self?.togglePlayPause()
        }
        
        NotificationCenter.default.addObserver(forName: .commandSeek, object: nil, queue: .main) { [weak self] notification in
            if let seconds = notification.userInfo?["seconds"] as? Double {
                self?.seek(by: seconds)
            }
        }
    }
    
    func load(video: Video) {
        print("🎬 [Player] Loading video: \(video.title) - \(video.url)")
        self.errorMessage = nil
        
        // Use cached URL if available
        let playURL = video.cachedURL ?? video.url
        print("📂 [Player] Playing from: \(playURL)")
        
        let unsupportedExtensions = ["mkv", "avi", "flv", "wmv", "rmvb", "webm"]
        if playURL.pathExtension.lowercased() != "" && unsupportedExtensions.contains(playURL.pathExtension.lowercased()) {
            let msg = "⚠️ Format '.\(playURL.pathExtension)' is not supported by native player."
            print(msg)
            self.errorMessage = msg
        }
        
        self.currentVideo = video
        let playerItem = AVPlayerItem(url: playURL)
        
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
                
                switch player.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate:
                    print("⏳ [Player] Buffering... Reason: \(player.reasonForWaitingToPlay?.rawValue ?? "Unknown")")
                case .paused:
                    print("⏸ [Player] Paused")
                case .playing:
                    print("▶️ [Player] Playing")
                @unknown default:
                    break
                }
            }
        }
        
        // Observe waiting reason
        waitingReasonObserver = player?.observe(\.reasonForWaitingToPlay) { player, _ in
            if let reason = player.reasonForWaitingToPlay {
                print("🤔 [Player] Waiting reason changed: \(reason.rawValue)")
            }
        }
        
        // Observe playback rate to sync isPlaying state
        rateObserver = player?.observe(\.rate) { [weak self] player, _ in
            Task { @MainActor in
                print("📉 [Player] Rate changed to: \(player.rate)")
                self?.isPlaying = player.rate != 0
            }
        }
        
        // Auto play on load
        play()
        startStatusBroadcasting()
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
    
    private func startStatusBroadcasting() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.broadcastStatus()
            }
        }
    }
    
    private func broadcastStatus() {
        let duration = player?.currentItem?.duration.seconds ?? 0
        let status: [String: Any] = [
            "isPlaying": isPlaying,
            "title": currentVideo?.title ?? "Idle",
            "currentTime": player?.currentTime().seconds ?? 0,
            "duration": duration.isNaN ? 0 : duration
        ]
        NotificationCenter.default.post(name: .playerStatusDidUpdate, object: nil, userInfo: ["status": status])
    }
    
    deinit {
        statusTimer?.invalidate()
    }
}
