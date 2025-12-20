import SwiftUI

struct DebugOverlayView: View {
    @StateObject private var logger = DebugLogger.shared
    @AppStorage("playerEngine") private var playerEngine = "system"
    
    var body: some View {
        if logger.showDebugOverlay {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Debug Console")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("Engine: \(playerEngine == "ksplayer" ? "KSPlayer" : "System")")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                            .padding(2)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.bottom, 2)
                    
                    // Video Stats Section
                    Group {
                        Text("Video Stats")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                            .padding(.bottom, 1)
                        
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
                            GridRow {
                                StatRow(title: "Resolution", value: logger.videoStats.resolution)
                                StatRow(title: "FPS", value: String(format: "%.1f", logger.videoStats.fps))
                            }
                            GridRow {
                                StatRow(title: "Bitrate", value: String(format: "%.2f Mbps", logger.videoStats.bitrate / 1000000))
                                StatRow(title: "Codec", value: logger.videoStats.codec)
                            }
                            GridRow {
                                StatRow(title: "Buffer", value: String(format: "%.1f s", logger.videoStats.bufferDuration))
                                StatRow(title: "Speed", value: String(format: "%.2f MB/s", logger.videoStats.downloadSpeed / 1024 / 1024))
                            }
                            GridRow {
                                StatRow(title: "Dropped", value: "\(logger.videoStats.dropFrames)")
                                Color.clear
                            }
                        }
                        .padding(.bottom, 5)
                    }
                    
                    // Remote Control Stats
                    Group {
                        Text("Remote Control")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.bottom, 1)
                        
                        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 2) {
                            GridRow {
                                StatRow(title: "Server", value: logger.serverURL)
                            }
                            GridRow {
                                StatRow(title: "Last Cmd", value: logger.lastRemoteCommand)
                            }
                        }
                        .padding(.bottom, 5)
                    }
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 1) {
                                ForEach(logger.logs) { log in
                                    Text("[\(timeString(from: log.timestamp))] \(log.message)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(log.type.color)
                                        .id(log.id)
                                }
                            }
                        }
                        .onChange(of: logger.logs.count) { _ in
                            if let lastId = logger.logs.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(10)
                .frame(width: geometry.size.width * 0.3, height: geometry.size.height * 0.5)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            .allowsHitTesting(false)
        }
    }
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(title):")
                .foregroundColor(.gray)
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
        .font(.system(size: 11, design: .monospaced))
    }
}
