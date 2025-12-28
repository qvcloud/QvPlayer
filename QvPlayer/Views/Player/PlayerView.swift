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
        case rewind, playPause, fastForward, ksPlayer, systemPlayer, audioTrack, playbackSpeed
    }
    @FocusState private var focusedField: FocusField?
    
    var body: some View {
        ZStack {
            if playerEngine == "ksplayer" {
                ksPlayerContent
            } else {
                systemPlayerContent
            }
            
            tipsOverlay
            sourceListOverlay
        }
        .ignoresSafeArea()
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .onAppear {
            print("▶️ [PlayerView] Current Engine: \(playerEngine)")
            // Sync viewModel with current video for UI state (even if using KSPlayer)
            if viewModel.currentVideo?.id != video.id {
                viewModel.currentVideo = video
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if playerEngine == "ksplayer" {
                    focusedField = .ksPlayer
                } else {
                    focusedField = .systemPlayer
                }
            }
        }
        .onChange(of: video) { _, newVideo in
            // Sync viewModel when video changes externally
            if viewModel.currentVideo?.id != newVideo.id {
                viewModel.currentVideo = newVideo
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
            if newValue == .rewind || newValue == .playPause || newValue == .fastForward || newValue == .audioTrack || newValue == .playbackSpeed {
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
                
                // Force update if it's the same video
                if self.video.id == nextVideo.id {
                    // If it's the same video, we need to force a replay
                    // For KSPlayerView, we can trigger a seek to 0 or re-set the URL
                    // But since KSPlayerView checks for URL equality, we might need a way to force it.
                    // A simple way is to post a seek command to 0 and play.
                    NotificationCenter.default.post(name: .commandSeek, object: nil, userInfo: ["seconds": 0.0])
                    NotificationCenter.default.post(name: .commandPlay, object: nil)
                } else {
                    self.video = nextVideo
                }
                
                if playerEngine == "ksplayer" {
                    // KSPlayerView will update because 'video' is now a @State property passed to it
                    // But we might need to ensure it re-renders or re-initializes the player
                } else {
                    viewModel.load(video: nextVideo)
                    viewModel.play()
                }
            }
        }
        .onChange(of: viewModel.currentVideo) { _, newVideo in
            if let newVideo = newVideo, newVideo.id != self.video.id {
                print("🔄 [PlayerView] Syncing video state from ViewModel: \(newVideo.title)")
                self.video = newVideo
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .queueDidFinish)) { _ in
            print("🏁 [PlayerView] Queue finished, dismissing player")
            dismiss()
        }
        .onExitCommand {
            if viewModel.showSourceList {
                viewModel.showSourceList = false
            } else {
                dismiss()
            }
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
                if viewModel.showSourceList {
                    viewModel.showSourceList = false
                } else {
                    dismiss()
                }
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
                    .onMoveCommand { direction in
                        handleMoveCommand(direction: direction) {
                            viewModel.seek(by: $0)
                        }
                    }
                    .onExitCommand {
                        if viewModel.showSourceList {
                            viewModel.showSourceList = false
                        } else {
                            dismiss()
                        }
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
    
    // MARK: - Overlays
    
    @ViewBuilder
    var tipsOverlay: some View {
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
    
    @ViewBuilder
    var sourceListOverlay: some View {
        if viewModel.showSourceList {
            GeometryReader { geometry in
                HStack {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(video.tvgName ?? video.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 5)
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(viewModel.sourceList) { src in
                                        sourceListItem(src: src)
                                    }
                                }
                            }
                            .focusable(false) // Ensure ScrollView doesn't steal focus
                            .frame(maxHeight: geometry.size.height * 0.6)
                            .onChange(of: viewModel.highlightedVideo) { _, newVideo in
                                if let video = newVideo {
                                    withAnimation {
                                        proxy.scrollTo(video.id, anchor: .center)
                                    }
                                }
                            }
                            .onAppear {
                                // Initial scroll to current video
                                if let video = viewModel.currentVideo {
                                    proxy.scrollTo(video.id, anchor: .center)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(width: 600)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.85))
                            .shadow(radius: 10)
                    )
                    .padding(.leading, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .transition(.move(edge: .leading).combined(with: .opacity))
            .zIndex(90)
        }
    }
    
    @ViewBuilder
    func sourceListItem(src: Video) -> some View {
        let isHighlighted = src.id == viewModel.highlightedVideo?.id
        let isPlaying = src.id == viewModel.currentVideo?.id
        
        // Format: host:port/.../filename
        let host = src.url.host ?? ""
        let port = src.url.port.map { ":\($0)" } ?? ""
        let filename = src.url.lastPathComponent
        let displayString = host.isEmpty ? src.url.absoluteString : "\(host)\(port)/.../\(filename)"
        
        HStack(spacing: 4) {
            if isPlaying {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .frame(width: 28, alignment: .trailing)
            } else {
                if let index = viewModel.sourceList.firstIndex(where: { $0.id == src.id }) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(width: 28, alignment: .trailing)
                }
            }
            
            Text(displayString)
                .font(.caption)
                .foregroundColor(isPlaying ? .green : .white)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
            
            Spacer(minLength: 8)
            
            if let latency = src.latency {
                Text("\(Int(latency))ms")
                    .font(.caption2)
                    .foregroundColor(latency < 0 ? .red : (latency < 500 ? .green : .yellow))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHighlighted ? Color.white.opacity(0.2) : (isPlaying ? Color.white.opacity(0.1) : Color.clear))
        )
        .id(src.id)
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
                        .background(
                            Circle()
                                .fill(focusedField == .rewind ? Color.white.opacity(0.3) : Color.clear)
                        )
                        .scaleEffect(focusedField == .rewind ? 1.2 : 1.0)
                        .animation(.spring(), value: focusedField)
                }
                .buttonStyle(.plain)
                .focused($focusedField, equals: .rewind)
            }

            Button(action: { onPlayPause() }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 40))
                    .padding()
                    .background(
                        Circle()
                            .fill(focusedField == .playPause ? Color.white.opacity(0.3) : Color.clear)
                    )
                    .scaleEffect(focusedField == .playPause ? 1.2 : 1.0)
                    .animation(.spring(), value: focusedField)
            }
            .buttonStyle(.plain)
            .focused($focusedField, equals: .playPause)
            
            if !video.isLive {
                Button(action: { onSeek(10) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 40))
                        .padding()
                        .background(
                            Circle()
                                .fill(focusedField == .fastForward ? Color.white.opacity(0.3) : Color.clear)
                        )
                        .scaleEffect(focusedField == .fastForward ? 1.2 : 1.0)
                        .animation(.spring(), value: focusedField)
                }
                .buttonStyle(.plain)
                .focused($focusedField, equals: .fastForward)
            }
            
            // Audio Track Selection
            if !viewModel.audioTracks.isEmpty {
                Menu {
                    ForEach(viewModel.audioTracks, id: \.self) { track in
                        Button(action: {
                            viewModel.selectAudioTrack(track)
                        }) {
                            HStack {
                                Text(track)
                                if track == viewModel.currentAudioTrack {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "waveform")
                        .font(.system(size: 30))
                        .padding()
                        .background(
                            Circle()
                                .fill(focusedField == .audioTrack ? Color.white.opacity(0.3) : Color.clear)
                        )
                        .scaleEffect(focusedField == .audioTrack ? 1.2 : 1.0)
                        .animation(.spring(), value: focusedField)
                }
                .buttonStyle(.plain)
                .focused($focusedField, equals: .audioTrack)
            }
            
            // Playback Speed
            Menu {
                ForEach([0.5, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button(action: {
                        NotificationCenter.default.post(name: .commandSetPlaybackRate, object: nil, userInfo: ["rate": Float(rate)])
                    }) {
                        HStack {
                            Text("\(String(format: "%.2fx", rate))")
                            if Float(rate) == viewModel.playbackRate {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "gauge")
                    .font(.system(size: 30))
                    .padding()
                    .background(
                        Circle()
                            .fill(focusedField == .playbackSpeed ? Color.white.opacity(0.3) : Color.clear)
                    )
                    .scaleEffect(focusedField == .playbackSpeed ? 1.2 : 1.0)
                    .animation(.spring(), value: focusedField)
            }
            .buttonStyle(.plain)
            .focused($focusedField, equals: .playbackSpeed)
        }
        .padding(.bottom, 60)
        .opacity(showControls || (focusedField != nil && focusedField != .ksPlayer && focusedField != .systemPlayer) ? 1 : 0)
        .animation(.easeInOut, value: showControls || (focusedField != nil && focusedField != .ksPlayer && focusedField != .systemPlayer))
    }
    
    // MARK: - Helpers
    
    func handleMoveCommand(direction: MoveCommandDirection, onSeek: (Double) -> Void) {
        // Intercept if Source List is visible
        if viewModel.showSourceList {
            print("🎮 [PlayerView] Intercepting MoveCommand for SourceList: \(direction)")
            switch direction {
            case .up:
                viewModel.switchSource(direction: -1, currentVideo: video)
                return
            case .down:
                viewModel.switchSource(direction: 1, currentVideo: video)
                return
            case .left, .right:
                 // Keep list open, reset timer
                 viewModel.switchSource(direction: 0, currentVideo: video)
                 return
            default:
                break
            }
        }
        
        // When controls are visible, disable seek/channel switch to allow UI navigation
        if showControls {
            return
        }
        
        switch direction {
        case .left:
            if video.isLive {
                viewModel.switchSource(direction: 0, currentVideo: video)
            } else {
                onSeek(-10)
            }
        case .right:
            if video.isLive {
                viewModel.switchSource(direction: 0, currentVideo: video)
            } else {
                onSeek(10)
            }
        case .up:
            showControls = true
            focusedField = .playPause
            if video.isLive {
                viewModel.switchChannel(direction: -1)
            }
        case .down:
            showControls = true
            focusedField = .playPause
            if video.isLive {
                viewModel.switchChannel(direction: 1)
            }
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
                focusedField = .systemPlayer
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
                    focusedField = .systemPlayer
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
