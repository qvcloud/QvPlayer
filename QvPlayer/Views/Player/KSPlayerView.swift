import SwiftUI
#if canImport(KSPlayer)
import KSPlayer
#endif
// Ensure FFmpegKit is available. If you see "Missing required modules", 
// make sure FFmpegKit is added to your target's Frameworks.
#if canImport(FFmpegKit)
import FFmpegKit
#endif

struct KSPlayerView: UIViewRepresentable {
    let video: Video
    
    func makeUIView(context: Context) -> UIView {
        print("▶️ [KSPlayerView] Initializing KSPlayer")
        DebugLogger.shared.info("[KSPlayerView] Initializing KSPlayer")
        
        /*
        #if canImport(FFmpegKit)
        // FFmpegKit logging is currently causing compilation issues.
        // Disabling direct FFmpeg logging for now.
        // To enable, we need to ensure FFmpegKitConfig and LogLevel are available.
        #endif
        */
        
        let playerView = UIView()
        playerView.backgroundColor = .black
        
        #if canImport(KSPlayer)
        let options = createOptions()
        
        // Use cached URL if available, otherwise use remote URL
        var targetURL = video.cachedURL ?? video.url
        
        // Resolve localcache:// scheme
        if targetURL.scheme == "localcache" {
             let rawFilename = targetURL.host ?? targetURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
             if !rawFilename.isEmpty, let filename = rawFilename.removingPercentEncoding {
                 let fileURL = CacheManager.shared.getFileURL(filename: filename)
                 if FileManager.default.fileExists(atPath: fileURL.path) {
                     targetURL = fileURL
                     print("✅ [KSPlayerView] Resolved localcache:// to \(targetURL.path)")
                 } else {
                     print("❌ [KSPlayerView] Failed to resolve localcache:// - File not found: \(filename)")
                 }
             }
        }
        
        if let url = URL(string: targetURL.absoluteString) {
            let playerLayer = KSPlayerLayer(url: url, options: options)
            if let view = playerLayer.player.view {
                view.frame = playerView.bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                playerView.addSubview(view)
            }
            context.coordinator.playerLayer = playerLayer
        }
        #else
        let label = UILabel()
        label.text = "KSPlayer Library Missing"
        label.textColor = .white
        label.textAlignment = .center
        label.frame = playerView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        playerView.addSubview(label)
        #endif
        
        return playerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        #if canImport(KSPlayer)
        if let playerLayer = context.coordinator.playerLayer {
            var targetURL = video.cachedURL ?? video.url
            
            // Resolve localcache:// scheme
            if targetURL.scheme == "localcache" {
                 let rawFilename = targetURL.host ?? targetURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                 if !rawFilename.isEmpty, let filename = rawFilename.removingPercentEncoding {
                     let fileURL = CacheManager.shared.getFileURL(filename: filename)
                     if FileManager.default.fileExists(atPath: fileURL.path) {
                         targetURL = fileURL
                     }
                 }
            }
            
            if playerLayer.url.absoluteString != targetURL.absoluteString {
                let options = createOptions()
                playerLayer.set(url: targetURL, options: options)
            }
        }
        #endif
    }
    
