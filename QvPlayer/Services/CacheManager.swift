import Foundation
import UIKit

class CacheManager {
    static let shared = CacheManager()
    private let fileManager = FileManager.default
    private let cacheDirectoryName = "VideoCache"
    private let thumbnailDirectoryName = "VideoThumbnails"
    
    private var cacheDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent(cacheDirectoryName)
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        return cacheDir
    }
    
    private var thumbnailDirectory: URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let thumbDir = paths[0].appendingPathComponent(thumbnailDirectoryName)
        if !fileManager.fileExists(atPath: thumbDir.path) {
            try? fileManager.createDirectory(at: thumbDir, withIntermediateDirectories: true)
        }
        return thumbDir
    }
    
    func getCachedFileURL(id: UUID, fileExtension: String = "mp4") -> URL {
        let filename = "\(id.uuidString).\(fileExtension)"
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    func getFileURL(filename: String) -> URL {
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    func isCached(id: UUID) -> Bool {
        // Search for any file starting with the UUID
        let prefix = id.uuidString
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return false
        }
        return fileURLs.contains { $0.lastPathComponent.hasPrefix(prefix) }
    }
    
    func saveUploadedFile(data: Data, filename: String) throws -> URL {
        DebugLogger.shared.info("Saving uploaded file: \(filename) (\(data.count) bytes)")
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
        DebugLogger.shared.info("File saved to: \(fileURL.path)")
        return fileURL
    }
    
    func cacheNetworkVideo(url: URL, id: UUID) async throws -> URL {
        DebugLogger.shared.info("Caching network video: \(url.lastPathComponent) as \(id.uuidString)")
        
        let fileExtension = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        let destinationURL = getCachedFileURL(id: id, fileExtension: fileExtension)
        
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
    
    func getFileAttributes(url: URL) -> (size: Int64, date: Date)? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64,
               let date = attributes[.creationDate] as? Date {
                return (size, date)
            }
        } catch {
            DebugLogger.shared.error("Failed to get attributes for \(url.path): \(error.localizedDescription)")
        }
        return nil
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
        try? fileManager.removeItem(at: thumbnailDirectory)
    }
    
    func removeCachedVideo(id: UUID) {
        // Search for files with this ID prefix to handle any extension
        let prefix = id.uuidString
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for url in fileURLs {
                if url.lastPathComponent.hasPrefix(prefix) {
                    DebugLogger.shared.info("Removing cached video: \(url.lastPathComponent)")
                    try? fileManager.removeItem(at: url)
                }
            }
        } catch {
            DebugLogger.shared.error("Failed to remove cached video for ID \(id): \(error)")
        }
    }
    
    func calculateCacheSize() -> Int64 {
        guard let urls = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for url in urls {
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        // Also include thumbnails
        if let thumbUrls = try? fileManager.contentsOfDirectory(at: thumbnailDirectory, includingPropertiesForKeys: [.fileSizeKey], options: []) {
            for url in thumbUrls {
                if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func performAutoClear(days: Int) {
        guard days > 0 else { return }
        let seconds = TimeInterval(days * 24 * 60 * 60)
        cleanCache(olderThan: seconds)
    }
    
    // MARK: - Thumbnail Caching
    
    func getThumbnailURL(id: UUID) -> URL {
        let filename = id.uuidString + ".jpg"
        return thumbnailDirectory.appendingPathComponent(filename)
    }
    
    func saveThumbnail(image: UIImage, id: UUID) {
        let fileURL = getThumbnailURL(id: id)
        if let data = image.jpegData(compressionQuality: 0.7) {
            do {
                try data.write(to: fileURL)
                DebugLogger.shared.info("Thumbnail saved to: \(fileURL.path)")
            } catch {
                DebugLogger.shared.error("Failed to save thumbnail: \(error)")
            }
        }
    }
    
    func getThumbnail(id: UUID) -> UIImage? {
        let fileURL = getThumbnailURL(id: id)
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL) {
            return UIImage(data: data)
        }
        return nil
    }
    
    func removeThumbnail(id: UUID) {
        let fileURL = getThumbnailURL(id: id)
        if fileManager.fileExists(atPath: fileURL.path) {
            DebugLogger.shared.info("Removing cached thumbnail: \(fileURL.lastPathComponent)")
            try? fileManager.removeItem(at: fileURL)
        }
    }
}
