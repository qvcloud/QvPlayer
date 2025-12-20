import SwiftUI
import AVKit

struct PlayerView: View {
    let video: Video
    @StateObject private var viewModel = PlayerViewModel()
    
    @State private var showControls = false
    
    enum FocusField {
        case rewind, playPause, fastForward
    }
    @FocusState private var focusedField: FocusField?
    
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
                            if !video.isLive {
                                Button(action: {
                                    viewModel.seek(by: -10)
                                }) {
                                    Image(systemName: "gobackward.10")
                                        .font(.system(size: 40))
                                        .padding()
                                }
                                .buttonStyle(.card)
                                .focused($focusedField, equals: .rewind)
                            }

                            Button(action: {
                                viewModel.togglePlayPause()
                            }) {
                                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 40))
                                    .padding()
                            }
                            .buttonStyle(.card)
                            .focused($focusedField, equals: .playPause)
                            
                            if !video.isLive {
                                Button(action: {
                                    viewModel.seek(by: 10)
                                }) {
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
                    .onTapGesture {
                        showControls.toggle()
                    }
                    // Auto-hide controls after delay
                    .onChange(of: showControls) { _, newValue in
                        if newValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                if focusedField == nil {
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
