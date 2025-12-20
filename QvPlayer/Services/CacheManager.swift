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
    
    func getFileURL(filename: String) -> URL {
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    func isCached(remoteURL: URL) -> Bool {
        let fileURL = getCachedFileURL(for: remoteURL)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func saveUploadedFile(data: Data, filename: String) throws -> URL {
        DebugLogger.shared.info("Saving uploaded file: \(filename) (\(data.count) bytes)")
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
        DebugLogger.shared.info("File saved to: \(fileURL.path)")
        return fileURL
    }
    
    func cacheNetworkVideo(url: URL) async throws -> URL {
        DebugLogger.shared.info("Caching network video: \(url.lastPathComponent)")
        let destinationURL = getCachedFileURL(for: url)
        if fileManager.fileExists(atPath: destinationURL.path) {
            DebugLogger.shared.info("Video already cached: \(destinationURL.lastPathComponent)")
            return destinationURL
        }
        
        let (downloadURL, _) = try await URLSession.shared.download(from: url)
        
        // Move downloaded file to cache directory
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: downloadURL, to: destinationURL)
        DebugLogger.shared.info("Video cached successfully: \(destinationURL.lastPathComponent)")
        
        return destinationURL
    }
    
    func cleanCache(olderThan timeInterval: TimeInterval = 24 * 60 * 60) {
        DebugLogger.shared.info("Cleaning cache older than \(timeInterval) seconds")
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return
        }
        
        let expirationDate = Date().addingTimeInterval(-timeInterval)
        
        for fileURL in fileURLs {
            if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < expirationDate {
                try? fileManager.removeItem(at: fileURL)
                DebugLogger.shared.info("Removed old cache file: \(fileURL.lastPathComponent)")
            }
        }
    }
    
    func clearAllCache() {
        DebugLogger.shared.warning("Clearing all cache")
        try? fileManager.removeItem(at: cacheDirectory)
    }
    
    func removeCachedVideo(url: URL) {
        let fileURL = getCachedFileURL(for: url)
        DebugLogger.shared.info("Removing cached video: \(fileURL.lastPathComponent)")
        try? fileManager.removeItem(at: fileURL)
    }
}
