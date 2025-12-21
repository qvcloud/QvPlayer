import Foundation

enum PlayQueueStatus: String, Codable {
    case pending
    case playing
    case played
}

struct PlayQueueItem: Identifiable, Codable {
    let id: UUID
    let videoId: UUID
    var sortOrder: Int
    var status: PlayQueueStatus
    var isLooping: Bool
    
    // Populated when fetching with join
    var video: Video?
    
    init(id: UUID = UUID(), videoId: UUID, sortOrder: Int = 0, status: PlayQueueStatus = .pending, isLooping: Bool = false, video: Video? = nil) {
        self.id = id
        self.videoId = videoId
        self.sortOrder = sortOrder
        self.status = status
        self.isLooping = isLooping
        self.video = video
    }
}
