import SwiftUI
import AVKit

struct PlayerView: View {
    let video: Video
    @AppStorage("playerEngine") private var playerEngine = "system"
    @StateObject private var viewModel = PlayerViewModel()
    @State private var ksIsPlaying = false
    
    @State private var showControls = false
    
    enum FocusField {
        case rewind, playPause, fastForward, ksPlayer
    }
    @FocusState private var focusedField: FocusField?
    
    var body: some View {
        ZStack {
            if playerEngine == "ksplayer" {
                ksPlayerContent
            } else {
                systemPlayerContent
            }
            
            // Debug Info Overlay
            VStack {
                HStack {
                    Text("Engine: \(playerEngine == "ksplayer" ? "KSPlayer" : "System (AVPlayer)")")
                        .font(.system(size: 24, weight: .bold)) // Larger font for TV
                        .foregroundColor(.yellow)
                        .padding(12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    Spacer()
                }
                Spacer()
            }
            .padding(60) // TV safe area
            .allowsHitTesting(false)
        }
        .onAppear {
            print("▶️ [PlayerView] Current Engine: \(playerEngine)")
            if playerEngine == "ksplayer" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .ksPlayer
                }
            }
        }
        .onChange(of: showControls) { _, newValue in
            if newValue {
                // Auto-hide logic could go here if we didn't force focus
            }
        }
    }
    
    var ksPlayerContent: some View {
        KSPlayerView(video: video)
            .focusable()
            .focused($focusedField, equals: .ksPlayer)
            .onPlayPauseCommand {
                NotificationCenter.default.post(name: .commandToggle, object: nil)
            }
            .onMoveCommand { direction in
                handleMoveCommand(direction: direction) {
                    NotificationCenter.default.post(name: .commandSeek, object: nil, userInfo: ["seconds": $0])
                }
            }
            .onTapGesture {
                toggleControls(engine: "ksplayer")
            }
            .overlay(alignment: .bottom) {
                playerControls(
                    isPlaying: ksIsPlaying,
                    onPlayPause: { NotificationCenter.default.post(name: .commandToggle, object: nil) },
                    onSeek: { sec in NotificationCenter.default.post(name: .commandSeek, object: nil, userInfo: ["seconds": sec]) }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .playerStatusDidUpdate)) { notification in
                if let userInfo = notification.userInfo,
                   let status = userInfo["status"] as? [String: Any],
                   let isPlaying = status["isPlaying"] as? Bool {
                    self.ksIsPlaying = isPlaying
                }
            }
    }
    
    var systemPlayerContent: some View {
        ZStack {
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .overlay {
                        if viewModel.isBuffering {
                            ZStack {
                                Color.black.opacity(0.4)
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(2)
                                    .tint(.white)
                            }
                        }
                        
                        if let error = viewModel.errorMessage {
                            VStack {
                                Text(error)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(8)
                                Spacer()
                            }
                            .padding(.top, 50)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .onTapGesture {
                        toggleControls(engine: "system")
                    }
                    .overlay(alignment: .bottom) {
                        playerControls(
                            isPlaying: viewModel.isPlaying,
                            onPlayPause: { viewModel.togglePlayPause() },
                            onSeek: { viewModel.seek(by: $0) }
                        )
                    }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            viewModel.load(video: video)
        }
        .onDisappear {
            viewModel.pause()
        }
    }
    
    // MARK: - Shared Controls
    
    @ViewBuilder
    func playerControls(isPlaying: Bool, onPlayPause: @escaping () -> Void, onSeek: @escaping (Double) -> Void) -> some View {
        HStack(spacing: 40) {
            if !video.isLive {
                Button(action: { onSeek(-10) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 40))
                        .padding()
                }
                .buttonStyle(.card)
                .focused($focusedField, equals: .rewind)
            }

            Button(action: { onPlayPause() }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 40))
                    .padding()
            }
            .buttonStyle(.card)
            .focused($focusedField, equals: .playPause)
            
            if !video.isLive {
                Button(action: { onSeek(10) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 40))
                        .padding()
                }
                .buttonStyle(.card)
                .focused($focusedField, equals: .fastForward)
            }
        }
        .padding(.bottom, 60)
        .opacity(showControls || focusedField != nil ? 1 : 0)
        .animation(.easeInOut, value: showControls || (focusedField != nil))
    }
    
    // MARK: - Helpers
    
    func handleMoveCommand(direction: MoveCommandDirection, onSeek: (Double) -> Void) {
        switch direction {
        case .left:
            onSeek(-10)
        case .right:
            onSeek(10)
        case .up, .down:
            showControls = true
            focusedField = .playPause
        default:
            break
        }
    }
    
    func toggleControls(engine: String) {
        showControls.toggle()
        if showControls {
            focusedField = .playPause
        } else {
            if engine == "ksplayer" {
                focusedField = .ksPlayer
            } else {
                focusedField = nil
            }
        }
    }
}
