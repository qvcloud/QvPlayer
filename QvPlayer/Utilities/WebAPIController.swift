import Foundation

class WebAPIController {
    static let shared = WebAPIController()
    
    private init() {}
    
    // MARK: - API Handlers
    
    func handleGetVideos() -> String? {
        let videos = MediaManager.shared.getVideos()
        DebugLogger.shared.info("API: Get Videos - Found \(videos.count) items")
        
        let jsonItems = videos.map { video -> [String: Any] in
            var dict: [String: Any] = [
                "id": video.id.uuidString,
                "title": video.title,
                "url": video.url.absoluteString,
                "group": video.group ?? "",
                "isLive": video.isLive,
                "sortOrder": video.sortOrder
            ]
            
            if let tvgName = video.tvgName {
                dict["tvgName"] = tvgName
            }
            
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
        var status = currentStatus
        status["isLooping"] = MediaManager.shared.isLoopingEnabled
        status["showDebugOverlay"] = UserDefaults.standard.bool(forKey: "showDebugOverlay")
        
        // Add Queue Data
        let items = MediaManager.shared.getPlayQueue()
        let jsonItems = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "id": item.id.uuidString,
                "videoId": item.videoId.uuidString,
                "sortOrder": item.sortOrder,
                "status": item.status.rawValue
            ]
            
            if let video = item.video {
                dict["video"] = [
                    "id": video.id.uuidString,
                    "title": video.title,
                    "url": video.url.absoluteString,
                    "group": video.group ?? "",
                    "isLive": video.isLive
                ]
            }
            
            return dict
        }
        status["queue"] = jsonItems
        
