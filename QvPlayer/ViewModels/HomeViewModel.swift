import Foundation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading: Bool = false
    
    init() {
        Task {
            await loadSampleVideos()
        }
    }
    
    func loadSampleVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate network delay for better UX feedback
        try? await Task.sleep(for: .seconds(0.5))
        
        self.videos = [
            Video(title: "CGTN Live", url: URL(string: "https://0472.org/hls/cgtn.m3u8")!, isLive: true, description: "CGTN Live Stream"),
            Video(title: "Big Buck Bunny", url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!, isLive: false, description: "Big Buck Bunny is a short computer-animated comedy film.")
        ]
    }
}
