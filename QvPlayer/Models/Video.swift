import Foundation

struct Video: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var url: URL
    var group: String?
    var isLive: Bool
    var description: String?
    var thumbnailURL: URL?
    
    init(id: UUID = UUID(), title: String, url: URL, group: String? = nil, isLive: Bool = false, description: String? = nil, thumbnailURL: URL? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.group = group
        self.isLive = isLive
        self.description = description
        self.thumbnailURL = thumbnailURL
    }
}
