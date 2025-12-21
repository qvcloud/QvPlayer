import Foundation

class MediaManager: ObservableObject {
    static let shared = MediaManager()
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(forName: .playerStatusDidUpdate, object: nil, queue: .main) { [weak self] notification in
            self?.handlePlayerStatusUpdate(notification)
        }
        
        NotificationCenter.default.addObserver(forName: .playerDidFinishPlaying, object: nil, queue: .main) { [weak self] _ in
            self?.handlePlaybackFinished()
        }
    }
    
    private var currentPlayingVideoId: UUID?
    private var isPlayerPlaying: Bool = false
    
    private func handlePlayerStatusUpdate(_ notification: Notification) {
        guard let status = notification.userInfo?["status"] as? [String: Any],
              let isPlaying = status["isPlaying"] as? Bool,
              let idString = status["id"] as? String,
              let videoId = UUID(uuidString: idString) else { return }
        
        self.isPlayerPlaying = isPlaying
        
        if isPlaying && currentPlayingVideoId != videoId {
            DebugLogger.shared.info("Queue: Player started new video \(videoId)")
            currentPlayingVideoId = videoId
            
            let queue = getPlayQueue()
            
            // 1. Mark any previously 'playing' items as 'played' (skipped)
            // This ensures we don't have multiple playing items
            for item in queue where item.status == .playing && item.videoId != videoId {
                DebugLogger.shared.info("Queue: Marking skipped item \(item.id) as played")
                updateQueueItemStatus(id: item.id, status: .played)
            }
            
            // 2. Mark this video as playing in the queue
            // We find the first 'pending' item with this videoId
            // If not found, check if there's a 'played' one (re-playing)
            if let item = queue.first(where: { $0.videoId == videoId && $0.status == .pending }) {
                DebugLogger.shared.info("Queue: Marking pending item \(item.id) as playing")
                updateQueueItemStatus(id: item.id, status: .playing)
            } else if let item = queue.first(where: { $0.videoId == videoId && $0.status == .played }) {
                // Re-playing a played item
                DebugLogger.shared.info("Queue: Marking played item \(item.id) as playing (replay)")
                updateQueueItemStatus(id: item.id, status: .playing)
            }
        }
    }
    
    private func handlePlaybackFinished() {
        DebugLogger.shared.info("Queue: Playback finished signal received")
        
        // 1. Mark current playing item as played
        let currentQueue = getPlayQueue()
        if let currentItem = currentQueue.first(where: { $0.status == .playing }) {
            DebugLogger.shared.info("Queue: Marking current item \(currentItem.id) as played")
            updateQueueItemStatus(id: currentItem.id, status: .played)
            
            // 2. Fetch updated queue to decide next step
            let updatedQueue = getPlayQueue()
            let pendingItems = updatedQueue.filter { $0.status == .pending }
            
            if let nextItem = pendingItems.first {
                // Play next item
                if let video = nextItem.video {
                    DebugLogger.shared.info("Queue: Advancing to next item: \(video.title)")
                    NotificationCenter.default.post(name: .commandPlayVideo, object: nil, userInfo: ["video": video])
                }
            } else {
                // Queue finished
                DebugLogger.shared.info("Queue: No more pending items")
                
                if currentItem.isLooping {
                    DebugLogger.shared.info("Queue: Looping enabled. Resetting queue.")
                    // Reset all items to pending
                    for item in updatedQueue {
                        updateQueueItemStatus(id: item.id, status: .pending)
                    }
                    
                    // Play first item
                    if let firstItem = updatedQueue.first, let video = firstItem.video {
                        NotificationCenter.default.post(name: .commandPlayVideo, object: nil, userInfo: ["video": video])
                    }
                } else {
                    DebugLogger.shared.info("Queue finished. Clearing queue data.")
                    clearPlayQueue()
                    notifyUpdate()
                }
            }
        } else {
            DebugLogger.shared.info("Queue: No currently playing item found in queue to mark as finished")
        }
    }
    
    private func notifyUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
        }
    }
    
    // MARK: - Public API
    
    func getVideos() -> [Video] {
        return DatabaseManager.shared.getAllVideos()
    }
    
    func updateVideoSortOrder(at index: Int, newOrder: Int) throws {
        var videos = getVideos()
        guard index >= 0 && index < videos.count else { return }
        
        var video = videos[index]
        video.sortOrder = newOrder
        
        DatabaseManager.shared.updateVideo(video)
        notifyUpdate()
    }
    
    func appendVideo(title: String, url: String, group: String? = nil, isLive: Bool? = nil) throws {
        DebugLogger.shared.info("Appending video: \(title)")
        guard let validURL = URL(string: url) else {
            let error = NSError(domain: "MediaManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for video: \(url)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        
        let isLocal = url.hasPrefix("localcache://") || validURL.isFileURL
        let finalIsLive = isLive ?? !isLocal
        
        var finalGroup = group
        if finalGroup == nil || finalGroup?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            finalGroup = isLocal ? "Local Uploads" : "Live Sources"
        }
        
        // Calculate new sort order (lowest - 1 to append at end)
        let videos = getVideos()
        let minSortOrder = videos.map { $0.sortOrder }.min() ?? 0
        let newSortOrder = minSortOrder - 1
        
        let newVideo = Video(title: title, url: validURL, group: finalGroup, isLive: finalIsLive, sortOrder: newSortOrder)
        DatabaseManager.shared.addVideo(newVideo)
        
        notifyUpdate()
    }
    
    func appendMediaFromM3U(content: String, customGroupName: String? = nil) throws {
        DebugLogger.shared.info("Appending playlist content")
        let newVideos = MediaService.shared.parseM3U(content: content)
        
        let currentVideos = getVideos()
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
    
    func replaceMediaWithM3U(content: String) throws {
        DebugLogger.shared.warning("Replacing entire playlist")
        
        // 1. Clear existing data
        DatabaseManager.shared.deleteAllVideos()
        
        // 2. Import new content
        let newVideos = MediaService.shared.parseM3U(content: content)
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
        let videos = getVideos()
        guard index >= 0 && index < videos.count else {
            let error = NSError(domain: "MediaManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid index for deletion: \(index)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        let video = videos[index]
        DebugLogger.shared.info("Deleting video: \(video.title)")
        
        // Clear cache and thumbnail
        CacheManager.shared.removeCachedVideo(id: video.id)
        CacheManager.shared.removeThumbnail(id: video.id)
        
        DatabaseManager.shared.deleteVideo(id: video.id)
        notifyUpdate()
    }
    
    func batchUpdateGroup(indices: [Int], newGroup: String) throws {
        let videos = getVideos()
        let validIndices = indices.filter { $0 >= 0 && $0 < videos.count }
        
        guard !validIndices.isEmpty else {
            let error = NSError(domain: "MediaManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "No valid indices provided"])
            throw error
        }
        
        for index in validIndices {
            var video = videos[index]
            video.group = newGroup
            DatabaseManager.shared.updateVideo(video)
        }
        
        notifyUpdate()
    }
    
    func updateVideo(at index: Int, title: String, url: String, group: String? = nil, isLive: Bool? = nil) throws {
        let videos = getVideos()
        guard index >= 0 && index < videos.count else {
            let error = NSError(domain: "MediaManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Invalid index for update: \(index)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        guard let validURL = URL(string: url) else {
            let error = NSError(domain: "MediaManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for update: \(url)"])
            DebugLogger.shared.error(error.localizedDescription)
            throw error
        }
        
        DebugLogger.shared.info("Updating video at index \(index): \(title)")
        
        var video = videos[index]
        
        let isLocal = url.hasPrefix("localcache://") || validURL.isFileURL
        let finalIsLive = isLive ?? !isLocal
        
        var finalGroup = group
        if finalGroup == nil || finalGroup?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            finalGroup = isLocal ? "Local Uploads" : "Live Sources"
        }
        
        video.title = title
        video.url = validURL
        video.group = finalGroup
        video.isLive = finalIsLive
        
        DatabaseManager.shared.updateVideo(video)
        notifyUpdate()
    }
    
    func deleteVideo(_ video: Video) {
        DebugLogger.shared.info("Deleting video: \(video.title)")
        
        // Clear cache and thumbnail
        CacheManager.shared.removeCachedVideo(id: video.id)
        CacheManager.shared.removeThumbnail(id: video.id)
        
        DatabaseManager.shared.deleteVideo(id: video.id)
        notifyUpdate()
    }
    
    func deleteGroup(_ groupName: String) {
        let videos = getVideos()
        
        // Find videos in the group
        let videosToDelete = videos.filter { $0.group == groupName }
        
        guard !videosToDelete.isEmpty else { return }
        
        DebugLogger.shared.info("Deleting group: \(groupName) with \(videosToDelete.count) videos")
        
        for video in videosToDelete {
             // Clear cache and thumbnail
             CacheManager.shared.removeCachedVideo(id: video.id)
             CacheManager.shared.removeThumbnail(id: video.id)
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
        
        // 3. Notify UI
        notifyUpdate()
    }

    func deleteVideos(at indices: [Int]) throws {
        let videos = getVideos()
        
        for index in indices {
            guard index >= 0 && index < videos.count else { continue }
            let video = videos[index]
            DebugLogger.shared.info("Deleting video: \(video.title)")
            
            // Clear cache and thumbnail
            CacheManager.shared.removeCachedVideo(id: video.id)
            CacheManager.shared.removeThumbnail(id: video.id)
            
            DatabaseManager.shared.deleteVideo(id: video.id)
        }
        
        notifyUpdate()
    }
    
    func updateVideosGroup(at indices: [Int], newGroup: String) throws {
        let videos = getVideos()
        
        for index in indices {
            guard index >= 0 && index < videos.count else { continue }
            var video = videos[index]
            video.group = newGroup
            DatabaseManager.shared.updateVideo(video)
        }
        notifyUpdate()
    }
    
    func updateVideoCacheStatus(video: Video, localURL: URL) {
        var updatedVideo = video
        updatedVideo.cachedURL = localURL
        
        if let attributes = CacheManager.shared.getFileAttributes(url: localURL) {
            updatedVideo.fileSize = attributes.size
            updatedVideo.creationDate = attributes.date
        }
        
        DatabaseManager.shared.updateVideo(updatedVideo)
        notifyUpdate()
    }
    
    func uncacheVideo(_ video: Video) {
        DebugLogger.shared.info("Uncaching video: \(video.title)")
        CacheManager.shared.removeCachedVideo(id: video.id)
        
        var updatedVideo = video
        updatedVideo.cachedURL = nil
        updatedVideo.fileSize = nil
        updatedVideo.creationDate = nil
        
        DatabaseManager.shared.updateVideo(updatedVideo)
        notifyUpdate()
    }
    
    func cleanCache(olderThan date: Date) {
        DebugLogger.shared.info("Cleaning cache older than \(date)")
        let videos = getVideos()
        
        let videosToClean = videos.filter { video in
            guard let creationDate = video.creationDate else { return false }
            return creationDate < date
        }
        
        for video in videosToClean {
            DebugLogger.shared.info("Cleaning expired cache for video: \(video.title)")
            
            // 1. Remove files
            if let cachedURL = video.cachedURL {
                CacheManager.shared.removeCachedVideo(id: video.id)
            }
            CacheManager.shared.removeThumbnail(id: video.id)
            
            // 2. Delete video record from DB
            DatabaseManager.shared.deleteVideo(id: video.id)
        }
        
        notifyUpdate()
    }
    
    // MARK: - Play Queue
    
    func addToPlayQueue(video: Video, isLooping: Bool = false) {
        DebugLogger.shared.info("Queue: Adding video \(video.title) to queue")
        let queue = getPlayQueue()
        let maxSort = queue.map { $0.sortOrder }.max() ?? 0
        let newSort = maxSort + 1
        
        let item = PlayQueueItem(videoId: video.id, sortOrder: newSort, status: .pending, isLooping: isLooping)
        DatabaseManager.shared.addPlayQueueItem(item)
        notifyUpdate()
        
        checkAndStartPlayback()
    }
    
    func replaceQueue(videos: [Video], isLooping: Bool = false) {
        DebugLogger.shared.info("Queue: Replacing queue with \(videos.count) videos")
        clearPlayQueue()
        
        for (index, video) in videos.enumerated() {
            let item = PlayQueueItem(videoId: video.id, sortOrder: index, status: .pending, isLooping: isLooping)
            DatabaseManager.shared.addPlayQueueItem(item)
        }
        notifyUpdate()
        
        checkAndStartPlayback()
    }
    
    func getPlayQueue() -> [PlayQueueItem] {
        return DatabaseManager.shared.getPlayQueue()
    }
    
    func clearPlayQueue() {
        DatabaseManager.shared.clearPlayQueue()
        notifyUpdate()
    }
    
    func updateQueueItemStatus(id: UUID, status: PlayQueueStatus) {
        DatabaseManager.shared.updatePlayQueueStatus(id: id, status: status)
        notifyUpdate()
    }
    
    func updateQueueItemSortOrder(id: UUID, newSortOrder: Int) throws {
        DebugLogger.shared.info("Queue: Attempting to move item \(id) to position \(newSortOrder)")
        let queue = getPlayQueue()
        
        guard let itemToMove = queue.first(where: { $0.id == id }) else {
            throw NSError(domain: "MediaManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Queue item not found"])
        }
        
        // Constraint 1: Cannot move played or playing items
        if itemToMove.status == .played || itemToMove.status == .playing {
            DebugLogger.shared.warning("Queue: Move failed - Item is \(itemToMove.status)")
            throw NSError(domain: "MediaManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot reorder played or playing items"])
        }
        
        // Constraint 2: Cannot move before currently playing item
        if let playingItem = queue.first(where: { $0.status == .playing }) {
            if newSortOrder <= playingItem.sortOrder {
                DebugLogger.shared.warning("Queue: Move failed - Target position \(newSortOrder) is before playing item \(playingItem.sortOrder)")
                throw NSError(domain: "MediaManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot move item before currently playing item"])
            }
        }
        
        // Constraint 3: Cannot move before last played item (if no playing item, but history exists)
        // Actually, just checking against the max sort order of played items is safer
        if let maxPlayedSort = queue.filter({ $0.status == .played }).map({ $0.sortOrder }).max() {
            if newSortOrder <= maxPlayedSort {
                DebugLogger.shared.warning("Queue: Move failed - Target position \(newSortOrder) is before played history \(maxPlayedSort)")
                throw NSError(domain: "MediaManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot move item before played items"])
            }
        }
        
        DebugLogger.shared.info("Queue: Moving item \(id) to \(newSortOrder)")
        DatabaseManager.shared.updatePlayQueueSortOrder(id: id, sortOrder: newSortOrder)
        notifyUpdate()
    }
    
    func checkAndStartPlayback() {
        // If player is already playing, do nothing
        if isPlayerPlaying { 
            DebugLogger.shared.info("Queue: Player is busy, skipping auto-start")
            return 
        }
        
        let queue = getPlayQueue()
        
        // Find first pending item
        if let nextItem = queue.first(where: { $0.status == .pending }) {
            if let video = nextItem.video {
                DebugLogger.shared.info("Queue: Auto-starting playback from queue: \(video.title)")
                NotificationCenter.default.post(name: .commandPlayVideo, object: nil, userInfo: ["video": video])
            }
        } else {
            DebugLogger.shared.info("Queue: No pending items to auto-start")
        }
    }
}

extension Notification.Name {
    static let playlistDidUpdate = Notification.Name("playlistDidUpdate")
}
