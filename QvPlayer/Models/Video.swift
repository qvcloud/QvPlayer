import Foundation

struct Video: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var url: URL
    var group: String?
    var isLive: Bool
    var description: String?
    var thumbnailURL: URL?
    var cachedURL: URL?
    var latency: Double?
    var lastLatencyCheck: Date?
    var sortOrder: Int
    var fileSize: Int64?
    var creationDate: Date?
    var tvgName: String?
    var sourceCount: Int?
    
    init(id: UUID = UUID(), title: String, url: URL, group: String? = nil, isLive: Bool = false, description: String? = nil, thumbnailURL: URL? = nil, cachedURL: URL? = nil, latency: Double? = nil, lastLatencyCheck: Date? = nil, sortOrder: Int = 0, fileSize: Int64? = nil, creationDate: Date? = nil, tvgName: String? = nil, sourceCount: Int? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.group = group
        self.isLive = isLive
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.cachedURL = cachedURL
        self.latency = latency
        self.lastLatencyCheck = lastLatencyCheck
        self.sortOrder = sortOrder
        self.fileSize = fileSize
        self.creationDate = creationDate
        self.tvgName = tvgName
        self.sourceCount = sourceCount
    }
}
