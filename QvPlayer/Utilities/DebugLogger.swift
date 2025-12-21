import Foundation
import SwiftUI

class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let type: LogType
    }
    
    struct VideoStats {
        var url: String = "-"
        var resolution: String = "-"
        var fps: Double = 0.0
        var bitrate: Double = 0.0
        var codec: String = "-"
        var dropFrames: Int = 0
        var downloadSpeed: Double = 0.0
        var bufferDuration: Double = 0.0
        var serverAddress: String = "-"
        var status: String = "-"
        var bytesRead: Int64 = 0
        var currentTime: Double = 0.0
        var duration: Double = 0.0
    }
    
    enum LogType {
        case info
        case warning
        case error
        
        var color: Color {
            switch self {
            case .info: return .white
            case .warning: return .yellow
            case .error: return .red
            }
        }
    }
    
    @Published var logs: [LogEntry] = []
    @Published var videoStats: VideoStats = VideoStats()
    @Published var serverURL: String = "Stopped"
    @Published var lastRemoteCommand: String = "-"
    @AppStorage("showDebugOverlay") var showDebugOverlay = false
    
    private init() {}
    
    func log(_ message: String, type: LogType = .info) {
        let timestamp = Date()
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: timestamp, message: message, type: type)
            self.logs.append(entry)
            // Keep only last 100 logs
            if self.logs.count > 100 {
                self.logs.removeFirst()
            }
        }
        // Also print to console with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        print("[\(formatter.string(from: timestamp))] [\(type)] \(message)")
    }
    
    func info(_ message: String) {
        log(message, type: .info)
    }
    
    func warning(_ message: String) {
        log(message, type: .warning)
    }
    
    func error(_ message: String) {
        log(message, type: .error)
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}
