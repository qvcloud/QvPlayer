import SwiftUI
import AVKit

struct PlayerView: View {
    let video: Video
    @StateObject private var viewModel = PlayerViewModel()
    
    @State private var showControls = false
    @FocusState private var isPlayButtonFocused: Bool
    
    var body: some View {
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
                    }
                    .overlay(alignment: .bottom) {
                        // Custom Controls Overlay
                        HStack(spacing: 40) {
                            Button(action: {
                                viewModel.togglePlayPause()
                            }) {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 40))
                                    .padding()
                            }
                            .buttonStyle(.card)
                            .focused($isPlayButtonFocused)
                            
                            // You can add more buttons here (e.g. Info, Subtitles)
                        }
                        .padding(.bottom, 60)
                        .opacity(showControls || isPlayButtonFocused ? 1 : 0)
                        .animation(.easeInOut, value: showControls || isPlayButtonFocused)
                    }
                    .onTapGesture {
                        showControls.toggle()
                    }
                    // Auto-hide controls after delay
                    .onChange(of: showControls) { newValue in
                        if newValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                if !isPlayButtonFocused {
                                    showControls = false
                                }
                            }
                        }
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
}
