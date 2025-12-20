import SwiftUI
import AVFoundation

struct VideoThumbnailView: View {
    let url: URL
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .layoutPriority(-1)
            } else {
                Image(systemName: "play.tv.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 50, height: 50)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(isLoading ? 0.5 : 1)
            }
        }
        .task {
            await generateThumbnail()
        }
    }
    
    private func generateThumbnail() async {
        let asset = AVURLAsset(url: url)
        
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
            }
        } catch {
            print("Thumbnail generation failed for \(url): \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
