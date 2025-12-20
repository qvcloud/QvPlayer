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
            // Post notification or update observable to reload
            NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
        } catch {
            print("Error saving playlist: \(error)")
        }
    }
    
    func loadPlaylist() -> String? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Error loading playlist: \(error)")
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
        guard let validURL = URL(string: url) else { return }
        var videos = getPlaylistVideos()
        let isLive = !validURL.isFileURL
        let newVideo = Video(title: title, url: validURL, group: group, isLive: isLive)
        videos.append(newVideo)
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        savePlaylist(content: newContent)
    }
    
    func deleteVideo(at index: Int) {
        var videos = getPlaylistVideos()
        guard index >= 0 && index < videos.count else { return }
        videos.remove(at: index)
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        savePlaylist(content: newContent)
    }
    
    func updateVideo(at index: Int, title: String, url: String, group: String? = nil) {
        var videos = getPlaylistVideos()
        guard index >= 0 && index < videos.count else { return }
        guard let validURL = URL(string: url) else { return }
        
        var video = videos[index]
        video.title = title
        video.url = validURL
        video.group = group
        videos[index] = video
        
        let newContent = PlaylistService.shared.generateM3U(from: videos)
        savePlaylist(content: newContent)
    }
}

extension Notification.Name {
    static let playlistDidUpdate = Notification.Name("playlistDidUpdate")
}
