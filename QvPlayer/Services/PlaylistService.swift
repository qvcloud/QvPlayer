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
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            if trimmedLine.hasPrefix("#EXTINF:") {
                // Example: #EXTINF:-1,Channel Name
                let components = trimmedLine.components(separatedBy: ",")
                if components.count > 1 {
                    currentTitle = components.last?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if trimmedLine.hasPrefix("http") || trimmedLine.hasPrefix("https") {
                if let url = URL(string: trimmedLine) {
                    let title = currentTitle ?? "Unknown Channel"
                    videos.append(Video(title: title, url: url, isLive: true))
                    currentTitle = nil
                }
            }
        }
        
        return videos
    }
    
    func generateM3U(from videos: [Video]) -> String {
        var content = "#EXTM3U\n"
        for video in videos {
            content += "#EXTINF:-1,\(video.title)\n"
            content += "\(video.url.absoluteString)\n"
        }
        return content
    }
    
    // Future: Add methods to save/load playlists from UserDefaults or SwiftData
}
