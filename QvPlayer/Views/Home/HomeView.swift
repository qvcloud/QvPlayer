import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            TabView(selection: $selectedTab) {
                VideoListView(viewModel: viewModel, groups: viewModel.localVideoGroups, isLoading: viewModel.isLoading, title: "Local Files", showVersion: false)
                    .tabItem {
                        Label("Local", systemImage: "folder")
                    }
                    .tag(0)
                
                VideoListView(viewModel: viewModel, groups: viewModel.liveVideoGroups, isLoading: viewModel.isLoading, title: "Live Streams", showVersion: false)
                    .tabItem {
                        Label("Live", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(2)
            }
            .onChange(of: selectedTab) { newValue in
                if newValue == 1 {
                    viewModel.startLiveStreamsCheck()
                } else {
                    viewModel.stopLiveStreamsCheck()
                }
            }
            .onChange(of: navigationPath) { newPath in
                if !newPath.isEmpty {
                    viewModel.stopLiveStreamsCheck()
                }
            }
            .navigationDestination(for: Video.self) { video in
                PlayerView(video: video)
            }
            .onReceive(NotificationCenter.default.publisher(for: .commandPlayVideo)) { notification in
                // Only handle navigation if we are NOT already in the player
                // If we are in the player, PlayerView handles the switch
                if navigationPath.isEmpty {
                    if let video = notification.userInfo?["video"] as? Video {
                        navigationPath = NavigationPath()
                        navigationPath.append(video)
                    } else if let index = notification.userInfo?["index"] as? Int {
                        let videos = MediaManager.shared.getVideos()
                        if index >= 0 && index < videos.count {
                            let video = videos[index]
                            navigationPath = NavigationPath()
                            navigationPath.append(video)
                        }
                    }
                }
            }
        }
    }
}

struct VideoListView: View {
    @ObservedObject var viewModel: HomeViewModel
    let groups: [VideoGroup]
    let isLoading: Bool
    let title: String
    let showVersion: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                // headerView
                
                if isLoading {
                    loadingView
                } else if groups.isEmpty {
                    emptyView
                } else {
                    videoGridView
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundStyle(.primary)
            
            if showVersion {
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading)
        .padding(.top)
    }
    
    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView("Loading...")
                .progressViewStyle(.circular)
                .tint(.primary)
            Spacer()
        }
        .padding(.top, 100)
    }
    
    private var emptyView: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "video.slash")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No videos found")
                    .foregroundStyle(.secondary)
                
                if let serverURL = WebServer.shared.serverURL {
                    VStack(spacing: 8) {
                        Text("You can import videos via the Web Console:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(serverURL)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 20)
                }
            }
            Spacer()
        }
        .padding(.top, 100)
    }
    
    private var videoGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 400, maximum: 600), spacing: 60)], spacing: 80) {
            ForEach(groups) { group in
                Section(header: groupHeader(for: group)) {
                    ForEach(group.videos) { video in
                        videoItem(for: video)
                    }
                }
            }
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 60)
    }
    
    private func groupHeader(for group: VideoGroup) -> some View {
        HStack {
            Text(group.name)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.vertical, 20)
            
            Spacer()
            
            Text("\(group.videos.count) items")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    private func videoItem(for video: Video) -> some View {
        Button {
            playVideo(video)
        } label: {
            VideoCard(video: video)
        }
        .buttonStyle(.plain) // Use plain style to let VideoCard handle focus visuals
        .contextMenu {
            if video.cachedURL == nil {
                Button {
                    Task {
                        if let localURL = try? await CacheManager.shared.cacheNetworkVideo(url: video.url, id: video.id) {
                            MediaManager.shared.updateVideoCacheStatus(video: video, localURL: localURL)
                        }
                    }
                } label: {
                    Label("Cache Locally", systemImage: "arrow.down.circle")
                }
            } else {
                Button(role: .destructive) {
                    MediaManager.shared.uncacheVideo(video)
                } label: {
                    Label("Remove Cache", systemImage: "trash")
                }
            }
            
            Button(role: .destructive) {
                MediaManager.shared.deleteVideo(video)
            } label: {
                Label("Delete", systemImage: "trash.fill")
            }
            
            if video.cachedURL == nil && !video.url.isFileURL {
                Button {
                    Task {
                        await viewModel.checkLatency(for: video)
                    }
                } label: {
                    Label("Check Speed", systemImage: "speedometer")
                }
            }
        }
    }
    
    private func playVideo(_ video: Video) {
        // Special handling for Live Streams (Direct Play, No Queue)
        if video.isLive {
            Task {
                // Clear queue to ensure no background playlist interference
                MediaManager.shared.clearPlayQueue()
                
                // Trigger navigation directly
                await MainActor.run {
                    NotificationCenter.default.post(name: .commandPlayVideo, object: nil, userInfo: ["video": video])
                }
            }
            return
        }

        Task {
            // Find the group and setup queue
            for group in groups {
                if let index = group.videos.firstIndex(where: { $0.id == video.id }) {
                    // Create queue starting from this video
                    let videosToQueue = Array(group.videos[index...])
                    // Run on background to avoid blocking UI
                    await Task.detached {
                        MediaManager.shared.replaceQueue(videos: videosToQueue)
                    }.value
                    return
                }
            }
            
            // Fallback if not found in groups
            MediaManager.shared.replaceQueue(videos: [video])
        }
    }
}

struct VideoCard: View {
    let video: Video
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                VideoThumbnailView(video: video)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(isFocused ? 0.3 : 0.1), radius: isFocused ? 15 : 5, x: 0, y: isFocused ? 10 : 2)
                    .scaleEffect(isFocused ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
                
                if video.cachedURL != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 24))
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(10)
                } else if let latency = video.latency, !video.url.isFileURL, !video.url.absoluteString.hasPrefix("localcache://") {
                    Text(latency < 0 ? "Timeout" : "\(Int(latency))ms")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            latency < 0 ? Color.red.opacity(0.8) :
                            latency < 200 ? Color.green.opacity(0.8) :
                            latency < 500 ? Color.orange.opacity(0.8) : Color.red.opacity(0.8)
                        )
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(video.title)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    if video.isLive, let count = video.sourceCount, count > 1 {
                        Text("\(count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.5))
                            .clipShape(Capsule())
                    }
                }
                
                if let description = video.description {
                    Text(description)
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(isFocused ? Color.white.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
