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
                if let index = notification.userInfo?["index"] as? Int {
                    let videos = PlaylistManager.shared.getPlaylistVideos()
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

struct VideoListView: View {
    @ObservedObject var viewModel: HomeViewModel
    let groups: [VideoGroup]
    let isLoading: Bool
    let title: String
    let showVersion: Bool
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                headerView
                
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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 40)], spacing: 40) {
            ForEach(groups) { group in
                Section(header: groupHeader(for: group)) {
                    ForEach(group.videos) { video in
                        videoItem(for: video)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }
    
    private func groupHeader(for group: VideoGroup) -> some View {
        HStack {
            Text(group.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .padding(.vertical, 12)
                .padding(.leading, 20)
            Spacer()
            
            Menu {
                Button(role: .destructive) {
                    PlaylistManager.shared.deleteGroup(group.name)
                } label: {
                    Label("Delete Group", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.card) // Improve focus behavior
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 20)
    }
    
    private func videoItem(for video: Video) -> some View {
        NavigationLink(value: video) {
            VideoCard(video: video)
        }
        .buttonStyle(.card)
        .contextMenu {
            if video.cachedURL == nil {
                Button {
                    Task {
                        _ = try? await CacheManager.shared.cacheNetworkVideo(url: video.url)
                        NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
                    }
                } label: {
                    Label("Cache Locally", systemImage: "arrow.down.circle")
                }
            } else {
                Button(role: .destructive) {
                    CacheManager.shared.removeCachedVideo(url: video.url)
                    NotificationCenter.default.post(name: .playlistDidUpdate, object: nil)
                } label: {
                    Label("Remove Cache", systemImage: "trash")
                }
            }
            
            Button(role: .destructive) {
                PlaylistManager.shared.deleteVideo(video)
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
}

struct VideoCard: View {
    let video: Video
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                VideoThumbnailView(url: video.url)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if video.cachedURL != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(6)
                } else if let latency = video.latency {
                    Text(latency < 0 ? "Timeout" : "\(Int(latency))ms")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            latency < 0 ? Color.red :
                            latency < 200 ? Color.green :
                            latency < 500 ? Color.orange : Color.red
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let description = video.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(10)
        .background(Color.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
