import Foundation

class WebAPIController {
    static let shared = WebAPIController()
    
    private init() {}
    
    // MARK: - API Handlers
    
    func handleGetVideos() -> String? {
        let videos = PlaylistManager.shared.getPlaylistVideos()
        DebugLogger.shared.info("API: Get Videos - Found \(videos.count) items")
        
        let jsonItems = videos.map { video -> [String: Any] in
            var dict: [String: Any] = [
                "title": video.title,
                "url": video.url.absoluteString,
                "group": video.group ?? "",
                "isLive": video.isLive,
                "sortOrder": video.sortOrder
            ]
            
            if let latency = video.latency {
                dict["latency"] = latency
            }
            
            if let lastCheck = video.lastLatencyCheck {
                dict["lastLatencyCheck"] = lastCheck.timeIntervalSince1970
            }
            
            return dict
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: jsonItems, options: .prettyPrinted) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func handleGetStatus(currentStatus: [String: Any]) -> String? {
        if let data = try? JSONSerialization.data(withJSONObject: currentStatus) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func handleAddVideo(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String,
              let url = json["url"] as? String else {
            return (false, "Invalid JSON or missing fields")
        }
        
        let group = json["group"] as? String
        let isLive = json["isLive"] as? Bool
        
        do {
            try PlaylistManager.shared.appendVideo(title: title, url: url, group: group, isLive: isLive)
            return (true, nil)
        } catch {
            return (false, "Failed to add video: \(error.localizedDescription)")
        }
    }
    
    func handleDeleteVideo(queryItems: [URLQueryItem]) -> (success: Bool, message: String?) {
        guard let indexStr = queryItems.first(where: { $0.name == "index" })?.value,
              let index = Int(indexStr) else {
            return (false, "Missing or invalid index parameter")
        }
        
        do {
            try PlaylistManager.shared.deleteVideo(at: index)
            return (true, nil)
        } catch {
            return (false, "Failed to delete video: \(error.localizedDescription)")
        }
    }
    
    func handleUpdateVideo(queryItems: [URLQueryItem], body: String) -> (success: Bool, message: String?) {
        guard let indexStr = queryItems.first(where: { $0.name == "index" })?.value,
              let index = Int(indexStr) else {
            return (false, "Missing or invalid index parameter")
        }
        
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String,
              let url = json["url"] as? String else {
            return (false, "Invalid JSON or missing fields")
        }
        
        let group = json["group"] as? String
        let isLive = json["isLive"] as? Bool
        
        do {
            try PlaylistManager.shared.updateVideo(at: index, title: title, url: url, group: group, isLive: isLive)
            return (true, nil)
        } catch {
            return (false, "Failed to update video: \(error.localizedDescription)")
        }
    }
    
    func handleBatchUpdateGroup(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let indices = json["indices"] as? [Int],
              let newGroup = json["group"] as? String else {
            return (false, "Invalid JSON or missing fields")
        }
        
        do {
            try PlaylistManager.shared.batchUpdateGroup(indices: indices, newGroup: newGroup)
            return (true, nil)
        } catch {
            return (false, "Failed to batch update group: \(error.localizedDescription)")
        }
    }
    
    func handleBatchDeleteVideo(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let indices = json["indices"] as? [Int] else {
            return (false, "Invalid JSON or missing indices")
        }
        
        do {
            try PlaylistManager.shared.deleteVideos(at: indices)
            return (true, nil)
        } catch {
            return (false, "Failed to delete videos: \(error.localizedDescription)")
        }
    }
    
    func handleUpdateSortOrder(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let index = json["index"] as? Int,
              let newOrder = json["sortOrder"] as? Int else {
            return (false, "Invalid JSON or missing fields")
        }
        
        do {
            try PlaylistManager.shared.updateVideoSortOrder(at: index, newOrder: newOrder)
            return (true, nil)
        } catch {
            return (false, "Failed to update sort order: \(error.localizedDescription)")
        }
    }
    
    func handleDeleteGroup(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let group = json["group"] as? String else {
            return (false, "Invalid JSON or missing group")
        }
        
        PlaylistManager.shared.deleteGroup(group)
        return (true, nil)
    }
    
    func handleControl(path: String, queryItems: [URLQueryItem]) -> (success: Bool, message: String?) {
        let action = path.replacingOccurrences(of: "/api/v1/control/", with: "")
        
        DispatchQueue.main.async {
            DebugLogger.shared.lastRemoteCommand = action
        }
        
        switch action {
        case "play":
            NotificationCenter.default.post(name: .commandPlay, object: nil)
        case "pause":
            NotificationCenter.default.post(name: .commandPause, object: nil)
        case "toggle":
            NotificationCenter.default.post(name: .commandToggle, object: nil)
        case "seek":
            if let secondsStr = queryItems.first(where: { $0.name == "time" })?.value,
               let seconds = Double(secondsStr) {
                NotificationCenter.default.post(name: .commandSeek, object: nil, userInfo: ["seconds": seconds])
            }
        case "play_video":
            if let indexStr = queryItems.first(where: { $0.name == "index" })?.value,
               let index = Int(indexStr) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .commandPlayVideo, object: nil, userInfo: ["index": index])
                }
            }
        default:
            return (false, "Unknown action")
        }
        
        return (true, nil)
    }
}
