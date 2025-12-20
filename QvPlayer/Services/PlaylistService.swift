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
        var currentGroup: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }
            
            if trimmedLine.hasPrefix("#EXTINF:") {
                // Example: #EXTINF:-1 group-title="News",Channel Name
                // Parse group-title
                if let groupRange = trimmedLine.range(of: "group-title=\"([^\"]+)\"", options: .regularExpression) {
                    let groupMatch = String(trimmedLine[groupRange])
                    // Extract value inside quotes
                    if let startQuote = groupMatch.firstIndex(of: "\""),
                       let endQuote = groupMatch.lastIndex(of: "\""),
                       startQuote != endQuote {
                        let groupName = String(groupMatch[groupMatch.index(after: startQuote)..<endQuote])
                        currentGroup = groupName
                    }
                } else {
                    currentGroup = nil
                }
                
                // Parse Title (everything after the last comma)
                let components = trimmedLine.components(separatedBy: ",")
                if components.count > 1 {
                    currentTitle = components.last?.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if trimmedLine.hasPrefix("http") || trimmedLine.hasPrefix("https") {
                if let url = URL(string: trimmedLine) {
                    let title = currentTitle ?? "Unknown Channel"
                    videos.append(Video(title: title, url: url, group: currentGroup, isLive: true))
                    currentTitle = nil
                    currentGroup = nil
                }
            }
        }
        
        return videos
    }
    
    func generateM3U(from videos: [Video]) -> String {
        var content = "#EXTM3U\n"
        for video in videos {
            var extInf = "#EXTINF:-1"
            if let group = video.group, !group.isEmpty {
                extInf += " group-title=\"\(group)\""
            }
            extInf += ",\(video.title)"
            
            content += "\(extInf)\n"
            content += "\(video.url.absoluteString)\n"
        }
        return content
    }
    
    // Future: Add methods to save/load playlists from UserDefaults or SwiftData
}
