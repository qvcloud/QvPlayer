import Foundation

class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    // MARK: - Migration Logic
    // We keep the old file paths just for migration purposes
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
    
    private var legacyFileURL: URL? {
        if FileManager.default.fileExists(atPath: documentsURL.path) { return documentsURL }
        if FileManager.default.fileExists(atPath: appSupportURL.path) { return appSupportURL }
        if FileManager.default.fileExists(atPath: cachesURL.path) { return cachesURL }
        return nil
    }
    
    init() {
        migrateFromM3UIfNeeded()
    }
    
    private func migrateFromM3UIfNeeded() {
        let videos = DatabaseManager.shared.getAllVideos()
        if !videos.isEmpty {
            DebugLogger.shared.info("Database already has videos. Skipping migration.")
            return
        }
        
        guard let url = legacyFileURL else {
            DebugLogger.shared.info("No legacy M3U file found. Skipping migration.")
            return
        }
        
        DebugLogger.shared.info("Migrating from M3U file at \(url.path)")
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let m3uVideos = PlaylistService.shared.parseM3U(content: content)
            
            // Also fetch old metadata if available to preserve latency info
            let metadata = DatabaseManager.shared.getAllMetadata()
            
            for (index, var video) in m3uVideos.enumerated() {
                // Preserve sort order from M3U order
                // We assign a sortOrder. Let's say higher is better.
                // If we want the first item in M3U to be first in list, it should have highest sortOrder.
                video.sortOrder = m3uVideos.count - index
                
                // Restore latency info
                let urlString = video.url.absoluteString
                if let data = metadata[urlString] {
                    video.latency = data.0
                    video.lastLatencyCheck = data.1
                }
                
                DatabaseManager.shared.addVideo(video)
            }
            
            DebugLogger.shared.info("Migration complete. \(m3uVideos.count) videos imported.")
            
            // Rename old file to .bak
            let bakURL = url.appendingPathExtension("bak")
            try? FileManager.default.moveItem(at: url, to: bakURL)
            
        } catch {
            DebugLogger.shared.error("Error during migration: \(error)")
        }
    }
    
    private func notifyUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
        }
    }
    
    // MARK: - Public API
    
    func getPlaylistVideos() -> [Video] {
        return DatabaseManager.shared.getAllVideos()
    }
    
    func updateVideoSortOrder(at index: Int, newOrder: Int) throws {
        var videos = getPlaylistVideos()
        guard index >= 0 && index < videos.count else { return }
        
        var video = videos[index]
        video.sortOrder = newOrder
        
        DatabaseManager.shared.updateVideo(video)
        notifyUpdate()
    }
    
    func appendVideo(title: String, url: String, group: String? = nil) throws {
        DebugLogger.shared.info("Appending video: \(title)")
        guard let validURL = URL(string: url) else {
            let error = NSError(domain: "PlaylistManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for video: \(url)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        
        let isLocal = url.hasPrefix("localcache://") || validURL.isFileURL
        let isLive = !isLocal
        
        var finalGroup = group
        if finalGroup == nil || finalGroup?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            finalGroup = isLocal ? "Local Uploads" : "Live Sources"
        }
        
        // Calculate new sort order (lowest - 1 to append at end)
        let videos = getPlaylistVideos()
        let minSortOrder = videos.map { $0.sortOrder }.min() ?? 0
        let newSortOrder = minSortOrder - 1
        
        let newVideo = Video(title: title, url: validURL, group: finalGroup, isLive: isLive, sortOrder: newSortOrder)
        DatabaseManager.shared.addVideo(newVideo)
        
        notifyUpdate()
    }
    
    func appendPlaylist(content: String, customGroupName: String? = nil) throws {
        DebugLogger.shared.info("Appending playlist content")
        let newVideos = PlaylistService.shared.parseM3U(content: content)
        
        let currentVideos = getPlaylistVideos()
        var minSortOrder = currentVideos.map { $0.sortOrder }.min() ?? 0
        
        var videosToAdd = [Video]()
        
        for video in newVideos {
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
            
            minSortOrder -= 1
            v.sortOrder = minSortOrder
            
            videosToAdd.append(v)
        }
        
        DatabaseManager.shared.addVideos(videosToAdd)
        notifyUpdate()
    }
    
    func replacePlaylist(content: String) throws {
        DebugLogger.shared.warning("Replacing entire playlist")
        
        // 1. Clear existing data
        DatabaseManager.shared.deleteAllVideos()
        
        // 2. Import new content
        let newVideos = PlaylistService.shared.parseM3U(content: content)
        var videosToAdd = [Video]()
        
        for (index, var video) in newVideos.enumerated() {
            // Preserve order
            video.sortOrder = newVideos.count - index
            
            if video.url.scheme?.hasPrefix("http") == true {
                video.isLive = true
            }
            if video.group == nil || video.group?.isEmpty == true {
                video.group = "Imported"
            }
            
            videosToAdd.append(video)
        }
        
        DatabaseManager.shared.addVideos(videosToAdd)
        notifyUpdate()
    }
    
    func deleteVideo(at index: Int) throws {
        let videos = getPlaylistVideos()
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
        
        DatabaseManager.shared.deleteVideo(id: video.id)
        notifyUpdate()
    }
    
    func updateVideo(at index: Int, title: String, url: String, group: String? = nil) throws {
        let videos = getPlaylistVideos()
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
        
        var video = videos[index]
        
        let isLocal = url.hasPrefix("localcache://") || validURL.isFileURL
        let isLive = !isLocal
        
        var finalGroup = group
        if finalGroup == nil || finalGroup?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            finalGroup = isLocal ? "Local Uploads" : "Live Sources"
        }
        
        video.title = title
        video.url = validURL
        video.group = finalGroup
        video.isLive = isLive
        
        DatabaseManager.shared.updateVideo(video)
        notifyUpdate()
    }
    
    func deleteVideo(_ video: Video) {
        DebugLogger.shared.info("Deleting video: \(video.title)")
        
        // Clear cache and thumbnail
        CacheManager.shared.removeCachedVideo(url: video.url)
        CacheManager.shared.removeThumbnail(for: video.url)
        
        DatabaseManager.shared.deleteVideo(id: video.id)
        notifyUpdate()
    }
    
    func deleteGroup(_ groupName: String) {
        let videos = getPlaylistVideos()
        
        // Find videos in the group
        let videosToDelete = videos.filter { $0.group == groupName }
        
        guard !videosToDelete.isEmpty else { return }
        
        DebugLogger.shared.info("Deleting group: \(groupName) with \(videosToDelete.count) videos")
        
        for video in videosToDelete {
             // Clear cache and thumbnail
             CacheManager.shared.removeCachedVideo(url: video.url)
             CacheManager.shared.removeThumbnail(for: video.url)
             DatabaseManager.shared.deleteVideo(id: video.id)
        }
        
        notifyUpdate()
    }
    
    func clearAllData() {
        DebugLogger.shared.warning("Clearing all app data (playlist + cache)")
        
        // 1. Clear Cache
        CacheManager.shared.clearAllCache()
        
        // 2. Clear Database
        DatabaseManager.shared.deleteAllVideos()
        
        // 3. Delete Legacy Playlist Files (from all possible locations)
        try? FileManager.default.removeItem(at: documentsURL)
        try? FileManager.default.removeItem(at: appSupportURL)
        try? FileManager.default.removeItem(at: cachesURL)
        
        // 4. Notify UI
        notifyUpdate()
    }

    func deleteVideos(at indices: [Int]) throws {
        let videos = getPlaylistVideos()
        
        for index in indices {
            guard index >= 0 && index < videos.count else { continue }
            let video = videos[index]
            DebugLogger.shared.info("Deleting video: \(video.title)")
            
            // Clear cache and thumbnail
            CacheManager.shared.removeCachedVideo(url: video.url)
            CacheManager.shared.removeThumbnail(for: video.url)
            
            DatabaseManager.shared.deleteVideo(id: video.id)
        }
        
        notifyUpdate()
    }
    
    func updateVideosGroup(at indices: [Int], newGroup: String) throws {
        let videos = getPlaylistVideos()
        
        for index in indices {
            guard index >= 0 && index < videos.count else { continue }
            var video = videos[index]
            video.group = newGroup
            DatabaseManager.shared.updateVideo(video)
        }
        notifyUpdate()
    }
}

extension Notification.Name {
    static let playlistDidUpdate = Notification.Name("playlistDidUpdate")
}
