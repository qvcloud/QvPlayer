import Foundation
import Combine

class SpeedTestManager: ObservableObject {
    static let shared = SpeedTestManager()
    
    private var isRunning = false
    private var task: Task<Void, Never>?
    private let session: URLSession
    
    // Concurrency control
    private let maxConcurrentTests = 1
    private let batchSize = 5
    
    // State to control load
    @Published var isHighLoad = false
    
    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 10.0
        config.httpMaximumConnectionsPerHost = 2
        self.session = URLSession(configuration: config)
        
        // Listen for player buffering events
        NotificationCenter.default.addObserver(forName: Notification.Name("playerIsBuffering"), object: nil, queue: .main) { [weak self] notification in
            if let isBuffering = notification.userInfo?["isBuffering"] as? Bool {
                self?.isHighLoad = isBuffering
                if isBuffering {
                    DebugLogger.shared.info("⏸ [SpeedTest] Pausing due to high load (Buffering)")
                } else {
                    DebugLogger.shared.info("▶️ [SpeedTest] Resuming (Load normal)")
                }
            }
        }
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        DebugLogger.shared.info("🚀 [SpeedTest] Background service started")
        
        task = Task.detached(priority: .background) { [weak self] in
            while let self = self, self.isRunning {
                if self.isHighLoad {
                    // If high load (e.g. buffering), wait longer
                    try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                    continue
                }
                
                await self.processBatch()
                
                // Wait before next batch
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            }
        }
    }
    
    func stop() {
        isRunning = false
        task?.cancel()
        task = nil
        DebugLogger.shared.info("🛑 [SpeedTest] Background service stopped")
    }
    
    private func processBatch() async {
        let videos = DatabaseManager.shared.getVideosForSpeedTest(limit: batchSize)
        
        if videos.isEmpty {
            // No videos need testing, sleep longer
            try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
            return
        }
        
        DebugLogger.shared.info("⚡️ [SpeedTest] Testing batch of \(videos.count) videos")
        
        for video in videos {
            if !isRunning { break }
            
            // Check if we should pause due to high load
            while isHighLoad {
                try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            }
            
            await testVideo(video)
            
            // Gentle delay between requests
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        }
    }
    
    private func testVideo(_ video: Video) async {
        let start = Date()
        var latency: Double = -1
        
        do {
            var request = URLRequest(url: video.url)
            request.httpMethod = "HEAD"
            // Some servers reject HEAD, fallback to GET with range if needed, 
            // but for now HEAD is safest for low bandwidth.
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, 
               (200...299).contains(httpResponse.statusCode) {
                latency = Date().timeIntervalSince(start) * 1000 // ms
            } else {
                // 404 or other error
                latency = -1
            }
        } catch {
            // Timeout or connection error
            latency = -1
        }
        
        // Update DB
        DatabaseManager.shared.saveLatency(for: video.url.absoluteString, latency: latency, lastCheck: Date())
        
        if latency > 0 {
            DebugLogger.shared.info("✅ [SpeedTest] \(video.title): \(Int(latency))ms")
        } else {
            // DebugLogger.shared.info("❌ [SpeedTest] \(video.title): Failed")
        }
    }
}
