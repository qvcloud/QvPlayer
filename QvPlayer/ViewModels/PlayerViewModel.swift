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
    private var observers: [NSObjectProtocol] = []
    
    deinit {
        print("🗑 [PlayerViewModel] Deinit")
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        statusTimer?.invalidate()
        timeControlStatusObserver?.invalidate()
        rateObserver?.invalidate()
        itemStatusObserver?.invalidate()
        waitingReasonObserver?.invalidate()
    }
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    private func setupAudioSession() {
        // Setup audio session for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ [AudioSession] Failed to setup: \(error)")
            DebugLogger.shared.error("[AudioSession] Failed to setup: \(error)")
        }
    }
    
    private func setupRemoteCommands() {
        let center = NotificationCenter.default
        
        observers.append(center.addObserver(forName: .commandPlay, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.player != nil else { return }
                self.play()
            }
        })
        
        observers.append(center.addObserver(forName: .commandPause, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.player != nil else { return }
                self.pause()
            }
        })
        
        observers.append(center.addObserver(forName: .commandToggle, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.player != nil else { return }
                self.togglePlayPause()
            }
        })
        
        observers.append(center.addObserver(forName: .commandSeek, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor in
                guard let self = self, self.player != nil else { return }
                if let seconds = notification.userInfo?["seconds"] as? Double {
                    self.seek(by: seconds)
                }
            }
        })
    }
    
    func load(video: Video) {
        setupAudioSession() // Ensure session is active
        print("🎬 [Player] Loading video: \(video.title) - \(video.url)")
        DebugLogger.shared.info("Loading video: \(video.title)")
        self.errorMessage = nil
        
        // Use cached URL if available
        let playURL = video.cachedURL ?? video.url
        print("📂 [Player] Playing from: \(playURL)")
        DebugLogger.shared.info("Playing from: \(playURL.lastPathComponent)")
        
        // Update Debug Stats URL
        var stats = DebugLogger.shared.videoStats
        stats.url = playURL.absoluteString
        DebugLogger.shared.videoStats = stats
        
        let unsupportedExtensions = ["mkv", "avi", "flv", "wmv", "rmvb", "webm"]
        if playURL.pathExtension.lowercased() != "" && unsupportedExtensions.contains(playURL.pathExtension.lowercased()) {
            let msg = "⚠️ Format '.\(playURL.pathExtension)' is not supported by native player."
            print(msg)
            DebugLogger.shared.warning(msg)
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
                DebugLogger.shared.error("[Player Error] \(log.errorDomain): \(log.errorComment ?? "Unknown error")")
            }
        }
        
        // Add Access Log Observer (Connection status)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemNewAccessLogEntry, object: playerItem, queue: .main) { notification in
            if let item = notification.object as? AVPlayerItem, let log = item.accessLog()?.events.last {
                print("📡 [Player Access] URI: \(log.uri ?? "nil") | IP: \(log.serverAddress ?? "nil") | Bitrate: \(log.indicatedBitrate)")
            }
        }
        
        // Observe Item Status
        itemStatusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            guard let self = self else { return }
            switch item.status {
            case .readyToPlay:
                print("✅ [Player Status] Ready to play")
                DebugLogger.shared.info("Player Status: Ready to play")
                
                Task {
                    do {
                        let videoTracks = try await item.asset.loadTracks(withMediaType: .video)
                        if let track = videoTracks.first {
                            print("📹 [Player] Video track found: \(track)")
                            
                            // Log Codec Info
                            let formatDescriptions = try await track.load(.formatDescriptions)
                            for format in formatDescriptions {
                                let mediaSubType = CMFormatDescriptionGetMediaSubType(format)
                                let codecString =  String(format: "%c%c%c%c",
                                                          (mediaSubType >> 24) & 0xff,
                                                          (mediaSubType >> 16) & 0xff,
                                                          (mediaSubType >> 8) & 0xff,
                                                          mediaSubType & 0xff)
                                print("   Codec: \(codecString)")
                                DebugLogger.shared.info("Video Codec: \(codecString)")
                                
                                // Check for AV1 (av01) which might not be supported by AVPlayer on all devices
                                if codecString == "av01" {
                                    let msg = "⚠️ AV1 Codec detected. System player may not support video. Please switch to KSPlayer."
                                    print(msg)
                                    DebugLogger.shared.warning(msg)
                                    await MainActor.run {
                                        self.errorMessage = msg
                                    }
                                }
                            }
                            
                            let isEnabled = try await track.load(.isEnabled)
                            let isSelfContained = try await track.load(.isSelfContained)
                            let estimatedDataRate = try await track.load(.estimatedDataRate)
                            
                            print("   Enabled: \(isEnabled)")
                            print("   Self Contained: \(isSelfContained)")
                            print("   Estimated Data Rate: \(estimatedDataRate)")
                            
                            // Check presentation size
                            print("   Presentation Size: \(item.presentationSize)")
                            if item.presentationSize == .zero {
                                DebugLogger.shared.warning("Player ready but presentation size is zero!")
                            }
                        } else {
                            print("⚠️ [Player] No video track found!")
                            DebugLogger.shared.warning("No video track found!")
                        }
                    } catch {
                        print("❌ [Player] Failed to load tracks: \(error)")
                    }
                }
            case .failed:
                if let error = item.error {
                    print("❌ [Player Status] Failed: \(error.localizedDescription)")
                    DebugLogger.shared.error("Player Status Failed: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.errorMessage = "Playback Failed: \(error.localizedDescription)"
                    }
                }
            case .unknown:
                print("❓ [Player Status] Unknown")
                DebugLogger.shared.warning("Player Status: Unknown")
            @unknown default:
                break
            }
        }
        
        if let player = self.player {
            player.replaceCurrentItem(with: playerItem)
        } else {
            self.player = AVPlayer(playerItem: playerItem)
        }
        
        // Ensure player is not muted and volume is up
        self.player?.isMuted = false
        self.player?.volume = 1.0
        
        // Observe buffering status
        timeControlStatusObserver = player?.observe(\.timeControlStatus) { [weak self] player, _ in
            Task { @MainActor in
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                
                switch player.timeControlStatus {
                case .waitingToPlayAtSpecifiedRate:
                    let reason = player.reasonForWaitingToPlay?.rawValue ?? "Unknown"
                    print("⏳ [Player] Buffering... Reason: \(reason)")
                    DebugLogger.shared.info("Buffering... Reason: \(reason)")
                case .paused:
                    print("⏸ [Player] Paused")
                    DebugLogger.shared.info("Player Paused")
                case .playing:
                    print("▶️ [Player] Playing")
                    DebugLogger.shared.info("Player Playing")
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
    
    func stop() {
        pause()
        player = nil
        statusTimer?.invalidate()
        statusTimer = nil
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
}
