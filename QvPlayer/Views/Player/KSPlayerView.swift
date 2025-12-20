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
        var playerLayer: KSPlayerLayer?
        #else
        var playerLayer: Any?
        #endif
    }
}
