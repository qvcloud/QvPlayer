import SwiftUI
import AVFoundation
#if canImport(KSPlayer)
import KSPlayer
#endif

struct VideoThumbnailView: View {
    let video: Video
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.primary.opacity(0.1)
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .layoutPriority(-1)
                
                // Subtle gradient overlay for better text contrast if needed
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.3)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                ZStack {
                    Image(systemName: video.isLive ? "antenna.radiowaves.left.and.right" : "play.tv.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundStyle(.secondary.opacity(0.5))
                    
                    if video.isLive {
                        VStack {
                            Spacer()
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            await generateThumbnail()
        }
    }
    
    private func generateThumbnail() async {
        // 0. Check Cache
        if let cachedImage = CacheManager.shared.getThumbnail(id: video.id) {
            await MainActor.run {
                self.image = cachedImage
                self.isLoading = false
            }
            return
        }
        
        DebugLogger.shared.info("Generating thumbnail for: \(video.title)")
        
        // 1. Try Remote Thumbnail URL
        if let thumbURL = video.thumbnailURL {
            if await fetchRemoteThumbnail(url: thumbURL) {
                return
            }
        }
        
        // Optimization: Skip thumbnail generation for live streams to prevent UI blocking
        if video.isLive {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        // Resolve localcache:// URL
        var targetURL = video.url
        if video.url.scheme == "localcache" {
            let rawFilename = video.url.host ?? video.url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !rawFilename.isEmpty, let filename = rawFilename.removingPercentEncoding {
                let fileURL = CacheManager.shared.getFileURL(filename: filename)
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    targetURL = fileURL
                    print("✅ [Thumbnail] Resolved localcache:// to \(targetURL.path)")
                } else {
                    print("❌ [Thumbnail] Failed to resolve localcache:// - File not found: \(filename)")
                }
            }
        }
        
        // 1. Try AVAssetImageGenerator first (Fastest, Native)
        var assetOptions: [String: Any] = [:]
        let configUserAgent = DatabaseManager.shared.getConfig(key: "user_agent")
        let userAgent = (configUserAgent?.isEmpty ?? true) ? AppConstants.defaultUserAgent : configUserAgent!
        assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["User-Agent": userAgent]
        
        let asset = AVURLAsset(url: targetURL, options: assetOptions)
        
        // Optimization: Don't decode full resolution for thumbnails
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)
        
        // Allow loose tolerance to find any available frame quickly
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        
        do {
            // Try to get a frame at 5 seconds.
            // With infinite tolerance, if 5s is not available, it will return the nearest (e.g. 0s or live head)
            let time = CMTime(seconds: 5, preferredTimescale: 600)
            let (cgImage, _) = try await generator.image(at: time)
            
            await MainActor.run {
                self.image = UIImage(cgImage: cgImage)
                self.isLoading = false
                // Save to cache
                if let image = self.image {
                    CacheManager.shared.saveThumbnail(image: image, id: video.id)
                }
            }
        } catch {
            DebugLogger.shared.warning("AVAssetImageGenerator failed for \(video.title): \(error.localizedDescription). Retrying with KSPlayer...")
            await generateThumbnailWithFFmpeg(url: targetURL)
        }
    }

    private func generateThumbnailWithFFmpeg(url: URL) async {
        #if canImport(KSPlayer)
        DebugLogger.shared.info("Attempting KSPlayer fallback for: \(url.absoluteString)")
        // Use KSPlayer's ThumbnailController
        let controller = ThumbnailController(thumbnailCount: 1)
        do {
            let thumbnails = try await controller.generateThumbnail(for: url)
            if let first = thumbnails.first {
                await MainActor.run {
                    self.image = first.image
                    self.isLoading = false
                    // Save to cache
                    if let image = self.image {
                        CacheManager.shared.saveThumbnail(image: image, id: video.id)
                    }
                }
                DebugLogger.shared.info("KSPlayer thumbnail success for: \(url.lastPathComponent)")
            } else {
                DebugLogger.shared.error("KSPlayer returned no thumbnails for: \(url.lastPathComponent)")
                await MainActor.run { self.isLoading = false }
            }
        } catch {
            DebugLogger.shared.error("KSPlayer thumbnail failed for \(url.lastPathComponent): \(error.localizedDescription)")
            await MainActor.run { self.isLoading = false }
        }
        #else
        DebugLogger.shared.error("KSPlayer not available for fallback")
        await MainActor.run {
            self.isLoading = false
        }
        #endif
    }
    
    private func fetchRemoteThumbnail(url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        let configUserAgent = DatabaseManager.shared.getConfig(key: "user_agent")
        let userAgent = (configUserAgent?.isEmpty ?? true) ? AppConstants.defaultUserAgent : configUserAgent!
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await NetworkManager.shared.session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.image = uiImage
                    self.isLoading = false
                    CacheManager.shared.saveThumbnail(image: uiImage, id: video.id)
                }
                return true
            }
        } catch {
            DebugLogger.shared.warning("Failed to fetch remote thumbnail for \(video.title): \(error.localizedDescription)")
        }
        return false
    }
}
