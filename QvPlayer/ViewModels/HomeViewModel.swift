import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var videos: [Video] = []
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
            return
        }
        
        // Fallback to sample videos if no local playlist
        self.videos = [
            Video(title: "CGTN Live", url: URL(string: "https://0472.org/hls/cgtn.m3u8")!, isLive: true, description: "CGTN Live Stream"),
            Video(title: "Big Buck Bunny", url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!, isLive: false, description: "Big Buck Bunny is a short computer-animated comedy film.")
        ]
    }
}
