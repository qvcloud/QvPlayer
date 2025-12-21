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
                // Handle custom localcache scheme
                var finalURL: URL?
                if trimmedLine.hasPrefix("localcache://") {
                    let rawFilename = String(trimmedLine.dropFirst("localcache://".count))
                    let filename = rawFilename.removingPercentEncoding ?? rawFilename
                    finalURL = CacheManager.shared.getFileURL(filename: filename)
                } else {
                    finalURL = URL(string: trimmedLine)
                }
                
                // Assume it's a URL (http, https, or file)
                if let url = finalURL {
                    var validURL = url
                    let title = currentTitle ?? "Unknown Channel"
                    // Check cache only for remote URLs
                    var cachedURL: URL? = nil
                    var isLive = true
                    
                    if validURL.isFileURL {
                        // Self-healing: If file doesn't exist, check if it's in the current cache
                        if !FileManager.default.fileExists(atPath: validURL.path) {
                            let filename = validURL.lastPathComponent
                            let potentialNewURL = CacheManager.shared.getFileURL(filename: filename)
                            if FileManager.default.fileExists(atPath: potentialNewURL.path) {
                                DebugLogger.shared.warning("Recovered broken file path for: \(filename)")
                                validURL = potentialNewURL
                            } else {
                                DebugLogger.shared.error("File not found for: \(filename)")
                            }
                        }
                        
                        cachedURL = validURL
                        isLive = false
                    } else if validURL.scheme?.lowercased().hasPrefix("http") == true {
                         cachedURL = CacheManager.shared.isCached(remoteURL: validURL) ? CacheManager.shared.getCachedFileURL(for: validURL) : nil
                    }
                    
                    videos.append(Video(title: title, url: validURL, group: currentGroup, isLive: isLive, cachedURL: cachedURL, latency: currentLatency, lastLatencyCheck: currentLastCheck))
                    currentTitle = nil
                    currentGroup = nil
                    currentLatency = nil
                    currentLastCheck = nil
                }
            }
        DebugLogger.shared.info("Parsed \(videos.count) videos from M3U")
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
            
            // Add custom tags for latency
            if let latency = video.latency {
                content += "#QV-LATENCY:\(latency)\n"
            }
            if let lastCheck = video.lastLatencyCheck {
                content += "#QV-LAST-CHECK:\(lastCheck.timeIntervalSince1970)\n"
            }
            
            var urlString = video.url.absoluteString
            if video.url.isFileURL {
                let filename = video.url.lastPathComponent
                let expectedCacheURL = CacheManager.shared.getFileURL(filename: filename)
                // Compare paths to handle potential scheme differences (file://)
                if video.url.path == expectedCacheURL.path {
                    let encodedFilename = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
                    urlString = "localcache://\(encodedFilename)"
                }
            }
            
            content += "\(urlString)\n"
        }
        return content
    }
    
    // Future: Add methods to save/load playlists from UserDefaults or SwiftData
}
