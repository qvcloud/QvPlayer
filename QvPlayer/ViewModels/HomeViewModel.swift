import Foundation

struct VideoGroup: Identifiable {
    let id = UUID()
    let name: String
    let videos: [Video]
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var videoGroups: [VideoGroup] = []
    @Published var localVideoGroups: [VideoGroup] = []
    @Published var liveVideoGroups: [VideoGroup] = []
    @Published var isLoading: Bool = false
    
    init() {
        Task {
            await loadVideos()
        }
        
        // Listen for playlist updates from WebServer
        NotificationCenter.default.addObserver(forName: .playlistDidUpdate, object: nil, queue: .main) { [weak self] _ in
            Task {
                await self?.loadVideos()
            }
        }
    }
    
    func loadVideos() async {
        DebugLogger.shared.info("Loading videos...")
        isLoading = true
        defer { isLoading = false }
        
        // Try to load from local storage first
        let localVideos = PlaylistManager.shared.getPlaylistVideos()
        if !localVideos.isEmpty {
            DebugLogger.shared.info("Loaded \(localVideos.count) videos from local storage")
            self.videos = localVideos
            self.groupVideos(localVideos)
            return
        }
        
        DebugLogger.shared.warning("No local playlist found, using sample videos")
        // Fallback to sample videos if no local playlist
        self.videos = [
            Video(title: "CGTN Live", url: URL(string: "https://0472.org/hls/cgtn.m3u8")!, group: "Live Sources", isLive: true, description: "CGTN Live Stream"),
            Video(title: "CCTV-13 News", url: URL(string: "http://ivi.bupt.edu.cn/hls/cctv13hd.m3u8")!, group: "Live Sources", isLive: true, description: "CCTV-13 News Live Stream"),
            Video(title: "Big Buck Bunny", url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!, group: "Movies", isLive: false, description: "Big Buck Bunny is a short computer-animated comedy film.")
        ]
        self.groupVideos(self.videos)
    }
    
    private func groupVideos(_ videos: [Video]) {
        DebugLogger.shared.info("Grouping \(videos.count) videos")
        
        // Split into local and live
        let localVideos = videos.filter { !$0.isLive }
        let liveVideos = videos.filter { $0.isLive }
        
        // Group Local
        let localGrouped = Dictionary(grouping: localVideos) { $0.group ?? "Ungrouped" }
        let localSortedKeys = localGrouped.keys.sorted {
            if $0 == "Ungrouped" { return false }
            if $1 == "Ungrouped" { return true }
            return $0 < $1
        }
        self.localVideoGroups = localSortedKeys.map { key in
            VideoGroup(name: key, videos: localGrouped[key] ?? [])
        }
        
        // Group Live
        let liveGrouped = Dictionary(grouping: liveVideos) { $0.group ?? "Ungrouped" }
        let liveSortedKeys = liveGrouped.keys.sorted {
            if $0 == "Ungrouped" { return false }
            if $1 == "Ungrouped" { return true }
            return $0 < $1
        }
        self.liveVideoGroups = liveSortedKeys.map { key in
            VideoGroup(name: key, videos: liveGrouped[key] ?? [])
        }
        
        // Keep original for backward compatibility if needed, or just union
        self.videoGroups = self.localVideoGroups + self.liveVideoGroups
    }
}