    #if canImport(KSPlayer)
    private func createOptions() -> KSOptions {
        let options = KSOptions()
        
        // Load Config
        let hardwareDecode = DatabaseManager.shared.getConfig(key: "hardware_decode") ?? "true"
        let fastOpen = DatabaseManager.shared.getConfig(key: "fast_open") ?? "true"
        let rtspTransport = DatabaseManager.shared.getConfig(key: "rtsp_transport") ?? "tcp"
        let bufferDuration = DatabaseManager.shared.getConfig(key: "buffer_duration") ?? "20"
        
        // Performance Optimizations
        options.hardwareDecode = (hardwareDecode == "true") // Enable Hardware Acceleration (VideoToolbox)
        options.isSecondOpen = (fastOpen == "true")   // Enable fast open
        
        // Network optimizations
        options.cache = true
        // Increase buffer size to avoid stuttering on network videos
        options.maxBufferDuration = TimeInterval(Int(bufferDuration) ?? 20)
        
        // RTSP Transport
        if rtspTransport == "udp" {
            options.formatContextOptions["rtsp_transport"] = "udp"
        } else {
            options.formatContextOptions["rtsp_transport"] = "tcp"
        }
        
        // User-Agent
        if let userAgent = DatabaseManager.shared.getConfig(key: "user_agent"), !userAgent.isEmpty {
            options.userAgent = userAgent
            DebugLogger.shared.info("[KSPlayer] Using custom User-Agent: \(userAgent)")
        }
        
        // Proxy
        if UserDefaults.standard.bool(forKey: "proxyEnabled") {
            let host = UserDefaults.standard.string(forKey: "proxyHost") ?? ""
            let port = UserDefaults.standard.string(forKey: "proxyPort") ?? "8080"
            let user = UserDefaults.standard.string(forKey: "proxyUsername") ?? ""
            let pass = UserDefaults.standard.string(forKey: "proxyPassword") ?? ""
            
            if !host.isEmpty {
                var proxyString = ""
                if !user.isEmpty {
                    // URL Encode username and password
                    let safeUser = user.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? user
                    let safePass = pass.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? pass
                    proxyString = "http://\(safeUser):\(safePass)@\(host):\(port)"
                } else {
                    proxyString = "http://\(host):\(port)"
                }
                
                options.formatContextOptions["http_proxy"] = proxyString
                // Mask password in logs
                let logString = proxyString.replacingOccurrences(of: ":[^@]+@", with: ":***@", options: .regularExpression)
                DebugLogger.shared.info("[KSPlayer] Using Proxy: \(logString)")
            }
        }
        
        // Enable detailed logging
        // options.setShowDebugLog(true) // API not available in this version
        
        return options
    }
    #endif
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        #if canImport(KSPlayer)
        coordinator.playerLayer?.pause()
        coordinator.stop()
        #endif
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var parent: KSPlayerView?
        #if canImport(KSPlayer)
        var playerLayer: KSPlayerLayer? {
            didSet {
                startStatusTimer()
            }
        }
        private var statusTimer: Timer?
        private var lastBytesRead: Int64 = 0
        private var lastPlayableTime: TimeInterval = 0
        private var lastSpeedCheckTime: TimeInterval = 0
        private var hasFinishedPlaying: Bool = false
        
        private var isUserPaused: Bool = false
        
        override init() {
            super.init()
            setupRemoteCommands()
        }
        
        deinit {
            statusTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }
        
        func stop() {
            statusTimer?.invalidate()
            broadcastStatus()
        }
        
