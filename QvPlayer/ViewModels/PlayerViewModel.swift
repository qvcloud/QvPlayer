import Foundation
import AVKit
import Combine

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentVideo: Video?
    
    private var cancellables = Set<AnyCancellable>()
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var rateObserver: NSKeyValueObservation?
    
    init() {
        // Setup audio session for playback if needed (more relevant for iOS but good practice)
        // For tvOS, AVPlayer handles most things automatically.
    }
    
    func load(video: Video) {
        self.currentVideo = video
        let playerItem = AVPlayerItem(url: video.url)
        
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
}
