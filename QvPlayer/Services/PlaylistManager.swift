import Foundation

class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    private let fileName = "playlist.m3u"
    

    
    private var documentsURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    private var appSupportURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent(fileName)
    }
    
    private var cachesURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent(fileName)
    }
    
    // Dynamic file URL based on availability
    private var fileURL: URL {
        // Check where the file currently exists
        if FileManager.default.fileExists(atPath: documentsURL.path) { return documentsURL }
        if FileManager.default.fileExists(atPath: appSupportURL.path) { return appSupportURL }
        if FileManager.default.fileExists(atPath: cachesURL.path) { return cachesURL }
        
        // Default for new file: Try Documents -> App Support -> Caches
        return documentsURL
    }
    
    func savePlaylist(content: String) throws {
        // Try saving to Documents first
        if (try? save(content: content, to: documentsURL)) != nil { return }
        
        // Try Application Support
        if (try? save(content: content, to: appSupportURL)) != nil { return }
        
        // Fallback to Caches
        try save(content: content, to: cachesURL)
    }
    
    private func save(content: String, to url: URL) throws {
        do {
            // Ensure directory exists
            let directory = url.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // Try to write
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                DebugLogger.shared.error("Failed to write atomically to \(url.path): \(error)")
                try content.write(to: url, atomically: false, encoding: .utf8)
            }
            
            // Set file protection to none
            try? (url as NSURL).setResourceValue(FileProtectionType.none, forKey: .fileProtectionKey)
            
            DebugLogger.shared.info("Playlist saved successfully to \(url.path)")
            NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
        } catch {
            DebugLogger.shared.error("Error saving playlist to \(url.path): \(error)")
            throw error
        }
    }
    
    func loadPlaylist() -> String? {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            DebugLogger.shared.info("No existing playlist found")
            return nil
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            DebugLogger.shared.info("Playlist loaded successfully from \(url.path)")
            return content
        } catch {
            DebugLogger.shared.error("Error loading playlist: \(error)")
            return nil
        }
    }
    
    func getPlaylistVideos() -> [Video] {
        if let content = loadPlaylist() {
            return PlaylistService.shared.parseM3U(content: content)
        }
        return []
    }
    
    func appendVideo(title: String, url: String, group: String? = nil) throws {
        DebugLogger.shared.info("Appending video: \(title)")
        guard let validURL = URL(string: url) else {
            let error = NSError(domain: "PlaylistManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for video: \(url)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        var videos = getPlaylistVideos()
        
        let isLocal = url.hasPrefix("localcache://") || validURL.isFileURL
        let isLive = !isLocal
        
        var finalGroup = group
        if finalGroup == nil || finalGroup?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            finalGroup = isLocal ? "Local Uploads" : "Live Sources"
        }
        
        let newVideo = Video(title: title, url: validURL, group: finalGroup, isLive: isLive)
        videos.append(newVideo)
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        try savePlaylist(content: newContent)
    }
    
    func appendPlaylist(content: String, customGroupName: String? = nil) throws {
        DebugLogger.shared.info("Appending playlist content")
        var videos = getPlaylistVideos()
        let newVideos = PlaylistService.shared.parseM3U(content: content)
        
        // Update group for new videos if needed, or keep as is
        // For imported playlists, we usually want to keep their groups or default to "Imported"
        // But parseM3U already handles group-title.
        
        // We should ensure isLive is set correctly for these
        let processedVideos = newVideos.map { video -> Video in
            var v = video
            // If it's http/https, it's likely live or remote
            if v.url.scheme?.hasPrefix("http") == true {
                v.isLive = true
            }
            
            if let customGroup = customGroupName {
                v.group = customGroup
            } else if v.group == nil || v.group?.isEmpty == true {
                v.group = "Imported"
            }
            return v
        }
        
        videos.append(contentsOf: processedVideos)
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        try savePlaylist(content: newContent)
    }
    
    func deleteVideo(at index: Int) throws {
        var videos = getPlaylistVideos()
        guard index >= 0 && index < videos.count else {
            let error = NSError(domain: "PlaylistManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid index for deletion: \(index)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        let video = videos[index]
        DebugLogger.shared.info("Deleting video: \(video.title)")
        
        // Clear cache and thumbnail
        CacheManager.shared.removeCachedVideo(url: video.url)
        CacheManager.shared.removeThumbnail(for: video.url)
        
        videos.remove(at: index)
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        try savePlaylist(content: newContent)
    }
    
    func updateVideo(at index: Int, title: String, url: String, group: String? = nil) throws {
        var videos = getPlaylistVideos()
        guard index >= 0 && index < videos.count else {
            let error = NSError(domain: "PlaylistManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid index for update: \(index)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        guard let validURL = URL(string: url) else {
            let error = NSError(domain: "PlaylistManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for update: \(url)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        
        DebugLogger.shared.info("Updating video at index \(index): \(title)")
        
        let isLocal = url.hasPrefix("localcache://") || validURL.isFileURL
        let isLive = !isLocal
        
        var finalGroup = group
        if finalGroup == nil || finalGroup?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            finalGroup = isLocal ? "Local Uploads" : "Live Sources"
        }
        
        let newVideo = Video(title: title, url: validURL, group: finalGroup, isLive: isLive)
        videos[index] = newVideo
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        try savePlaylist(content: newContent)
    }
    
    func deleteVideo(_ video: Video) {
        var videos = getPlaylistVideos()
        // Match by ID or URL if ID fails (for backward compatibility or if IDs are regenerated)
        if let index = videos.firstIndex(where: { $0.id == video.id || $0.url == video.url }) {
            DebugLogger.shared.info("Deleting video: \(video.title)")
            
            // Clear cache and thumbnail
            CacheManager.shared.removeCachedVideo(url: video.url)
            CacheManager.shared.removeThumbnail(for: video.url)
            
            videos.remove(at: index)
            
            let newContent = PlaylistService.shared.generateM3U(from: videos)
            try? savePlaylist(content: newContent)
        }
    }
    
    func deleteGroup(_ groupName: String) {
        var videos = getPlaylistVideos()
        
        // Find videos in the group
        let videosToDelete = videos.filter { $0.group == groupName }
        
        guard !videosToDelete.isEmpty else { return }
        
        DebugLogger.shared.info("Deleting group: \(groupName) with \(videosToDelete.count) videos")
        
        for video in videosToDelete {
             // Clear cache and thumbnail
             CacheManager.shared.removeCachedVideo(url: video.url)
             CacheManager.shared.removeThumbnail(for: video.url)
        }
        
        // Remove videos from the list
        videos.removeAll { $0.group == groupName }
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        try? savePlaylist(content: newContent)
    }
    
    func clearAllData() {
        DebugLogger.shared.warning("Clearing all app data (playlist + cache)")
        
        // 1. Clear Cache
        CacheManager.shared.clearAllCache()
        
        // 2. Delete Playlist Files (from all possible locations)
        try? FileManager.default.removeItem(at: documentsURL)
        try? FileManager.default.removeItem(at: appSupportURL)
        try? FileManager.default.removeItem(at: cachesURL)
        
        // 3. Notify UI
        NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
    }

    func deleteVideos(at indices: [Int]) throws {
        var videos = getPlaylistVideos()
        let sortedIndices = indices.sorted(by: >)
        
        for index in sortedIndices {
            guard index >= 0 && index < videos.count else { continue }
            let video = videos[index]
            DebugLogger.shared.info("Deleting video: \(video.title)")
            
            // Clear cache and thumbnail
            CacheManager.shared.removeCachedVideo(url: video.url)
            CacheManager.shared.removeThumbnail(for: video.url)
            
            videos.remove(at: index)
        }
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        try savePlaylist(content: newContent)
    }
    
    func updateVideosGroup(at indices: [Int], newGroup: String) throws {
        var videos = getPlaylistVideos()
        
        for index in indices {
            guard index >= 0 && index < videos.count else { continue }
            var video = videos[index]
            video.group = newGroup
            videos[index] = video
        }
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        try savePlaylist(content: newContent)
    }
    
    func updateVideoLatency(at index: Int, latency: Double, lastCheck: Date) {
        var videos = getPlaylistVideos()
        guard index >= 0 && index < videos.count else { return }
        
        var video = videos[index]
        video.latency = latency
        video.lastLatencyCheck = lastCheck
        videos[index] = video
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        try? savePlaylist(content: newContent)
    }
}

extension Notification.Name {
    static let playlistDidUpdate = Notification.Name("playlistDidUpdate")
}
