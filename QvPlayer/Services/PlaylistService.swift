import Foundation

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var videos: [Video]
    
    init(id: UUID = UUID(), name: String, videos: [Video] = []) {
        self.id = id
        self.name = name
        self.videos = videos
    }
}

class PlaylistService {
    static let shared = PlaylistService()
    
    private init() {}
    
    func parseM3U(content: String) -> [Video] {
        var videos: [Video] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentTitle: String?
        
        for line in lines {
            if line.hasPrefix("#EXTINF:") {
                // Example: #EXTINF:-1,Channel Name
                let components = line.components(separatedBy: ",")
                if components.count > 1 {
                    currentTitle = components.last?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if line.hasPrefix("http") || line.hasPrefix("https") {
                if let url = URL(string: line.trimmingCharacters(in: .whitespacesAndNewlines)), let title = currentTitle {
                    videos.append(Video(title: title, url: url, isLive: true))
                    currentTitle = nil
                }
            }
        }
        
        return videos
    }
    
    // Future: Add methods to save/load playlists from UserDefaults or SwiftData
}
