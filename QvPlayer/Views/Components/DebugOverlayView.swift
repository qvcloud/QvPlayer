import SwiftUI

struct DebugOverlayView: View {
    @StateObject private var logger = DebugLogger.shared
    @AppStorage("playerEngine") private var playerEngine = "system"
    
    var body: some View {
        if logger.showDebugOverlay {
            GeometryReader { geometry in
                VStack(alignment: .leading) {
                    HStack {
                        Text("Debug Console")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("Engine: \(playerEngine == "ksplayer" ? "KSPlayer" : "System")")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.bottom, 5)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(logger.logs) { log in
                                    Text("[\(timeString(from: log.timestamp))] \(log.message)")
                                        .font(.system(size: 12, design: .monospaced))
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
                .padding()
                .background(Color.black.opacity(0.8))
                .cornerRadius(10)
                .frame(width: geometry.size.width * 0.5, height: 300)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
