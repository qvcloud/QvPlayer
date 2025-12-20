import SwiftUI
import AVKit

struct PlayerView: View {
    let video: Video
    @AppStorage("playerEngine") private var playerEngine = "system"
    @StateObject private var viewModel = PlayerViewModel()
    @State private var ksIsPlaying = false
    
    @State private var showControls = false
    @State private var tipsMessage: String?
    @State private var showTips = false
    
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
            
            // Tips / Error Overlay
            if showTips, let message = tipsMessage {
                VStack {
                    HStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                        Text(message)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.85))
                            .shadow(radius: 10)
                    )
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
            }
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
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if let error = newValue {
                showTips(message: error)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("playerDidEncounterError"))) { notification in
            if let message = notification.userInfo?["message"] as? String {
                showTips(message: message)
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
                    onSeek: { NotificationCenter.default.post(name: .commandSeek, object: nil, userInfo: ["seconds": $0]) }
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
                SystemVideoPlayer(player: player)
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
            viewModel.player = nil
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
    
    func showTips(message: String) {
        self.tipsMessage = message
        withAnimation {
            self.showTips = true
        }
        
        // Auto-hide after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation {
                self.showTips = false
            }
        }
    }
}