        if let data = try? JSONSerialization.data(withJSONObject: status) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func handleGetConfig() -> String? {
        let userAgent = DatabaseManager.shared.getConfig(key: "user_agent") ?? ""
        let hardwareDecode = DatabaseManager.shared.getConfig(key: "hardware_decode") ?? "true"
        let fastOpen = DatabaseManager.shared.getConfig(key: "fast_open") ?? "true"
        let rtspTransport = DatabaseManager.shared.getConfig(key: "rtsp_transport") ?? "tcp"
        let bufferDuration = DatabaseManager.shared.getConfig(key: "buffer_duration") ?? "20"
        
        // Proxy Settings (UserDefaults)
        let proxyEnabled = UserDefaults.standard.bool(forKey: "proxyEnabled")
        let proxyHost = UserDefaults.standard.string(forKey: "proxyHost") ?? ""
        let proxyPort = UserDefaults.standard.string(forKey: "proxyPort") ?? ""
        let proxyUsername = UserDefaults.standard.string(forKey: "proxyUsername") ?? ""
        let proxyPassword = UserDefaults.standard.string(forKey: "proxyPassword") ?? ""
        
        let allUserAgents = DatabaseManager.shared.getAllUserAgents()
        let userAgentsDict = allUserAgents.map { [
            "name": $0.name,
            "value": $0.value,
            "isSystem": $0.isSystem
        ] }
        
        let config: [String: Any] = [
            "userAgent": userAgent,
            "hardwareDecode": hardwareDecode == "true",
            "fastOpen": fastOpen == "true",
            "rtspTransport": rtspTransport,
            "bufferDuration": Int(bufferDuration) ?? 20,
            "userAgents": userAgentsDict,
            "proxyEnabled": proxyEnabled,
            "proxyHost": proxyHost,
            "proxyPort": proxyPort,
            "proxyUsername": proxyUsername,
            "proxyPassword": proxyPassword
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: config) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func handleUpdateConfig(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (false, "Invalid JSON")
        }
        
        if let userAgent = json["userAgent"] as? String {
            DatabaseManager.shared.setConfig(key: "user_agent", value: userAgent)
            DebugLogger.shared.info("Config updated: User-Agent = \(userAgent)")
        }
        
        if let hardwareDecode = json["hardwareDecode"] as? Bool {
            DatabaseManager.shared.setConfig(key: "hardware_decode", value: hardwareDecode ? "true" : "false")
        }
        
        if let fastOpen = json["fastOpen"] as? Bool {
            DatabaseManager.shared.setConfig(key: "fast_open", value: fastOpen ? "true" : "false")
        }
        
        if let rtspTransport = json["rtspTransport"] as? String {
            DatabaseManager.shared.setConfig(key: "rtsp_transport", value: rtspTransport)
        }
        
        if let bufferDuration = json["bufferDuration"] as? Int {
            DatabaseManager.shared.setConfig(key: "buffer_duration", value: String(bufferDuration))
        }
        
        // Proxy Settings
        if let proxyEnabled = json["proxyEnabled"] as? Bool {
            UserDefaults.standard.set(proxyEnabled, forKey: "proxyEnabled")
        }
        if let proxyHost = json["proxyHost"] as? String {
            UserDefaults.standard.set(proxyHost, forKey: "proxyHost")
        }
        if let proxyPort = json["proxyPort"] as? String {
            UserDefaults.standard.set(proxyPort, forKey: "proxyPort")
        }
        if let proxyUsername = json["proxyUsername"] as? String {
            UserDefaults.standard.set(proxyUsername, forKey: "proxyUsername")
        }
        if let proxyPassword = json["proxyPassword"] as? String {
            UserDefaults.standard.set(proxyPassword, forKey: "proxyPassword")
        }
        
        // Handle Custom User Agent Management
        if let action = json["uaAction"] as? String {
            if action == "add",
               let name = json["uaName"] as? String,
               let value = json["uaValue"] as? String {
                DatabaseManager.shared.addCustomUserAgent(name: name, value: value)
            } else if action == "delete",
                      let name = json["uaName"] as? String {
                DatabaseManager.shared.removeCustomUserAgent(name: name)
            }
        }
        
        return (true, "Configuration updated")
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
            try MediaManager.shared.appendVideo(title: title, url: url, group: group, isLive: isLive)
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
            try MediaManager.shared.deleteVideo(at: index)
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
            try MediaManager.shared.updateVideo(at: index, title: title, url: url, group: group, isLive: isLive)
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
            try MediaManager.shared.batchUpdateGroup(indices: indices, newGroup: newGroup)
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
            try MediaManager.shared.deleteVideos(at: indices)
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
            try MediaManager.shared.updateVideoSortOrder(at: index, newOrder: newOrder)
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
        
        MediaManager.shared.deleteGroup(group)
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
        case "seekTo":
            if let timeStr = queryItems.first(where: { $0.name == "time" })?.value,
               let time = Double(timeStr) {
                NotificationCenter.default.post(name: .commandSeekTo, object: nil, userInfo: ["time": time])
            }
        case "play_video":
            if let idStr = queryItems.first(where: { $0.name == "id" })?.value,
               let id = UUID(uuidString: idStr) {
                let videos = MediaManager.shared.getVideos()
                if let video = videos.first(where: { $0.id == id }) {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .commandPlayVideo, object: nil, userInfo: ["video": video])
                    }
                }
            }
        default:
            return (false, "Unknown action")
        }
        
        return (true, nil)
    }
    
    // MARK: - Queue Handlers
    
    func handleGetQueue(queryItems: [URLQueryItem]) -> String? {
        let items = MediaManager.shared.getPlayQueue()
        
        let jsonItems = items.map { item -> [String: Any] in
            var dict: [String: Any] = [
                "id": item.id.uuidString,
                "videoId": item.videoId.uuidString,
                "sortOrder": item.sortOrder,
                "status": item.status.rawValue
            ]
            
            if let video = item.video {
                dict["video"] = [
                    "id": video.id.uuidString,
                    "title": video.title,
                    "url": video.url.absoluteString,
                    "group": video.group ?? "",
                    "isLive": video.isLive
                ]
            }
            
            return dict
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: jsonItems, options: .prettyPrinted) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func handleAddToQueue(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (false, "Invalid JSON")
        }
        
        let isLooping = json["isLooping"] as? Bool
        
        // Option 1: Add single video by ID
        if let videoIdStr = json["videoId"] as? String,
           let videoId = UUID(uuidString: videoIdStr) {
            // Find video
            if let video = MediaManager.shared.getVideos().first(where: { $0.id == videoId }) {
                MediaManager.shared.addToPlayQueue(video: video, isLooping: isLooping)
                return (true, nil)
            } else {
                return (false, "Video not found")
            }
        }
        
        // Option 2: Replace queue with list of video IDs
        if let videoIds = json["videoIds"] as? [String] {
            let allVideos = MediaManager.shared.getVideos()
            var videosToAdd: [Video] = []
            
            for idStr in videoIds {
                if let uuid = UUID(uuidString: idStr),
                   let video = allVideos.first(where: { $0.id == uuid }) {
                    videosToAdd.append(video)
                }
            }
            
            MediaManager.shared.replaceQueue(videos: videosToAdd, isLooping: isLooping)
            return (true, nil)
        }
        
        return (false, "Missing videoId or videoIds")
    }
    
    func handleClearQueue(queryItems: [URLQueryItem]) -> (success: Bool, message: String?) {
        if let idStr = queryItems.first(where: { $0.name == "id" })?.value,
           let id = UUID(uuidString: idStr) {
            MediaManager.shared.removePlayQueueItem(id: id)
            return (true, nil)
        }
        
        MediaManager.shared.clearPlayQueue()
        return (true, nil)
    }
    
    func handleUpdateQueueSortOrder(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idStr = json["id"] as? String,
              let id = UUID(uuidString: idStr),
              let newOrder = json["sortOrder"] as? Int else {
            return (false, "Invalid JSON or missing fields")
        }
        
        do {
            try MediaManager.shared.updateQueueItemSortOrder(id: id, newSortOrder: newOrder)
            return (true, nil)
        } catch {
            return (false, "Failed to update queue sort order: \(error.localizedDescription)")
        }
    }
    
    func handleUpdateQueueLoopStatus(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let isLooping = json["isLooping"] as? Bool else {
            return (false, "Invalid JSON or missing isLooping")
        }
        
        MediaManager.shared.updateQueueLoopStatus(isLooping: isLooping)
        return (true, nil)
    }
    
    func handleUpdateDebugOverlay(body: String) -> (success: Bool, message: String?) {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let show = json["show"] as? Bool else {
            return (false, "Invalid JSON")
        }
        
        UserDefaults.standard.set(show, forKey: "showDebugOverlay")
        
        DispatchQueue.main.async {
            DebugLogger.shared.showDebugOverlay = show
        }
        return (true, nil)
    }
}
