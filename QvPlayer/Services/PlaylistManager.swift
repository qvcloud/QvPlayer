import Foundation

class PlaylistManager: ObservableObject {
    static let shared = PlaylistManager()
    
    private let fileName = "playlist.m3u"
    
    private var fileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    func savePlaylist(content: String) {
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            DebugLogger.shared.info("Playlist saved successfully")
            // Post notification or update observable to reload
            NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
        } catch {
            DebugLogger.shared.error("Error saving playlist: \(error)")
        }
    }
    
    func loadPlaylist() -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            DebugLogger.shared.info("No existing playlist found")
            return nil
        }
        
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            DebugLogger.shared.info("Playlist loaded successfully")
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
    
    func appendVideo(title: String, url: String, group: String? = nil) {
        DebugLogger.shared.info("Appending video: \(title)")
        guard let validURL = URL(string: url) else {
            DebugLogger.shared.error("Invalid URL for video: \(url)")
            return
        }
        var videos = getPlaylistVideos()
        let isLive = !validURL.isFileURL
        let newVideo = Video(title: title, url: validURL, group: group, isLive: isLive)
        videos.append(newVideo)
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        savePlaylist(content: newContent)
    }
    
    func deleteVideo(at index: Int) {
        var videos = getPlaylistVideos()
        guard index >= 0 && index < videos.count else {
            DebugLogger.shared.error("Invalid index for deletion: \(index)")
            return
        }
        let video = videos[index]
        DebugLogger.shared.info("Deleting video: \(video.title)")
        
        // Clear cache and thumbnail
        CacheManager.shared.removeCachedVideo(url: video.url)
        CacheManager.shared.removeThumbnail(for: video.url)
        
        videos.remove(at: index)
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        savePlaylist(content: newContent)
    }
    
    func updateVideo(at index: Int, title: String, url: String, group: String? = nil) {
        var videos = getPlaylistVideos()
        guard index >= 0 && index < videos.count else {
            DebugLogger.shared.error("Invalid index for update: \(index)")
            return
        }
        guard let validURL = URL(string: url) else {
            DebugLogger.shared.error("Invalid URL for update: \(url)")
            return
        }
        
        DebugLogger.shared.info("Updating video at index \(index): \(title)")
        var video = videos[index]
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        savePlaylist(content: newContent)
    }
}

extension Notification.Name {
    static let playlistDidUpdate = Notification.Name("playlistDidUpdate")
}