        private func setupRemoteCommands() {
            NotificationCenter.default.addObserver(self, selector: #selector(handlePlay), name: .commandPlay, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handlePause), name: .commandPause, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleToggle), name: .commandToggle, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleSeek(_:)), name: .commandSeek, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleSeekTo(_:)), name: .commandSeekTo, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleSelectAudioTrack(_:)), name: .commandSelectAudioTrack, object: nil)
        }
        
        @objc private func handlePlay() { 
            isUserPaused = false
            playerLayer?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.broadcastStatus()
            }
        }
        @objc private func handlePause() { 
            isUserPaused = true
            playerLayer?.pause()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.broadcastStatus()
            }
        }
        @objc private func handleToggle() {
            if playerLayer?.player.isPlaying == true {
                isUserPaused = true
                playerLayer?.pause()
            } else {
                isUserPaused = false
                playerLayer?.play()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.broadcastStatus()
            }
        }
        @objc private func handleSeek(_ notification: Notification) {
            if let seconds = notification.userInfo?["seconds"] as? Double {
                // Seek usually auto-plays, so reset pause flag
                isUserPaused = false
                let current = playerLayer?.player.currentPlaybackTime ?? 0
                playerLayer?.seek(time: current + seconds, autoPlay: true, completion: { _ in 
                    self.broadcastStatus()
                })
            }
        }
        
        @objc private func handleSeekTo(_ notification: Notification) {
            if let time = notification.userInfo?["time"] as? Double {
                isUserPaused = false
                playerLayer?.seek(time: time, autoPlay: true, completion: { _ in 
                    self.broadcastStatus()
                })
            }
        }
        
        @objc private func handleSelectAudioTrack(_ notification: Notification) {
            guard let trackId = notification.userInfo?["trackId"] as? String else { return }
            if let playerLayer = playerLayer {
                let tracks = playerLayer.player.tracks(mediaType: .audio)
                if let track = tracks.first(where: { ($0.name.isEmpty ? $0.description : $0.name) == trackId }) {
                    track.isEnabled = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.broadcastStatus()
                    }
                }
            }
        }
        
        private func startStatusTimer() {
            statusTimer?.invalidate()
            statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.broadcastStatus()
            }
        }
        
        private func broadcastStatus() {
            guard let playerLayer = playerLayer else { return }
            let player = playerLayer.player
            
            let currentTime = player.currentPlaybackTime
            let duration = player.duration
            
            let isLocal = playerLayer.url.isFileURL
            let serverAddress = isLocal ? "Local" : "Remote"
            
            let status: [String: Any] = [
                "isPlaying": player.isPlaying,
                "title": playerLayer.url.lastPathComponent,
                "id": parent?.video.id.uuidString ?? "",
                "currentTime": currentTime.isNaN ? 0 : currentTime,
                "duration": duration.isNaN ? 0 : duration,
                "serverAddress": serverAddress,
                "isOnline": player.isPlaying || player.duration > 0
            ]
            NotificationCenter.default.post(name: .playerStatusDidUpdate, object: nil, userInfo: ["status": status])
            
            // Broadcast Audio Tracks
            let audioTracks = player.tracks(mediaType: .audio)
            if !audioTracks.isEmpty {
                let audioTrackNames = audioTracks.map { $0.name.isEmpty ? $0.description : $0.name }
                let currentAudioTrack = audioTracks.first(where: { $0.isEnabled })
                let currentAudioTrackName = currentAudioTrack.map { $0.name.isEmpty ? $0.description : $0.name } ?? ""
                
                NotificationCenter.default.post(name: .playerTracksDidUpdate, object: nil, userInfo: [
                    "audioTracks": audioTrackNames,
                    "currentAudioTrack": currentAudioTrackName
                ])
            }
            
            // Check for completion (Simple polling detection)
            // Only trigger if we are very close to the end, stopped, AND not paused by user
            if duration > 0 && (duration - currentTime) < 0.5 && !player.isPlaying && !isUserPaused {
                 // Only trigger if we are very close to the end and stopped
                 // This assumes the player stops automatically at the end
                 if !hasFinishedPlaying {
                     print("🏁 [KSPlayer] Playback finished (detected via polling)")
                     NotificationCenter.default.post(name: .playerDidFinishPlaying, object: nil)
                     hasFinishedPlaying = true
                 }
            } else {
                // Reset flag if we are not at the end (e.g. seeked back)
                if (duration - currentTime) > 1.0 {
                    hasFinishedPlaying = false
                }
            }
            
            // Update Debug Stats
            Task { @MainActor in
                var stats = DebugLogger.shared.videoStats
                stats.url = playerLayer.url.absoluteString
                let size = player.naturalSize
                stats.resolution = "\(Int(size.width))x\(Int(size.height))"
                stats.bufferDuration = max(0, player.playableTime - player.currentPlaybackTime)
                
                // FPS
                stats.fps = Double(player.nominalFrameRate)
                
                // Track Info
                if let track = player.tracks(mediaType: .video).first(where: { $0.isEnabled }) {
                     stats.codec = track.description
                     stats.bitrate = Double(track.bitRate)
                }
                
                // Calculate Download Speed
                let currentTime = Date().timeIntervalSince1970
                var currentBytes: Int64 = 0
                
                // Detailed Stream Info
                if let dynamicInfo = player.dynamicInfo {
                    currentBytes = dynamicInfo.bytesRead
                    stats.bytesRead = dynamicInfo.bytesRead
                }
                
                stats.currentTime = player.currentPlaybackTime
                stats.duration = player.duration
                
                // Update Online Status
                stats.status = (player.isPlaying || player.duration > 0) ? "Online" : "Offline"
                stats.serverAddress = serverAddress
                
                // if let dynamicInfo = player.dynamicInfo {
                //    currentBytes = dynamicInfo.bytesRead
                // }
                
                let currentPlayableTime = player.playableTime
                
                if self.lastSpeedCheckTime > 0 {
                    let timeDelta = currentTime - self.lastSpeedCheckTime
                    if timeDelta > 0.5 { // Update if enough time passed
                        // Method 1: bytesRead
                        let bytesDelta = currentBytes - self.lastBytesRead
                        var speed = Double(bytesDelta) / timeDelta
                        
                        // Method 2: Fallback to buffer growth
                        if speed <= 0 && stats.bitrate > 0 {
                            let playableDelta = currentPlayableTime - self.lastPlayableTime
                            // Only consider reasonable positive growth (ignore seeks)
                            if playableDelta > 0 && playableDelta < 50 {
                                let estimatedBytes = playableDelta * (stats.bitrate / 8.0)
                                speed = estimatedBytes / timeDelta
                            }
                        }
                        
                        stats.downloadSpeed = max(0, speed)
                        
                        self.lastBytesRead = currentBytes
                        self.lastPlayableTime = currentPlayableTime
                        self.lastSpeedCheckTime = currentTime
                    }
                } else {
                    self.lastBytesRead = currentBytes
                    self.lastPlayableTime = currentPlayableTime
                    self.lastSpeedCheckTime = currentTime
                }
                
                DebugLogger.shared.videoStats = stats
            }
        }
        #else
        var playerLayer: Any?
        #endif
    }
}
