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
        let playerView = UIView()
        playerView.backgroundColor = .black
        
        #if canImport(KSPlayer)
        let options = KSOptions()
        // KSOptions.isAutoPlay = true // Global setting if needed
        
        // Performance Optimizations
        options.hardwareDecode = true // Enable Hardware Acceleration (VideoToolbox)
        options.isSecondOpen = true   // Enable fast open
        
        // Network optimizations
        // options.timeout = 30 // Not available
        
        if let url = URL(string: video.url.absoluteString) {
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
        #if canImport(KSPlayer)
        if let playerLayer = context.coordinator.playerLayer {
            if playerLayer.url.absoluteString != video.url.absoluteString {
                let options = KSOptions()
                playerLayer.set(url: video.url, options: options)
            }
        }
        #endif
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        #if canImport(KSPlayer)
        coordinator.playerLayer?.pause()
        // coordinator.playerLayer?.reset() // reset() not available
        #endif
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        #if canImport(KSPlayer)
        var playerLayer: KSPlayerLayer? {
            didSet {
                startStatusTimer()
            }
        }
        private var statusTimer: Timer?
        
        override init() {
            super.init()
            setupRemoteCommands()
        }
        
        deinit {
            statusTimer?.invalidate()
            NotificationCenter.default.removeObserver(self)
        }
        
        private func setupRemoteCommands() {
            NotificationCenter.default.addObserver(self, selector: #selector(handlePlay), name: .commandPlay, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handlePause), name: .commandPause, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleToggle), name: .commandToggle, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleSeek(_:)), name: .commandSeek, object: nil)
        }
        
        @objc private func handlePlay() { playerLayer?.play() }
        @objc private func handlePause() { playerLayer?.pause() }
        @objc private func handleToggle() {
            if playerLayer?.player.isPlaying == true {
                playerLayer?.pause()
            } else {
                playerLayer?.play()
            }
        }
        @objc private func handleSeek(_ notification: Notification) {
            if let seconds = notification.userInfo?["seconds"] as? Double {
                let current = playerLayer?.player.currentPlaybackTime ?? 0
                playerLayer?.seek(time: current + seconds, autoPlay: true, completion: { _ in })
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
            let status: [String: Any] = [
                "isPlaying": playerLayer.player.isPlaying,
                "title": playerLayer.url.lastPathComponent,
                "currentTime": playerLayer.player.currentPlaybackTime,
                "duration": playerLayer.player.duration
            ]
            NotificationCenter.default.post(name: .playerStatusDidUpdate, object: nil, userInfo: ["status": status])
        }
        #else
        var playerLayer: Any?
        #endif
    }
}
