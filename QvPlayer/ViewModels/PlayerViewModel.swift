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
    @Published var playbackRate: Float = 1.0
    
    // Audio Tracks
    @Published var audioTracks: [String] = []
    @Published var currentAudioTrack: String?
    
    // Source Switching Overlay
    @Published var sourceList: [Video] = []
    @Published var showSourceList: Bool = false
    @Published var highlightedVideo: Video?
    private var sourceListTimer: Timer?
    private var switchSourceDebounceTimer: Timer?
    
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
    
    func stop() {
        pause()
        // Broadcast final stopped status
        broadcastStatus()
        
        player = nil
        statusTimer?.invalidate()
        statusTimer = nil
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
        
        observers.append(center.addObserver(forName: .commandSetPlaybackRate, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor in
                guard let self = self else { return }
                if let rate = notification.userInfo?["rate"] as? Float {
                    self.setPlaybackRate(rate)
                }
            }
        })
        
        observers.append(center.addObserver(forName: .playerTracksDidUpdate, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor in
                guard let self = self else { return }
                if let tracks = notification.userInfo?["audioTracks"] as? [String] {
                    // Only update if changed to avoid loops or unnecessary updates
                    if self.audioTracks != tracks {
                        self.audioTracks = tracks
                    }
                }
                if let current = notification.userInfo?["currentAudioTrack"] as? String {
                    if self.currentAudioTrack != current {
                        self.currentAudioTrack = current
                    }
                }
            }
        })
        
        observers.append(center.addObserver(forName: .commandSeekTo, object: nil, queue: .main) { [weak self] notification in
            Task { @MainActor in
                guard let self = self, self.player != nil else { return }
                if let time = notification.userInfo?["time"] as? Double {
                    self.seek(to: time)
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
        var playURL = video.cachedURL ?? video.url
        
        // Safety check: Resolve localcache:// scheme if it wasn't resolved earlier
        if playURL.scheme == "localcache" {
            // Try to extract filename from host or path
            let rawFilename = playURL.host ?? playURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !rawFilename.isEmpty, let filename = rawFilename.removingPercentEncoding {
                let fileURL = CacheManager.shared.getFileURL(filename: filename)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    playURL = fileURL
                    print("✅ [Player] Resolved localcache:// to \(playURL.path)")
                } else {
                    print("❌ [Player] Failed to resolve localcache:// - File not found: \(filename)")
                }
            }
        }
        
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
        
        // Check Player Engine
        let engine = UserDefaults.standard.string(forKey: "playerEngine") ?? "system"
        if engine == "ksplayer" {
            // If using KSPlayer, we don't need to setup AVPlayer here.
            // Just stop any existing system player to avoid double audio.
            self.player?.pause()
            self.player = nil
            return
        }
        
        // Configure User-Agent if set
        let userAgent = DatabaseManager.shared.getConfig(key: "user_agent")
        var asset: AVURLAsset
        if let ua = userAgent, !ua.isEmpty {
            let options = ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": ua]]
            asset = AVURLAsset(url: playURL, options: options)
            DebugLogger.shared.info("Using custom User-Agent: \(ua)")
        } else {
            asset = AVURLAsset(url: playURL)
        }
        
        let playerItem = AVPlayerItem(asset: asset)
        
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
        
        // Add Playback Finished Observer
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            print("🏁 [Player] Playback finished")
            NotificationCenter.default.post(name: .playerDidFinishPlaying, object: nil)
        }
        
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
                let isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self?.isBuffering = isBuffering
                
                // Notify SpeedTestManager
                NotificationCenter.default.post(name: Notification.Name("playerIsBuffering"), object: nil, userInfo: ["isBuffering": isBuffering])
                
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
                    
                    var stats = DebugLogger.shared.videoStats
                    stats.status = "Online"
                    
                    // Update Server Address from Access Log
                    if let event = player.currentItem?.accessLog()?.events.last {
                        stats.serverAddress = event.serverAddress ?? "-"
                    }
                    
                    if stats.serverAddress == "-" || stats.serverAddress.isEmpty {
                        if let url = (player.currentItem?.asset as? AVURLAsset)?.url, url.isFileURL {
                            stats.serverAddress = "Local"
                        }
                    }
                    
                    DebugLogger.shared.videoStats = stats
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
        let engine = UserDefaults.standard.string(forKey: "playerEngine") ?? "system"
        if engine == "ksplayer" { return }
        
        player?.rate = playbackRate
        isPlaying = true
    }
    
    func setPlaybackRate(_ rate: Float) {
        print("⏩ [PlayerViewModel] Setting playback rate: \(rate)")
        self.playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
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
    
    func selectAudioTrack(_ trackId: String) {
        print("🔊 [PlayerViewModel] Selecting audio track: \(trackId)")
        NotificationCenter.default.post(name: .commandSelectAudioTrack, object: nil, userInfo: ["trackId": trackId])
    }
    
    func seek(by seconds: Double) {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let newTime = CMTimeAdd(currentTime, CMTimeMakeWithSeconds(seconds, preferredTimescale: 600))
        player.seek(to: newTime)
    }
    
    func seek(to time: Double) {
        guard let player = player else { return }
        let newTime = CMTimeMakeWithSeconds(time, preferredTimescale: 600)
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
        
        var serverAddress = "-"
        if let event = player?.currentItem?.accessLog()?.events.last {
            serverAddress = event.serverAddress ?? "-"
        }
        
        if serverAddress == "-" || serverAddress.isEmpty {
            if let url = (player?.currentItem?.asset as? AVURLAsset)?.url, url.isFileURL {
                serverAddress = "Local"
            }
        }
        
        let currentTime = player?.currentTime().seconds ?? 0
        
        let status: [String: Any] = [
            "isPlaying": isPlaying,
            "title": currentVideo?.title ?? "Idle",
            "tvgName": currentVideo?.tvgName ?? "",
            "id": currentVideo?.id.uuidString ?? "",
            "currentTime": currentTime.isNaN ? 0 : currentTime,
            "duration": duration.isNaN ? 0 : duration,
            "serverAddress": serverAddress,
            "isOnline": isPlaying // Simple approximation for System Player
        ]
        NotificationCenter.default.post(name: .playerStatusDidUpdate, object: nil, userInfo: ["status": status])
    }
    
    func switchChannel(direction: Int) {
        guard let currentVideo = self.currentVideo, let tvgName = currentVideo.tvgName else { return }
        
        Task.detached {
            if let nextVideo = DatabaseManager.shared.getAdjacentChannel(currentTvgName: tvgName, offset: direction) {
                await MainActor.run {
                    DebugLogger.shared.info("Switching Channel to: \(nextVideo.tvgName ?? nextVideo.title)")
                    self.load(video: nextVideo)
                    self.play()
                    
                    // Also update source list for the new channel in background
                    Task.detached {
                        let videos = DatabaseManager.shared.getVideos(byTvgName: nextVideo.tvgName ?? "")
                        let sortedVideos = videos.sorted { v1, v2 in
                            // Sort: Positive Latency < Nil (Untested) < Negative (Failed)
                            let l1 = v1.latency ?? Double.greatestFiniteMagnitude
                            let l2 = v2.latency ?? Double.greatestFiniteMagnitude
                            
                            let s1 = (l1 > 0) ? l1 : Double.infinity
                            let s2 = (l2 > 0) ? l2 : Double.infinity
                            
                            if s1 != s2 { return s1 < s2 }
                            return v1.title < v2.title
                        }
                        await MainActor.run {
                            self.sourceList = sortedVideos
                            self.showSourceList = true
                            self.highlightedVideo = nextVideo
                            
                            // Auto hide after 1.5s
                            self.sourceListTimer?.invalidate()
                            self.sourceListTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                                Task { @MainActor in
                                    self?.showSourceList = false
                                    self?.highlightedVideo = nil
                                }
                            }
                        }
                    }
                }
            } else {
                DebugLogger.shared.warning("No adjacent channel found")
            }
        }
    }

    func switchSource(direction: Int, currentVideo: Video? = nil) {
        guard let video = currentVideo ?? self.currentVideo else {
            DebugLogger.shared.error("switchSource: No current video")
            return
        }
        
        // If source list is already populated and visible, use it directly for faster switching
        if showSourceList && !sourceList.isEmpty {
            // If just keeping list open (direction 0), ensure highlight is synced if missing
            if direction == 0 {
                if highlightedVideo == nil { highlightedVideo = video }
                resetSourceListTimer()
                return
            }
            
            let baseId = highlightedVideo?.id ?? video.id
            if let index = sourceList.firstIndex(where: { $0.id == baseId }) {
                var newIndex = index + direction
                if newIndex < 0 { newIndex = sourceList.count - 1 }
                if newIndex >= sourceList.count { newIndex = 0 }
                
                let nextVideo = sourceList[newIndex]
                self.highlightedVideo = nextVideo
                DebugLogger.shared.info("Highlighting source: \(nextVideo.title) (\(newIndex + 1)/\(sourceList.count))")
                
                resetSourceListTimer()
                
                // Debounce Switch
                switchSourceDebounceTimer?.invalidate()
                switchSourceDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        if nextVideo.id != self?.currentVideo?.id {
                            DebugLogger.shared.info("Switching source to \(nextVideo.title) (Latency: \(nextVideo.latency ?? -1))")
                            self?.load(video: nextVideo)
                            self?.play()
                        }
                    }
                }
            } else {
                DebugLogger.shared.error("switchSource: Base video ID \(baseId) not found in sourceList of \(sourceList.count) items")
                // Fallback: Select first item
                if let first = sourceList.first {
                    self.highlightedVideo = first
                }
            }
            return
        }
        
        guard let tvgName = video.tvgName else {
            DebugLogger.shared.error("switchSource: No tvgName for video \(video.title)")
            return
        }
        
        Task.detached {
            let videos = DatabaseManager.shared.getVideos(byTvgName: tvgName)
            guard !videos.isEmpty else { return }
            
            // Sort videos by latency (lowest positive first)
            let sortedVideos = videos.sorted { v1, v2 in
                // Sort: Positive Latency < Nil (Untested) < Negative (Failed)
                let l1 = v1.latency ?? Double.greatestFiniteMagnitude
                let l2 = v2.latency ?? Double.greatestFiniteMagnitude
                
                let s1 = (l1 > 0) ? l1 : Double.infinity
                let s2 = (l2 > 0) ? l2 : Double.infinity
                
                if s1 != s2 { return s1 < s2 }
                return v1.title < v2.title
            }
            
            if let index = sortedVideos.firstIndex(where: { $0.id == video.id }) {
                var newIndex = index + direction
                if newIndex < 0 { newIndex = sortedVideos.count - 1 }
                if newIndex >= sortedVideos.count { newIndex = 0 }
                
                let nextVideo = sortedVideos[newIndex]
                
                await MainActor.run {
                    // Update Source List UI
                    self.sourceList = sortedVideos
                    self.showSourceList = true
                    self.highlightedVideo = nextVideo
                    DebugLogger.shared.info("Initial source list loaded. Highlighting: \(nextVideo.title)")
                    
                    self.resetSourceListTimer()
                    
                    if nextVideo.id != video.id {
                        // Debounce initial switch if it was a navigation action
                        self.switchSourceDebounceTimer?.invalidate()
                        self.switchSourceDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                            Task { @MainActor in
                                DebugLogger.shared.info("Switching source for \(tvgName) to \(nextVideo.title) (Latency: \(nextVideo.latency ?? -1))")
                                self?.load(video: nextVideo)
                                self?.play()
                            }
                        }
                    }
                }
            } else {
                // Current video not found in list (maybe ID mismatch?), default to first
                 await MainActor.run {
                    self.sourceList = sortedVideos
                    self.showSourceList = true
                    if let first = sortedVideos.first {
                        self.highlightedVideo = first
                        DebugLogger.shared.info("Current video not in list. Defaulting to first: \(first.title)")
                    }
                 }
            }
        }
    }
    
    private func resetSourceListTimer() {
        sourceListTimer?.invalidate()
        sourceListTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.showSourceList = false
                self?.highlightedVideo = nil
            }
        }
    }
}
