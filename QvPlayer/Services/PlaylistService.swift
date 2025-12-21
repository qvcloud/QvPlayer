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
        DebugLogger.shared.info("Parsing M3U content...")
        var videos: [Video] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentTitle: String?
        var currentGroup: String?
        var currentLatency: Double?
        var currentLastCheck: Date?
        var currentSortOrder: Int = 0
        
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
            } else if trimmedLine.hasPrefix("#QV-LATENCY:") {
                if let val = Double(trimmedLine.dropFirst("#QV-LATENCY:".count)) {
                    currentLatency = val
                }
            } else if trimmedLine.hasPrefix("#QV-LAST-CHECK:") {
                if let val = Double(trimmedLine.dropFirst("#QV-LAST-CHECK:".count)) {
                    currentLastCheck = Date(timeIntervalSince1970: val)
                }
            } else if !trimmedLine.hasPrefix("#") {
                // Standard URL handling
                if let url = URL(string: trimmedLine) {
                    let title = currentTitle ?? "Unknown Channel"
                    var isLive = true
                    var cachedURL: URL? = nil
                    
                    if url.isFileURL {
                        isLive = false
                        cachedURL = url
                    }
                    
                    videos.append(Video(title: title, url: url, group: currentGroup, isLive: isLive, cachedURL: cachedURL, latency: currentLatency, lastLatencyCheck: currentLastCheck, sortOrder: currentSortOrder))
                    
                    currentTitle = nil
                    currentGroup = nil
                    currentLatency = nil
                    currentLastCheck = nil
                    currentSortOrder = 0
                }
            } else if trimmedLine.hasPrefix("#QV-ORDER:") {
                if let val = Int(trimmedLine.dropFirst("#QV-ORDER:".count).trimmingCharacters(in: .whitespaces)) {
                    currentSortOrder = val
                }
            }
        }
        DebugLogger.shared.info("Parsed \(videos.count) videos from M3U")
        
        return videos
    }
    
    // Future: Add methods to save/load playlists from UserDefaults or SwiftData
}
