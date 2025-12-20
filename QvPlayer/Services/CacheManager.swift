import Foundation

class CacheManager {
    static let shared = CacheManager()
    private let fileManager = FileManager.default
    private let cacheDirectoryName = "VideoCache"
    
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent(cacheDirectoryName)
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        return cacheDir
    }
    
    func getCachedFileURL(for remoteURL: URL) -> URL {
        // Create a safe filename from the URL
        let filename = remoteURL.lastPathComponent
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    func isCached(remoteURL: URL) -> Bool {
        let fileURL = getCachedFileURL(for: remoteURL)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func saveUploadedFile(data: Data, filename: String) throws -> URL {
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
    
    func cacheNetworkVideo(url: URL) async throws -> URL {
        let destinationURL = getCachedFileURL(for: url)
        if fileManager.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }
        
        let (downloadURL, _) = try await URLSession.shared.download(from: url)
        
        // Move downloaded file to cache directory
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: downloadURL, to: destinationURL)
        
        return destinationURL
    }
    
    func cleanCache(olderThan timeInterval: TimeInterval = 24 * 60 * 60) {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return
        }
        
        let expirationDate = Date().addingTimeInterval(-timeInterval)
        
        for fileURL in fileURLs {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < expirationDate {
                try? fileManager.removeItem(at: fileURL)
                print("Removed old cache file: \(fileURL.lastPathComponent)")
            }
        }
    }
    
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
    }
    
    func removeCachedVideo(url: URL) {
        let fileURL = getCachedFileURL(for: url)
        try? fileManager.removeItem(at: fileURL)
    }
}
