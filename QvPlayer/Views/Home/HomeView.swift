import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("QvPlayer")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                            .foregroundStyle(.primary)
                        
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading)
                    .padding(.top)
                    
                    if viewModel.isLoading {
                        HStack {
                            Spacer()
                            ProgressView("Loading Channels...")
                                .progressViewStyle(.circular)
                                .tint(.primary)
                            Spacer()
                        }
                        .padding(.top, 100)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 500), spacing: 40)], spacing: 40, pinnedViews: [.sectionHeaders]) {
                            ForEach(viewModel.videoGroups) { group in
                                Section(header: 
                                    HStack {
                                        Text(group.name)
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.primary)
                                            .padding(.vertical, 12)
                                            .padding(.leading, 20)
                                        Spacer()
                                    }
                                    .background(.regularMaterial)
                                ) {
                                    ForEach(group.videos) { video in
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
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationDestination(for: Video.self) { video in
                PlayerView(video: video)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gear")
                    }
                }
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
