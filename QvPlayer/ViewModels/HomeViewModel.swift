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
        isLoading = true
        defer { isLoading = false }
        
        // Try to load from local storage first
        let localVideos = PlaylistManager.shared.getPlaylistVideos()
        if !localVideos.isEmpty {
            self.videos = localVideos
            self.groupVideos(localVideos)
            return
        }
        
        // Fallback to sample videos if no local playlist
        self.videos = [
            Video(title: "CGTN Live", url: URL(string: "https://0472.org/hls/cgtn.m3u8")!, group: "News", isLive: true, description: "CGTN Live Stream"),
            Video(title: "Big Buck Bunny", url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!, group: "Movies", isLive: false, description: "Big Buck Bunny is a short computer-animated comedy film.")
        ]
        self.groupVideos(self.videos)
    }
    
    private func groupVideos(_ videos: [Video]) {
        let groupedDictionary = Dictionary(grouping: videos) { $0.group ?? "Ungrouped" }
        
        let sortedKeys = groupedDictionary.keys.sorted {
            if $0 == "Ungrouped" { return false } // Ungrouped at the end
            if $1 == "Ungrouped" { return true }
            return $0 < $1
        }
        
        self.videoGroups = sortedKeys.map { key in
            VideoGroup(name: key, videos: groupedDictionary[key] ?? [])
        }
    }
}
