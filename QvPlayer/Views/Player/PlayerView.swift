import SwiftUI
import AVKit

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @State var video: Video
    @AppStorage("playerEngine") private var playerEngine = "system"
    @StateObject private var viewModel = PlayerViewModel()
    @State private var ksIsPlaying = false
    
    @State private var showControls = false
    @State private var tipsMessage: String?
    @State private var showTips = false
    @State private var autoHideTask: DispatchWorkItem?
    
    enum FocusField {
        case rewind, playPause, fastForward, ksPlayer, systemPlayer
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
        .ignoresSafeArea()
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .onAppear {
            print("▶️ [PlayerView] Current Engine: \(playerEngine)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if playerEngine == "ksplayer" {
                    focusedField = .ksPlayer
                } else {
                    focusedField = .systemPlayer
                }
            }
        }
        .onChange(of: showControls) { _, newValue in
            if newValue {
                resetAutoHideTimer()
            } else {
                cancelAutoHideTimer()
            }
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue == .rewind || newValue == .playPause || newValue == .fastForward {
                resetAutoHideTimer()
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
        .onReceive(NotificationCenter.default.publisher(for: .playerDidFinishPlaying)) { _ in
            print("🏁 [PlayerView] Received finish notification")
            // Do NOT dismiss here if we are in a queue context
            // The MediaManager will trigger the next video
        }
        .onReceive(NotificationCenter.default.publisher(for: .commandPlayVideo)) { notification in
            if let nextVideo = notification.userInfo?["video"] as? Video {
                print("⏭ [PlayerView] Switching to next video: \(nextVideo.title)")
                self.video = nextVideo
                
                if playerEngine == "ksplayer" {
                    // KSPlayerView will update because 'video' is now a @State property passed to it
                    // But we might need to ensure it re-renders or re-initializes the player
                } else {
                    viewModel.load(video: nextVideo)
                    viewModel.play()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .queueDidFinish)) { _ in
            print("🏁 [PlayerView] Queue finished, dismissing player")
            dismiss()
        }
        .onExitCommand {
            dismiss()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
    
    var ksPlayerContent: some View {
        KSPlayerView(video: video)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
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
            .onExitCommand {
                dismiss()
            }
            .onTapGesture {
                toggleControls(engine: "ksplayer")
            }
            .overlay(alignment: .bottom) {
                playerControls(
                    isPlaying: ksIsPlaying,
                    onPlayPause: { 
                        NotificationCenter.default.post(name: .commandToggle, object: nil)
                        resetAutoHideTimer()
                    },
                    onSeek: { 
                        NotificationCenter.default.post(name: .commandSeek, object: nil, userInfo: ["seconds": $0])
                        resetAutoHideTimer()
                    }
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
                    .focusable()
                    .focused($focusedField, equals: .systemPlayer)
                    .onExitCommand {
                        dismiss()
                    }
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
                            onPlayPause: { 
                                viewModel.togglePlayPause()
                                resetAutoHideTimer()
                            },
                            onSeek: { 
                                viewModel.seek(by: $0)
                                resetAutoHideTimer()
                            }
                        )
                    }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if playerEngine != "ksplayer" {
                viewModel.load(video: video)
                viewModel.play()
            }
        }
        .onDisappear {
            if playerEngine != "ksplayer" {
                viewModel.stop()
            }
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
        .opacity(showControls || (focusedField != nil && focusedField != .ksPlayer) ? 1 : 0)
        .animation(.easeInOut, value: showControls || (focusedField != nil && focusedField != .ksPlayer))
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
            resetAutoHideTimer()
        } else {
            cancelAutoHideTimer()
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
    
    func resetAutoHideTimer() {
        autoHideTask?.cancel()
        let task = DispatchWorkItem {
            withAnimation {
                showControls = false
                if playerEngine == "ksplayer" {
                    focusedField = .ksPlayer
                } else {
                    focusedField = nil
                }
            }
        }
        autoHideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
    }
    
    func cancelAutoHideTimer() {
        autoHideTask?.cancel()
        autoHideTask = nil
    }
}
